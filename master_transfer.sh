#!/bin/bash

# This script transfers files from Google Drive to multiple MEGA accounts.
# It assumes rclone and MEGAcmd are properly installed and in the system's PATH.
# It reads account credentials from a separate 'accounts.txt' file.

# Ensure we are in the script's directory.
cd "$(dirname "$0")"

# --- CONFIGURATION ---
RCLONE_CMD="rclone"
INPUT_FILE="scripts/renamemap_purified.txt"
ACCOUNTS_FILE="scripts/accounts.txt"
FAILURE_LOG="scripts/transfer_failures.txt"
TRANSFER_LOG="scripts/transfer_log.txt"
PROCESSED_LOG="scripts/processed_files.log"
TEMP_DOWNLOAD_DIR="./temp_downloads"

# --- Read Accounts from the Scroll ---
# The script will now read your secrets from accounts.txt
# The file must be in the format: email:password
declare -a MEGA_EMAILS
declare -a MEGA_PASSWORDS

if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo "!! FATAL: The scroll of secrets, '$ACCOUNTS_FILE', was not found. Aborting."
    exit 1
fi

while IFS=':' read -r email password; do
    # Ignore empty lines or lines without a colon
    if [[ -n "$email" && -n "$password" ]]; then
        MEGA_EMAILS+=("$email")
        MEGA_PASSWORDS+=("$password")
    fi
done < "$ACCOUNTS_FILE"

if [ ${#MEGA_EMAILS[@]} -eq 0 ]; then
    echo "!! FATAL: The scroll of secrets, '$ACCOUNTS_FILE', is empty or improperly formatted. Aborting."
    exit 1
fi
# --- END CONFIGURATION ---

# Create necessary files and directories if they don't exist
mkdir -p "$TEMP_DOWNLOAD_DIR"
touch "$FAILURE_LOG"
touch "$TRANSFER_LOG"
touch "$PROCESSED_LOG"

# A function to be called when the script is interrupted or finishes
cleanup() {
    echo ""
    echo ">> Logging out of MEGA..."
    mega-logout > /dev/null 2>&1
    echo "--- Ritual Complete ---"
}
# Trap the exit signal to ensure cleanup happens
trap cleanup EXIT

LINE_COUNT=$(wc -l < "$INPUT_FILE")
CURRENT_LINE=0
REMOTE_COUNT=${#MEGA_EMAILS[@]}

echo "--- Beginning Final Transfer Protocol ---"
echo "Found $LINE_COUNT targets to transfer to $REMOTE_COUNT destinations."

while IFS=$'\t' read -r old_path new_path; do
  # Skip empty or malformed lines
  if [ -z "$old_path" ] || [ -z "$new_path" ]; then
    continue
  fi
  
  CURRENT_LINE=$((CURRENT_LINE + 1))

  # Check if this file has already been processed
  if grep -Fxq "$new_path" "$PROCESSED_LOG"; then
    echo "Skipping ($CURRENT_LINE/$LINE_COUNT): ${new_path} (already transferred)"
    continue
  fi

  echo "Processing ($CURRENT_LINE/$LINE_COUNT): ${new_path}"
  LOCAL_FILE_PATH="${TEMP_DOWNLOAD_DIR}/${new_path}"

  # 1. Download from Google Drive
  echo " -> Summoning from Google Drive..."
  "$RCLONE_CMD" copy "gdrive:${new_path}" "$TEMP_DOWNLOAD_DIR"
  if [ ! -f "$LOCAL_FILE_PATH" ]; then
    echo "!! WARNING: Failed to download '${new_path}' from Google Drive."
    echo "${new_path} (download failed)" >> "$FAILURE_LOG"
    continue # Skip to the next file
  fi
  
  # 2. Determine which MEGA account to use
  destination_remote_index=$(( (CURRENT_LINE - 1) % REMOTE_COUNT ))
  
  echo " -> Binding to realm of ${MEGA_EMAILS[$destination_remote_index]}..."
  # Logout for a clean state, then log in to the target account
  mega-logout > /dev/null 2>&1
  mega-login "${MEGA_EMAILS[$destination_remote_index]}" "${MEGA_PASSWORDS[$destination_remote_index]}"
  if [ $? -ne 0 ]; then
    echo "!! FATAL: Failed to login to MEGA account ${MEGA_EMAILS[$destination_remote_index]}."
    echo "${new_path} (login failed)" >> "$FAILURE_LOG"
    rm -f "$LOCAL_FILE_PATH"
    continue
  fi

  # 3. Upload to MEGA
  echo " -> Offering to MEGA..."
  mega-put "$LOCAL_FILE_PATH" "/"
  
  # 4. Verify result and clean up
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