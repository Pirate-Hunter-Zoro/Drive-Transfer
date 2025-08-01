# `DRIVE-TRANSFERER`: The Renaming Ritual

A two-stage technique designed to bring order to a chaotic collection of media files. It first purifies their names with demonic power and then dispatches them to their final destinations.

This project is intended to be run on a machine where you have the freedom to act—one where both **`rclone`** and the **`MEGAcmd`** command-line tools are properly installed and their locations have been added to the system's `PATH` environment variable. All previous, pathetic attempts to work around system limitations (such as the Selenium puppet technique) have been abandoned as they are no longer necessary.

The ritual is resumable; if interrupted, it can pick up where it left off without re-processing completed work.

-----

## Components of the Arsenal

Your forces are comprised of the following:

* **Master Scripts:**
  * `master_rename.sh`: The primary invocation script. It orchestrates the entire renaming assault, from cataloging to final execution, using `rclone` and Gemini.
  * `master_transfer.sh`: The secondary script. Unleashed after the renaming is complete to transfer the perfected files from Google Drive to multiple MEGA accounts.
* **Core Weaponry:**
  * `rename/forge_gemini_batch_map.py`: The heart of the renaming technique. It wields the power of Gemini to correct flawed filenames.
  * `rename/refine_with_notes.py`: The precision strike. It uses a `notes.txt` file to correct specific flaws found in the initial battle plan.
  * `execute_rename.sh`: The executioner. It carries out the final renames within Google Drive.
* **Supporting Files & Scrolls:**
  * `.env`: A scroll where you must inscribe your secret key (`GOOGLE_API_KEY`).
  * `accounts.txt`: A **critical** and secret scroll where you list your MEGA account credentials, one per line, in the format `email:password`. **This file must be in your `.gitignore`**.
  * `requirements.txt`: A list of incantations (`pip`) to summon the necessary Python spirits.
  * `rename/`: The directory where the battle takes place. It contains the lists of targets, the battle plan, logs of failures, and records of transfers.

-----

## Preparation for the Ritual

Before you begin, you must prepare the battlefield. Failure is not an option.

1. **Install the Warriors:** Ensure both `rclone` and `MEGAcmd` are fully installed on your system.
2. **Grant Them Sight (PATH):** You **must** add the installation directories for both `rclone` and `MEGAcmd` to your system's `PATH` environment variable. The ritual will fail if your terminal cannot find these commands from any location.
3. **Configure `rclone`:** You must have a configured `rclone` remote pointing to your Google Drive, and it must be named `gdrive`.
4. **Inscribe the Secret Keys:**
      * Create the `.env` file with your Google API key: `echo "GOOGLE_API_KEY='YOUR_SECRET_KEY_HERE'" > .env`
      * Create the `accounts.txt` file and list your MEGA accounts, one per line: `your-email@example.com:your_password`

-----

## Executing the Assault

The technique is unleashed in two distinct phases.

### Phase I: The Renaming

This phase purifies the names of your files within Google Drive.

1. **Invoke the Master Script:**

    ```sh
    bash master_rename.sh
    ```

2. **Observe the Ritual:** The script will automatically catalog your files, use Gemini to create a renaming plan, and then enter the **Refinement Loop**.
3. **The Refinement Loop:** If the Jagan Eye detects any flaws (duplicate final names), the ritual will pause. It will isolate the flawed entries into `rename/repeats.txt`. You must then create a `rename/notes.txt` file to provide corrections. This loop will repeat until the plan is perfect.
4. **Unleash the Dragon:** Upon your final confirmation, the script will execute the renames directly on your Google Drive.

### Phase II: The Transfer

After the targets have been perfected, their transfer can begin.

1. **Invoke the Transfer Script:**

    ```sh
    bash master_transfer.sh
    ```

2. **The Great Dispersal:** The script will read your `accounts.txt` file and begin a relentless, file-by-file assault. It will download each file from Google Drive to a temporary local folder, upload it to the next MEGA account in the sequence, and then purge the local copy before proceeding to the next target. All transfers are logged for your records.
