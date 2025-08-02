# Drive Transfer & Renaming Suite

This is a collection of scripts—a formidable arsenal—for the systematic renaming and transfer of media files from a Google Drive remote to multiple MEGA.nz accounts. It's designed for precision and power, using a series of targeted techniques to cleanse, correct, and relocate your assets.

The workflow is built around `rclone`, `mega-cmd`, and the Google Gemini API to handle the grunt work, leaving you to oversee the operation. Don't mess it up.

## Core Arsenal

The process is a multi-stage assault. Each script is a distinct technique, to be used in the proper sequence.

* **`forge_gemini_batch_map.py`**: The opening move. This script takes a simple list of your chaotic filenames (`file_list.txt`) and consults a higher power (the Gemini API) to forge a complete battle plan (`renamemap.txt`). This plan maps each original file to its perfected, TMDB-compliant name. It operates in batches to handle a large number of targets without faltering.

* **`refine_with_notes.py`**: A surgical strike. Should the initial plan contain flaws, this is your tool for correction. It takes a list of identified failures (`repeats.txt`) and your explicit instructions (`notes.txt`) to perform precise corrections on the main plan, `renamemap_purified.txt`. It consults Gemini for a focused blast of energy, ensuring only the flawed entries are altered.

* **`execute_rename.sh`**: The point of no return. This shell script executes the perfected battle plan. It reads `renamemap_purified.txt` line by line and uses `rclone moveto` to rename the files directly in your Google Drive. Failures are recorded in `execution_failures.txt` for your review.

* **`transfer.ps1`**: The final migration. This PowerShell script is the master of logistics. It transfers your video files from the Google Drive remote to a series of MEGA accounts, respecting the storage limits of each one. It downloads each file locally before uploading, keeps a log of all transferred files (`processed_files.log`), and maintains individual manifests for each MEGA account.

* **`remove_colon.py`**: A simple, but necessary, utility. This script scours your Google Drive for video files with colons in their names—a character that can cause trouble—and replaces them. It includes a `DRY_RUN` parameter, a pointless feature for the weak-willed who fear commitment.

* **`scan_accounts.ps1`**: A tool for interrogation. This script performs a sweeping audit of your MEGA accounts. It logs into each one sequentially, hunts for files matching a specific name, and records all findings in `scripts/found_files_log.txt`. Use it to confirm the location of key assets or to find stragglers after a major operation. It requires a single password in `scripts/scan_account_password.txt` for the entire account block.

## Prerequisites

Don't even think about starting without the proper preparations.

* **rclone**: Must be installed and configured with a Google Drive remote named `gdrive:`.
* **mega-cmd**: Must be installed and accessible in your system's PATH.
* **Python 3**: Required to execute the Python scripts.
* **Dependencies**: Install all necessary Python libraries using the provided list.

    ```bash
    pip install -r requirements.txt
    ```

* **Google Gemini API Key**: You need to acquire your own API key and place it in a `.env` file in the root directory, like this: `GOOGLE_API_KEY='your_key_here'`.
* **Google Drive API Credentials**: For `remove_colon.py`, you'll need a `client_secrets.json` file from your Google Cloud project with the Drive API enabled.

## The Battle Plan (Usage)

Follow these steps. Do not deviate.

1. **Reconnaissance**: First, generate a list of all target files from your Google Drive remote and save it as `scripts/file_list.txt`. The format is one full file path per line.

2. **Forge the Map**: Unleash the first technique.

    ```bash
    python scripts/forge_gemini_batch_map.py
    ```

    This will generate `scripts/renamemap.txt` and a log of any files Gemini refused to process (`gemini_failures.txt`).

3. **Purify the Plan**: Review `renamemap.txt`. Correct any obvious errors and save it as `scripts/renamemap_purified.txt`. This is your definitive plan of attack.

4. **(Optional) Refine and Correct**: If you discover systemic errors or patterns of failure, list the flawed original paths in `scripts/repeats.txt` and write your correction instructions in `scripts/notes.txt`. Then, execute the refinement technique.

    ```bash
    python scripts/refine_with_notes.py
    ```

    This will surgically alter `renamemap_purified.txt` with the Gemini-provided corrections.

5. **Execute the Renaming**: With the plan finalized, it's time to act.

    ```bash
    ./execute_rename.sh
    ```

    This will begin the renaming process on Google Drive. Monitor the output for warnings.

6. **Begin the Transfer**: Once the renaming is complete, configure your MEGA account credentials in `scripts/accounts.txt` and `scripts/passwords.txt`. Then, initiate the final transfer.

    ```powershell
    ./transfer.ps1
    ```

    This script will handle the rest, moving files account by account until the task is done.
