#!/usr/bin/env python3

import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

SYSTEM_ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("documentation", SYSTEM_ROOT / "tools/check-documentation.py")
documentation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(documentation)


def write(path, text):
    """CRLF 로 저장하면 POSIX sh 와 awk 검사기가 값 끝의 CR 을 값의 일부로 읽는다."""
    with path.open("w", newline="\n") as handle:
        handle.write(text)


class HistoricalDocumentsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / ".engsys").mkdir()
        (self.root / "docs/adr").mkdir(parents=True)
        shutil.copyfile(SYSTEM_ROOT / "packages/docs-gov/policy.yaml", self.root / "policy.yaml")
        write(self.root / ".engsys/project.yaml", """documentation:
  policy: 'policy.yaml'
  lifecycle:
    adr:
      path: 'docs/adr'
      frozen-status: ['accepted']
""")
        self.record = self.root / "docs/adr/0001-example.md"
        self.valid = "---\ntype: adr\nstatus: accepted\n---\n\n# Decision\n"
        write(self.record, self.valid)

    def errors(self):
        return "\n".join(documentation.check(self.root))

    def test_valid_record_and_local_links(self):
        write(self.root / "docs/with space.md", "# Context\n")
        write(self.record, self.valid + "\n[context](../with%20space.md#context)\n"
                               "[same][record]\n\n[record]: 0001-example.md\n")
        self.assertEqual(self.errors(), "")

    def test_unknown_status_fails(self):
        write(self.record, self.valid.replace("accepted", "typo-accepted"))
        self.assertIn("unknown status", self.errors())

    def test_frontmatter_is_required(self):
        for text in ("# No metadata\n", "---\ntype: adr\n", self.valid.replace("type: adr\n", "")):
            with self.subTest(text=text):
                write(self.record, text)
                self.assertIn("frontmatter", self.errors())

    def test_broken_inline_and_reference_links_fail(self):
        for link in ("[missing](missing.md)", "[missing]: missing.md"):
            with self.subTest(link=link):
                write(self.record, self.valid + "\n" + link + "\n")
                self.assertIn("broken local link: missing.md", self.errors())

    def test_code_examples_and_external_links_are_not_followed(self):
        write(self.record, self.valid + """
```md
[example](not-a-real-file.md)
```
`[inline example](not-a-real-file.md)`

    [indented example](not-a-real-file.md)

[external](https://example.invalid/document)
[fragment](#decision)
""")
        self.assertEqual(self.errors(), "")

    def test_missing_declared_directory_fails(self):
        shutil.rmtree(self.root / "docs/adr")
        self.assertIn("lifecycle path does not exist", self.errors())

    def test_unknown_frozen_status_fails(self):
        contract = self.root / ".engsys/project.yaml"
        write(contract, contract.read_text().replace("['accepted']", "['typo']"))
        self.assertIn("unknown frozen-status", self.errors())

    def test_check_preserves_historical_prose(self):
        write(self.record, self.valid + "\nAn old decision can differ from current code.\n")
        before = self.record.read_bytes()
        self.assertEqual(self.errors(), "")
        self.assertEqual(self.record.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
