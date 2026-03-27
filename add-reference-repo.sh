#!/usr/bin/env bash
# add-reference-repo.sh — Add a GitHub repo as a submodule under reference-code/
#
# Usage:
#   ./add-reference-repo.sh <github-url> [folder-name]
#
# Examples:
#   ./add-reference-repo.sh https://github.com/aukilabs/some-service
#   ./add-reference-repo.sh https://github.com/aukilabs/some-service custom-name

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <github-url> [folder-name]"
  exit 1
fi

URL="$1"
# Derive folder name from the last path segment of the URL, stripping .git if present
DEFAULT_NAME="$(basename "$URL" .git)"
NAME="${2:-$DEFAULT_NAME}"
TARGET="reference-code/$NAME"

if [[ -d "$TARGET" ]]; then
  echo "Error: $TARGET already exists."
  exit 1
fi

echo "Adding $URL as submodule at $TARGET ..."
git submodule add "$URL" "$TARGET"

echo ""
echo "Done! '$TARGET' added as a submodule."
echo ""
echo "Next steps:"
echo "  git add .gitmodules $TARGET"
echo "  git commit -m \"chore: add $NAME reference repo\""
