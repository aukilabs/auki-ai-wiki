#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Stopping local posemesh cluster..."
docker compose down -v
echo "Done."
