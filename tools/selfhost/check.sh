#!/usr/bin/env bash
# Offline checks only. No daemon, models, provider accounts or pentest.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
export PYTHONDONTWRITEBYTECODE=1
for file in install.sh install-dev.sh conf/apply-settings.sh conf/entrypoint-opencode.sh tools/selfhost/check.sh; do
  bash -n "$file"
done
shellcheck install.sh install-dev.sh conf/apply-settings.sh conf/entrypoint-opencode.sh tools/selfhost/check.sh
python tools/selfhost/check-secrets.py
python -m pytest -q -p no:cacheprovider tests/selfhost mcp/tests
bash tools/check-no-regression.sh
python - <<'PY'
import json
from pathlib import Path
for path in [Path('conf/opencode.json'), Path('docs/selfhost/scope.example.json')]:
    json.loads(path.read_text())
print('Static JSON valid')
PY
# Use a disposable project directory so real provider files are neither required
# nor read. Configuration only: never contact the Docker Engine.
sandbox=$(mktemp -d)
trap 'rm -rf -- "$sandbox"' EXIT
cp docker-compose.lab*.yml "$sandbox/"
printf 'OPENCODE_AUTH_MODE=existing\nOPENCODE_MODEL=openai/example\n' > "$sandbox/.opencode.env"
DARKMOON_OPENCODE_IMAGE="sha256:$(printf '%064d' 0)"
export DARKMOON_OPENCODE_IMAGE
export DARKMOON_TOOLBOX_IMAGE="$DARKMOON_OPENCODE_IMAGE"
export DARKMOON_OLLAMA_IMAGE="$DARKMOON_OPENCODE_IMAGE"
export DARKMOON_LAB_DOCKER_SOCKET=/tmp/darkmoon-test-only.sock
base=(docker compose --project-directory "$sandbox" -f "$sandbox/docker-compose.lab.yml")
"${base[@]}" config --quiet
"${base[@]}" -f "$sandbox/docker-compose.lab.cloud.yml" config --quiet
"${base[@]}" -f "$sandbox/docker-compose.lab.advanced.yml" config --quiet
"${base[@]}" -f "$sandbox/docker-compose.lab.ollama.yml" -f "$sandbox/docker-compose.lab.ollama-gpu.yml" config --quiet
echo 'Compose configurations valid (no containers started)'
