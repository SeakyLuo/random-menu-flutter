#!/bin/zsh
set -euo pipefail
exec python3 "${0:A:h}/backup_android_data.py" "$@"
