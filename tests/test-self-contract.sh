#!/bin/sh

# 이 레포는 자기 자신의 첫 pilot이다. 표준을 배포하는 레포가 그 표준을 만족하지 못하면
# 그대로 실패해야 한다.
set -eu

system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
"$system_root/bin/engsys" check --project "$system_root"

# Self lock은 HEAD와 같은 packages·bin·lib tree를 가리켜야 한다. 아니면 engsys claude가
# 병합 전 revision의 skill·hook·launcher를 조합한다. 자기 표준 변경은 명시적 upgrade로만
# 반영한다는 규칙을 self-pilot에도 강제한다.
lock_revision=$(sed -n "/^system:$/,/^profile:/ s/^  revision: '\(.*\)'\$/\1/p" \
  "$system_root/.engsys/lock.yaml" | sed -n '1p')
[ -n "$lock_revision" ] || { printf '%s\n' 'self lock has no system revision' >&2; exit 1; }
for tree in packages bin lib; do
  locked=$(git -C "$system_root" rev-parse "$lock_revision:$tree")
  current=$(git -C "$system_root" rev-parse "HEAD:$tree")
  if [ "$locked" != "$current" ]; then
    printf '%s\n' "self lock is stale: $tree differs from HEAD;" \
      'run bin/engsys upgrade --project . --apply and commit the lock' >&2
    exit 1
  fi
done
