#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUA_BIN="${LUA_BIN:-lua}"
LUAC_BIN="${LUAC_BIN:-luac}"

for command_name in "$LUA_BIN" "$LUAC_BIN" python3; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "缺少发布校验依赖: $command_name" >&2
        exit 1
    fi
done

cd "$PROJECT_DIR"

echo "[1/4] 运行 Lua 测试"
"$LUA_BIN" tests/run.lua

echo "[2/4] 检查 Lua 语法"
while IFS= read -r -d '' lua_file; do
    "$LUAC_BIN" -p "$lua_file"
done < <(find scripts/dst-controller tests -type f -name '*.lua' -print0)
"$LUAC_BIN" -p modinfo.lua
"$LUAC_BIN" -p modmain.lua

echo "[3/4] 检查版本与 Steam 描述"
python3 - "$PROJECT_DIR" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
modinfo = (root / "modinfo.lua").read_text(encoding="utf-8")
match = re.search(r'^version\s*=\s*"([^"]+)"', modinfo, re.MULTILINE)
if not match:
    raise SystemExit("modinfo.lua 中找不到 version")
version = match.group(1)

expected = {
    "README.md": f"**版本**: {version}",
    "README_EN.md": f"**Version**: {version}",
    "CLAUDE.md": f"**Version**: {version}",
}
for filename, marker in expected.items():
    content = (root / filename).read_text(encoding="utf-8")
    if marker not in content:
        raise SystemExit(f"{filename} 版本未与 modinfo.lua 同步: 需要 {marker}")

description = (root / "STEAM_DESCRIPTION.txt").read_text(encoding="utf-8").strip()
if len(description) > 8000:
    raise SystemExit(f"Steam 描述超过 8000 字符限制: {len(description)}")
if "github.com/gfreezy/dst-controller" not in description.lower():
    raise SystemExit("Steam 描述缺少 GitHub 项目链接")
print(f"版本 {version}；Steam 描述 {len(description)}/8000 字符")
PY

echo "[4/4] 检查 Git 差异格式"
git diff --check

echo "发布校验通过"
