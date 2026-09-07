#!/bin/sh

# 이 레포는 자기 자신의 첫 pilot이다. 표준을 배포하는 레포가 그 표준을 만족하지 못하면
# 그대로 실패해야 한다.
set -eu

system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
"$system_root/bin/engsys" check --project "$system_root"
