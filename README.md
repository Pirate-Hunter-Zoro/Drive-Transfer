# Project: Drive to MEGA Transfer Utility

A collection of scripts designed to transfer files from a Google Drive account to multiple MEGA.nz accounts. It seems you have a need for such a thing.

-----

## Overview

This set of tools automates the tedious process of moving large video files from Google Drive and distributing them across several MEGA accounts, presumably to circumvent storage limitations. It also includes helper scripts for account and file management. It is designed for those who have better things to do than manually download and upload files like some lowly human.

-----

## Scripts

### `transfer.ps1`

This is the main script. It orchestrates the transfer of `.mkv` and `.mp4` files from a specified Google Drive `rclone` remote to a series of MEGA accounts.

**Features:**

* **Automatic Account Switching:** When one MEGA account is full, the script will log out and proceed to the next one in your list.
* **Logging:** Keeps a record of which files have been processed and which files have been uploaded to each account.
* **Resilience:** It is designed to be the "definitive, corrected version."

-----

### `scan_accounts.ps1`

A PowerShell script to search for a specific file across multiple MEGA accounts. It logs into each account, searches for a string, and logs the findings. The default search is for 'The Way of the Househusband'. A curious choice.

-----

### `remove_colon.py`

A Python script that scans your Google Drive for `.mkv` or `.mp4` files with colons in their names and replaces them with `-`. This is likely to prevent issues with file systems that do not tolerate such characters. It includes a `DRY_RUN` mode to see what changes would be made without actually renaming anything. Do not be a fool; use the dry run first.

-----

## Setup

### Requirements

* **rclone:** Must be installed and configured with a Google Drive remote.
* **mega-cmd:** The MEGA command-line tools must be installed and accessible in your system's PATH.
* **Python 3:** For the `remove_colon.py` script.
* **PowerShell:** For the `transfer.ps1` and `scan_accounts.ps1` scripts.
* **Python Dependencies:** The necessary Python packages are listed in `requirements.txt`. Install them with this command:

    ```powershell
    pip install -r requirements.txt
    ```

### Configuration

1. **`transfer.ps1`:**
      * Set your Google Drive remote name in `$gdriveRemote`.
      * Create `scripts/accounts.txt` and populate it with your MEGA account emails, one per line.
      * Create `scripts/passwords.txt` and place the password for the MEGA accounts inside.
2. **`scan_accounts.ps1`:**
      * Update the `$searchString` variable to the file you are looking for.
      * Create `scripts/scan_account_password.txt` with the relevant password.
3. **`remove_colon.py`:**
      * You will need to acquire `client_secrets.json` from the Google Cloud Platform and place it in the same directory. The script will handle the authentication flow on the first run.

-----

## Execution

### Transferring Files

To begin the main transfer process, run the following in your PowerShell terminal:

```powershell
.\transfer.ps1
```

The script will handle the rest, assuming you have configured it properly.

### Scanning Accounts

To search for a file within your MEGA accounts:

```powershell
.\scan_accounts.ps1
```

### Renaming Files in Google Drive

To fix filenames with colons, execute the Python script. Remember to set `DRY_RUN` to `False` when you are ready to make changes.

```powershell
python remove_colon.py
```

-----

## `.gitignore`

This file ensures that logs, credentials, and temporary downloaded files are not committed to your version control. It is a basic measure of cleanliness. Do not alter it unless you know what you are doing.
