#!/usr/bin/env bash
# Syntax check all Lua/Luau sources to keep scrolls tidy.
set -euo pipefail

# Prefer Luau compiler when available to handle Roblox extensions like
# `continue` and bitwise operators; fall back to standard luac otherwise.
if command -v luau-compile >/dev/null 2>&1; then
  LUACMD="luau-compile"
  LUACMD_ARGS=""
elif command -v luac >/dev/null 2>&1; then
  LUACMD="luac"
  LUACMD_ARGS="-p"
else
  echo "Luau or Lua compiler not found" >&2
  exit 1
fi

status=0
while IFS= read -r -d '' file; do
  if ! $LUACMD $LUACMD_ARGS "$file" >/dev/null 2>&1; then
    echo "Syntax error detected in $file" >&2
    status=1
  fi
done < <(find src -name '*.lua' -print0)

exit $status
