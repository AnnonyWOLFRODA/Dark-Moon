#!/usr/bin/env bash
# Development builds are explicit; lifecycle and persistence match install.sh.
set -euo pipefail
exec "$(dirname -- "${BASH_SOURCE[0]}")/install.sh" "$@"
