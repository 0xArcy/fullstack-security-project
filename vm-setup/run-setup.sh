#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  run-setup.sh <role> [role-options]

Roles:
  database   Runs setup-database.sh
  backend    Runs setup-backend.sh
  frontend   Runs setup-frontend.sh

Examples:
  ./run-setup.sh database --backend-ip 10.0.0.11
  ./run-setup.sh backend --creds-file /root/secure-db-credentials.env --frontend-origin https://10.0.0.10
  ./run-setup.sh frontend --backend-host 10.0.0.11
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

role="$1"
shift

case "$role" in
  database)
    exec "${SCRIPT_DIR}/setup-database.sh" "$@"
    ;;
  backend)
    exec "${SCRIPT_DIR}/setup-backend.sh" "$@"
    ;;
  frontend)
    exec "${SCRIPT_DIR}/setup-frontend.sh" "$@"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown role: ${role}" >&2
    usage
    exit 1
    ;;
esac
