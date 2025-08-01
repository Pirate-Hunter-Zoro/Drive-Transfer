#!/bin/bash

# This script transfers files from Google Drive to multiple MEGA accounts.
# It is designed to be run from the project root directory.
# All log files and input maps are expected to be in the 'scripts' subdirectory.

# Ensure we are in the script's directory.
cd "$(dirname "$0")"

# --- CONFIGURATION ---
RCLONE_CMD="rclone"
# CORRECTED: All script-related files are in the 'scripts' directory.
INPUT_FILE="scripts/renamemap_purified.txt"
ACCOUNTS_FILE="scripts/accounts.txt"
FAILURE_LOG="scripts/transfer_failures.txt"
TRANSFER_LOG="scripts/transfer_log.txt"
PROCESSED_LOG="scripts/processed_files.log"
TEMP_DOWNLOAD_DIR="./temp_downloads"

# --- Inquisitor's Check ---
if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo "!! FATAL: The scroll of secrets, '$ACCOUNTS_FILE', does not exist. Aborting."
    exit 1
fi
if [ ! -s "$ACCOUNTS_FILE" ]; then
    echo "!! FATAL: The scroll of secrets, '$ACCOUNTS_FILE', is an empty vessel. Aborting."
    exit 1
fi

# --- REFORGED: Read Accounts from the Scroll ---
# This technique is brutally effective and resilient to Windows line endings.
mapfile -t lines < <(grep -v '^$' "$ACCOUNTS_FILE" | tr -d '\r')
declare -a MEGA_EMAILS
declare -a MEGA_PASSWORDS

for line in "${lines[@]}"; do
    MEGA_EMAILS+=("$(echo "$line" | cut -d':' -f1)")
    MEGA_PASSWORDS+=("$(echo "$line" | cut -d':' -f2-)")
done

if [ ${#MEGA_EMAILS[@]} -eq 0 ]; then
    echo "!! FATAL: Failed to read any accounts from '$ACCOUNTS_FILE'. Check its formatting. Aborting."
    exit 1
fi
# --- END REFORGED ---

# Create necessary files and directories
mkdir -p "$TEMP_DOWNLOAD_DIR"
touch "$FAILURE_LOG"
touch "$TRANSFER_LOG"
touch "$PROCESSED_LOG"

cleanup() {
    echo ""
    echo ">> Logging out of MEGA..."
    mega-logout > /dev/null 2>&1
    echo "--- Ritual Complete ---"
}
trap cleanup EXIT

LINE_COUNT=$(wc -l < "$INPUT_FILE")
CURRENT_LINE=0
REMOTE_COUNT=${#MEGA_EMAILS[@]}

echo "--- Beginning Final Transfer Protocol ---"
echo "Found $LINE_COUNT targets to transfer to $REMOTE_COUNT destinations."

while IFS=$'\t' read -r old_path new_path; do
  if [[ -z "$old_path" || -z "$new_path" ]]; then continue; fi
  
  CURRENT_LINE=$((CURRENT_LINE + 1))

  if grep -Fxq "$new_path" "$PROCESSED_LOG"; then
    echo "Skipping ($CURRENT_LINE/$LINE_COUNT): ${new_path} (already transferred)"
    continue
  fi

  echo "Processing ($CURRENT_LINE/$LINE_COUNT): ${new_path}"
  LOCAL_FILE_PATH="${TEMP_DOWNLOAD_DIR}/${new_path}"

  echo " -> Summoning from Google Drive..."
  "$RCLONE_CMD" copy "gdrive:${new_path}" "$TEMP_DOWNLOAD_DIR"
  if [ ! -f "$LOCAL_FILE_PATH" ]; then
    echo "!! WARNING: Failed to download '${new_path}' from Google Drive."
    echo "${new_path} (download failed)" >> "$FAILURE_LOG"
    continue
  fi
  
  destination_remote_index=$(( (CURRENT_LINE - 1) % REMOTE_COUNT ))
  
  echo " -> Binding to realm of ${MEGA_EMAILS[$destination_remote_index]}..."
  mega-logout > /dev/null 2>&1
  mega-login "${MEGA_EMAILS[$destination_remote_index]}" "${MEGA_PASSWORDS[$destination_remote_index]}"
  if [ $? -ne 0 ]; then
    echo "!! FATAL: Failed to login to MEGA account ${MEGA_EMAILS[$destination_remote_index]}."
    echo "${new_path} (login failed)" >> "$FAILURE_LOG"
    rm -f "$LOCAL_FILE_PATH"
    continue
  fi

  echo " -> Offering to MEGA..."
  mega-put "$LOCAL_FILE_PATH" "/"
  
  if [ $? -eq 0 ]; then
    echo " -> SUCCESS. Recording victory and cleansing battlefield."
    echo -e "${new_path}\t${MEGA_EMAILS[$destination_remote_index]}" >> "$TRANSFER_LOG"
    echo "$new_path" >> "$PROCESSED_LOG"
    rm -f "$LOCAL_FILE_PATH"
  else
    echo "!! WARNING: Failed to upload '${new_path}' to MEGA."
    echo "${new_path} (upload failed)" >> "$FAILURE_LOG"
    rm -f "$LOCAL_FILE_PATH"
  fi

done < "$INPUT_FILE"