# `DRIVE-TRANSFERER`: The Renaming Ritual

A two-stage technique designed to bring order to a chaotic collection of media files. It first purifies their names with demonic power and then dispatches them to their final destinations.

The primary assault relies on the superior intellect of the `forge_gemini_batch_map.py` script, which interrogates targets in controlled waves to determine their true names. It is a resumable process; if interrupted, it can pick up where it left off without re-processing completed work.

Should the initial plan contain flaws (such as duplicate destinations), the ritual will pause and demand human guidance. It isolates the flawed entries and uses the `refine_with_notes.py` script to perform a surgical strike, perfecting the plan before execution.

---

## Components of the Arsenal

Your forces are comprised of the following:

* **Master Scripts:**
  * `master_rename.sh`: The primary invocation script. It orchestrates the entire renaming assault, from cataloging to final execution.
  * `master_transfer.sh`: The secondary script. Unleashed after the renaming is complete to transfer the perfected files.
* **Core Weaponry:**
  * `scripts/forge_gemini_batch_map.py`: The heart of the technique. It wields the power of Gemini to correct the flawed filenames.
  * `scripts/refine_with_notes.py`: The precision strike. It uses a `notes.txt` file to correct specific flaws isolated in `repeats.txt`.
  * `execute_rename.sh`: The executioner. It carries out the final sentence passed down by the master plan.
* **Supporting Files & Scrolls:**
  * `.env`: A scroll where you must inscribe your secret key (`GOOGLE_API_KEY`).
  * `requirements.txt`: A list of incantations (`pip`) to summon the necessary Python spirits.
  * `credentials.json` & `token.json`: Seals of power required for your `rclone` configuration to command Google Drive.
  * `scripts/`: The directory where the battle takes place. It contains the lists of targets (`file_list.txt`), the battle plan (`renamemap.txt`), logs of failures, records of transfers, and **`repeats.txt`**, a temporary file containing only the flawed mappings that require your attention.

---

## Preparation for the Ritual

Before you begin, you must prepare the battlefield. Do not fail in these simple tasks.

1. **Configure `rclone`:** This technique assumes you have already established a pact with `rclone` and have configured your `gdrive:` and `mega...:` remotes.
2. **Inscribe the Secret Key:** Create the `.env` file. It must contain your Google API key. Execute this command precisely:

    ```sh
    echo "GOOGLE_API_KEY='YOUR_SECRET_KEY_HERE'" > .env
    ```

3. **Set the Weapon's Path:** The `RCLONE_CMD` variable at the top of both `master_rename.sh` and `master_transfer.sh` must point to your `rclone` executable. Your pathetic human systems are inconsistent; you must adjust this path yourself.

---

## Executing the Assault

The technique is unleashed in two distinct phases.

### Phase I: The Renaming

This is the main assault. All other steps are merely a prelude to this.

1. **Invoke the Master Script:**

    ```sh
    sh master_rename.sh
    ```

2. **Observe the Ritual:** The script will automatically:
    * Prepare its spiritual energy by setting up the Conda environment.
    * **Catalog targets**, creating `scripts/file_list.txt` (This step is skipped if the file already exists).
    * **Interrogate targets** using Gemini, creating `scripts/renamemap.txt` (Skipped if the file exists).
    * **Purify the plan** into `scripts/renamemap_purified.txt` (Skipped if the file exists).
3. **The Refinement Loop:** The script will then scrutinize the plan with the Jagan Eye.
    * If no flaws are found, it will proceed.
    * If duplicate destinations are detected, the ritual will **pause** and **isolate** all flawed mappings into a new file: **`scripts/repeats.txt`**.
    * You must then create a **`scripts/notes.txt`** file. Use the contents of `repeats.txt` as your guide to write instructions for correcting the flawed entries.
    * Once you save the notes and press Enter, the `refine_with_notes.py` script will perform a **surgical strike**: correcting *only* the flawed lines and merging them back into the master plan.
    * This loop repeats until the plan is flawless.
4. **Unleash the Dragon:** You will be prompted for final confirmation. This is the point of no return. Once you proceed, `execute_rename.sh` will carry out the renames.

### Phase II: The Transfer

After the targets have been perfected, their transfer can begin.

1. **Invoke the Transfer Script:**

    ```sh
    sh master_transfer.sh
    ```

2. **The Great Dispersal:** The script will copy the renamed files from `gdrive:` to your series of `mega...:` remotes, keeping a detailed log of which file went to which destination in `scripts/transfer_log.txt`.
