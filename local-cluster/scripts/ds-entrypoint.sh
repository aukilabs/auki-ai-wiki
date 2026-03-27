#!/bin/sh
set -e

# ds-entrypoint.sh — Read registration credentials from shared volume, then start DS.

CREDS_FILE="/shared/ds-credentials"

echo "Waiting for DS registration credentials..."
for i in $(seq 1 60); do
  if [ -f "$CREDS_FILE" ]; then
    CREDS=$(cat "$CREDS_FILE")
    echo "DS_REGISTRATION_CREDENTIALS loaded"
    export DS_REGISTRATION_CREDENTIALS="$CREDS"
    exec ./ds "$@"
  fi
  sleep 1
done

echo "ERROR: DS registration credentials not found after 60s"
exit 1
