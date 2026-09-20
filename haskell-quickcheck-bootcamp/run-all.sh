#!/usr/bin/env bash
# 全 Example をコンパイル & 実行して、エラーなく動くことを確認するスクリプト。
#
# 使い方:
#   ./run-all.sh            すべて実行
#   ./run-all.sh 01 05 12   指定した番号だけ実行
#
# 注意: 「わざと失敗するプロパティ」を含む Example があります。
#       ここで見ているのは「Haskell として動くか (終了コード 0)」であって、
#       「全プロパティが成功するか」ではありません。
set -uo pipefail
cd "$(dirname "$0")/examples"

if [ $# -gt 0 ]; then
  files=()
  for n in "$@"; do files+=("Example${n}.hs"); done
else
  files=(Example*.hs)
fi

pass=0; fail=0; failed=()
for f in "${files[@]}"; do
  if out=$(timeout 90 runghc -Wall -Wno-type-defaults -Wno-unused-top-binds "$f" 2>&1); then
    printf '  ok   %s\n' "$f"
    pass=$((pass+1))
  else
    printf '  FAIL %s\n' "$f"
    printf '%s\n' "$out" | sed 's/^/       /'
    fail=$((fail+1)); failed+=("$f")
  fi
done

echo
echo "passed: $pass / failed: $fail"
[ "$fail" -eq 0 ] || { echo "failed files: ${failed[*]}"; exit 1; }
