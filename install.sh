#!/usr/bin/env bash
# Conservative lifecycle for a dedicated laboratory. Never source/eval dotenv.
set -euo pipefail
umask 077
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command_name="${1:-install}"
case "$command_name" in
  --help|-h)
    echo 'Usage: ./install.sh [install|reconfigure|update|diagnose|reset|stop]'
    echo 'Configure .opencode.env first. Set DARKMOON_OPENCODE_IMAGE to an immutable ID or digest.'
    echo 'reset stops this stack; it never deletes persistent data or images.'
    exit 0 ;;
  --init) command_name=reconfigure ;;
  --reset) command_name=reset ;;
  install|reconfigure|update|diagnose|reset|stop) ;;
  *) echo 'Unknown command' >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then echo 'Unexpected argument' >&2; exit 2; fi
command -v docker >/dev/null || { echo 'Docker is required' >&2; exit 1; }
docker compose version >/dev/null
if [[ ! "${DARKMOON_OPENCODE_IMAGE:-}" =~ ^(sha256:[a-f0-9]{64}|[^[:space:]]+@sha256:[a-f0-9]{64})$ ]]; then
  echo 'Set DARKMOON_OPENCODE_IMAGE to an immutable image ID or repo@sha256:digest' >&2
  exit 1
fi
compose=(docker compose -p darkmoon-lab -f docker-compose.lab.yml)
if [[ "$command_name" == reset ]]; then
  echo 'This stops/removes darkmoon-lab containers and its network.'
  echo 'Named volumes, credentials, sessions, reports, images and caches are retained.'
  read -r -p 'Type RESET darkmoon-lab to continue: ' confirmation
  [[ "$confirmation" == 'RESET darkmoon-lab' ]] || exit 1
  "${compose[@]}" down
  exit
fi
if [[ "$command_name" == stop ]]; then "${compose[@]}" stop; exit; fi
[[ -f .opencode.env && ! -L .opencode.env ]] || {
  echo 'Create a regular .opencode.env from docs/selfhost/provider.env.example' >&2; exit 1;
}
chmod 600 .opencode.env
# Validate literal dotenv and generated JSON in a temporary directory, without
# exporting file-controlled variables to this shell or executing their contents.
python3 tools/selfhost/validate-env.py .opencode.env
"${compose[@]}" config --quiet
docker info >/dev/null
if [[ "$command_name" == diagnose ]]; then
  "${compose[@]}" ps
  exit
fi
if [[ "$command_name" == update && "$DARKMOON_OPENCODE_IMAGE" != sha256:* ]]; then
  "${compose[@]}" pull
fi
"${compose[@]}" up -d
# A running PID alone is not readiness: ensure configuration parses and a
# disabled toolbox really has no Docker connection. No LLM request or campaign.
"${compose[@]}" exec -T opencode /opt/darkmoon/mcp/server/.venv/bin/python /root/conf/lab-ready.py
echo 'Lab started. Toolbox disabled; verify interactive authentication locally.'
