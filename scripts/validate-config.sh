#!/bin/bash
# Validates sst.config.ts after editing.
# Runs as a PostToolUse hook on Edit/Write operations.

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only validate sst.config.ts files
case "$FILE_PATH" in
  *sst.config.ts) ;;
  *) exit 0 ;;
esac

# Skip if file doesn't exist (deleted)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Skip if npx is not available
if ! command -v npx &> /dev/null; then
  exit 0
fi

# Get the directory containing the config file for tsc context
CONFIG_DIR=$(dirname "$FILE_PATH")

# Run TypeScript check with --skipLibCheck for speed
OUTPUT=$(cd "$CONFIG_DIR" && npx tsc --noEmit --skipLibCheck 2>&1) && STATUS=0 || STATUS=$?

if [ $STATUS -eq 0 ]; then
  echo '{"systemMessage": "SST config TypeScript validation passed."}'
else
  echo "$OUTPUT" | jq -Rs '{systemMessage: ("SST config validation found issues:\n" + .)}'
fi

exit 0
