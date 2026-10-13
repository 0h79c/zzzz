#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -x .tools/lune || ! -x .tools/rojo || ! -x .tools/luau-compile || ! -x .tools/luau-analyze ]]; then
  echo "Install the pinned tools first: python3 scripts/bootstrap.py" >&2
  exit 1
fi
while IFS= read -r -d '' source; do
  .tools/luau-compile "$source" >/dev/null
done < <(find src tests -name '*.luau' -print0)
.tools/luau-compile scripts/balance_report.luau >/dev/null
.tools/luau-analyze src/shared/Expedition.luau src/shared/CombatRules.luau src/shared/HuntMetrics.luau
for test in tests/*.luau; do
  .tools/lune run "$test"
done
.tools/lune run scripts/balance_report.luau
mkdir -p build
.tools/rojo build default.project.json --output build/Wildbond.rbxlx
echo "Checks finished. Open build/Wildbond.rbxlx in Roblox Studio and run the Studio checklist."
