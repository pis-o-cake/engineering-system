#!/usr/bin/env python3
"""Measure a scoped native gate against engsys in a disposable project clone.

No timing from this experiment represents human time saved. The original checkout is never edited.
Only exit codes and timings are exported; command output stays in the temporary clone.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).parent / "lib"))
import engsys_yaml


def run(command, cwd, env):
    started = time.perf_counter()
    result = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True, timeout=300)
    return {"exit_code": result.returncode, "seconds": round(time.perf_counter() - started, 6)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--native", required=True, help="Scoped native verification command")
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--system", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.samples < 5:
        parser.error("at least 5 samples are required")
    project = args.project.resolve()
    system = args.system.resolve()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=project):
        parser.error("measure a clean committed project checkout")
    result = {"format": 1, "project_revision": revision,
              "system_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=system, text=True).strip(),
              "system_diff_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "HEAD"], cwd=system)).hexdigest(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "python": platform.python_version()},
              "scope": args.native, "samples": args.samples, "human_time_saved": None,
              "thresholds": {"max_median_added_seconds": 5, "max_clean_failures": 0,
                             "required_managed_mutation_detections": 2},
              "clean": [], "mutations": []}
    result["implementation_blobs"] = {
        str(path.relative_to(system)): hashlib.sha256(path.read_bytes()).hexdigest()
        for directory in ("bin", "lib", "packages/docs-gov/bin")
        for path in sorted((system / directory).rglob("*")) if path.is_file()
    }
    env = {**os.environ, "ENGSYS_USE_CHECKOUT": "1", "PYTHONDONTWRITEBYTECODE": "1"}
    env.pop("ENGSYS_PINNED", None)
    env.pop("ENGSYS_SYSTEM_ROOT", None)
    with tempfile.TemporaryDirectory(prefix="engsys-measure-") as directory:
        clone = Path(directory) / "project"
        subprocess.run(["git", "clone", "-q", "--local", str(project), str(clone)], check=True)
        # Reuse installed tools. Model and documentation files remain in the disposable clone.
        for relative in (".venv", "backend/.venv", "node_modules", "frontend/chat/node_modules", "frontend/cms/node_modules"):
            original = project / relative
            if original.is_dir() and not (clone / relative).exists():
                (clone / relative).parent.mkdir(parents=True, exist_ok=True)
                (clone / relative).symlink_to(original, target_is_directory=True)
        manifest = clone / ".engsys/project.yaml"
        contract = engsys_yaml.load(manifest)
        scoped = re.sub(r"^  verify:.*$", lambda _: "  verify: '" + args.native.replace("'", "''") + "'",
                            manifest.read_text(encoding="utf-8"), count=1, flags=re.M)
        # This experiment isolates documentation governance; branch migration is a different check.
        scoped = re.sub(r"^vcs:\n.*?(?=^[A-Za-z]|\Z)", "", scoped, flags=re.M | re.S)
        with manifest.open('w', encoding='utf-8', newline='\n') as handle:
            handle.write(scoped)
        result["contract_adjustments"] = ["native verification scoped to the supplied command", "vcs block omitted for documentation-only measurement"]
        native = ["sh", "-c", args.native]
        # Windows 는 shebang 을 해석하지 않는다. launcher 는 언제나 sh 로 실행한다.
        managed = ["sh", str(system / "bin/engsys"), "verify", "--project", str(clone)]
        for command in (native, managed):
            warmup = run(command, clone, env)
            if warmup["exit_code"]:
                raise SystemExit(f"clean warmup failed: {command}; no improvement claim is valid")
        for sample in range(args.samples):
            row = {"sample": sample + 1}
            for name, command in (("native", native), ("managed", managed))[::1 if sample % 2 == 0 else -1]:
                row[name] = run(command, clone, env)
            result["clean"].append(row)
        generated = contract["documentation"]["generated"][0]["output"]
        authored = next(path for path in contract["documentation"]["review"]["scopes"]
                        if (clone / path).is_file() and path.endswith(".md"))
        for name, relative in (("generated-drift", generated), ("stale-review", authored)):
            target = clone / relative
            before = target.read_bytes()
            try:
                target.write_bytes(before + b"\n\nTemporary measurement change.\n")
                result["mutations"].append({"scenario": name, "native": run(native, clone, env),
                                            "managed": run(managed, clone, env)})
            finally:
                target.write_bytes(before)
        result["restored"] = run(managed, clone, env)
    clean_failures = sum(row[name]["exit_code"] != 0 for row in result["clean"] for name in ("native", "managed"))
    added = statistics.median(row["managed"]["seconds"] - row["native"]["seconds"] for row in result["clean"])
    detections = sum(row["managed"]["exit_code"] != 0 for row in result["mutations"])
    result["summary"] = {"native_median_seconds": statistics.median(row["native"]["seconds"] for row in result["clean"]),
                         "managed_median_seconds": statistics.median(row["managed"]["seconds"] for row in result["clean"]),
                         "median_added_seconds": added, "clean_failures": clean_failures,
                         "managed_mutation_detections": detections,
                         "pass": clean_failures == 0 and detections == 2 and added <= 5 and result["restored"]["exit_code"] == 0}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], ensure_ascii=False))
    return 0 if result["summary"]["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
