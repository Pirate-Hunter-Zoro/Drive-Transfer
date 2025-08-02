#!/bin/bash

# This script reads the purified renamemap and executes the rclone commands, logging failures.

# Ensure we are in the script's directory.
cd "$(dirname "$0")"

# Corrected paths to the plan and a new failure log
INPUT_FILE="scripts/renamemap_purified.txt"
FAILURE_LOG="scripts/execution_failures.txt"
RCLONE_CMD="rclone" # Make sure this path is correct - it will be on windows if you edit the path environmental variable

# Clear any previous failure log
>"$FAILURE_LOG"

if [ ! -f "$INPUT_FILE" ]; then
    echo "!! ERROR: Purified battle plan '$INPUT_FILE' not found. Aborting."
    exit 1
fi

LINE_COUNT=$(wc -l < "$INPUT_FILE")
CURRENT_LINE=0

while IFS=$'\t' read -r old_path new_path; do
  if [ -z "$old_path" ] || [ -z "$new_path" ]; then
    continue
  fi
  
  CURRENT_LINE=$((CURRENT_LINE + 1))
  echo "Executing rename ($CURRENT_LINE/$LINE_COUNT): ${old_path}"
  
  # Execute the moveto command and check its exit status
  "$RCLONE_CMD" moveto "gdrive:${old_path}" "gdrive:${new_path}"
  if [ $? -ne 0 ]; then
    echo "!! WARNING: Failed to rename '${old_path}'. Recording to failure log."
    echo "${old_path}" >> "$FAILURE_LOG"
  fi
done < "$INPUT_FILE"

echo "Execution complete."