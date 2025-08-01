#!/bin/bash

# --- BINDING CONFIGURATION ---
# IMPORTANT: You MUST edit your path variables so that the rclone command will work regardless of where it is run from.
RCLONE_CMD="rclone"

# The name of the spirit realm (Conda environment) to be used.
ENV_NAME="media_sorcerer"
# --- END CONFIGURATION ---


# Ensure we are in the script's directory.
cd "$(dirname "$0")"

echo "--- The Renaming Ritual is About to Begin ---"
echo ""

# Phase 0: Prepare the Spirit Realm (Conda Environment)
echo ">> Phase 0: Preparing the Spirit Realm (Conda)..."
CONDA_BASE=$(conda info --base)
if [ -z "$CONDA_BASE" ]; then
    echo "!! ERROR: Conda installation not found. Aborting ritual."
    exit 1
fi
source "$CONDA_BASE/etc/profile.d/conda.sh"
if ! conda env list | grep -q "^$ENV_NAME\s"; then
    echo " -> Spirit realm '$ENV_NAME' not found. Creating it now..."
    conda create --name "$ENV_NAME" python=3.10 -y
fi
conda activate "$ENV_NAME"
echo " -> Summoning required spirits with Pip..."
pip install -r requirements.txt --quiet
echo ">> Spirit realm is now active and fully prepared."
echo ""


# Phase 1: Cataloging
echo ">> Phase 1: Cataloging all targets..."
if [ ! -f "scripts/file_list.txt" ]; then
    "$RCLONE_CMD" lsf gdrive: --files-only --include="*.{mkv,mp4}" > scripts/file_list.txt
    echo ">> Cataloging complete."
else
    echo " -> 'file_list.txt' already exists. Skipping cataloging."
fi
echo ""

# Phase 2: Interrogation
echo ">> Phase 2: Interrogating all targets with forge_gemini_batch_map.py..."
if [ ! -f "scripts/renamemap.txt" ]; then
    python scripts/forge_gemini_batch_map.py
    echo ">> Interrogation complete."
else
    echo " -> 'renamemap.txt' already exists. Skipping interrogation."
fi
echo ""

# Phase 3: Purification
echo ">> Phase 3: Purifying the battle plan..."
if [ ! -f "scripts/renamemap_purified.txt" ]; then
    awk -F'\t' '!seen[$1]++' scripts/renamemap.txt > scripts/renamemap_purified.txt
    echo ">> Battle plan purified."
else
    echo " -> 'renamemap_purified.txt' already exists. Skipping purification."
fi
echo ""

# Phase 3.5: Refinement Loop
echo ">> Phase 3.5: Scrutinizing the plan for weakness..."
while true; do
    # First, find the names of the duplicate destinations
    DUPLICATES=$(awk -F'\t' 'NF > 1 {print $2}' scripts/renamemap_purified.txt | sort | uniq -d)

    if [ -z "$DUPLICATES" ]; then
        echo " -> No duplicate destinations found. The plan is perfect."
        echo ""
        break # Exit the loop
    fi
    
    # NEW: Isolate all lines causing the duplicates into a separate file
    echo " -> Isolating flawed mappings into scripts/repeats.txt..."
    awk -F'\t' 'NR==FNR{a[$0];next} $2 in a' <(echo "$DUPLICATES") scripts/renamemap_purified.txt > scripts/repeats.txt

    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!! WARNING: The Jagan Eye has found flaws in your plan."
    echo "!! The full problematic mappings have been saved to 'scripts/repeats.txt'"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "The following destinations are repeated:"
    echo "$DUPLICATES"
    echo ""
    echo "To proceed, you must provide guidance."
    echo "1. Create or edit the file 'scripts/notes.txt'."
    echo "2. In this file, write instructions on how to correct the mappings found in 'scripts/repeats.txt'."
    
    read -p "Once 'scripts/notes.txt' is saved, press [Enter] to refine the plan..."

    if [ ! -f "scripts/notes.txt" ]; then
        echo "!! ERROR: 'scripts/notes.txt' not found. You cannot proceed without guidance. Aborting."
        exit 1
    fi
    
    echo ">> Invoking refinement technique..."
    python scripts/refine_with_notes.py
    
    if [ $? -ne 0 ]; then
        echo "!! FATAL ERROR: The refinement script failed to execute. Aborting ritual."
        exit 1
    fi

    echo ">> Refinement complete. Re-scrutinizing the plan..."
done


# Phase 4: The Point of No Return
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!! WARNING: THE BATTLE PLAN IS FORGED. THE NEXT STEP IS FINAL. !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "Open and inspect 'scripts/renamemap_purified.txt' NOW."
echo "This is your final plan."
echo ""
read -p "Are you satisfied with the plan? Press [Enter] to unleash the final execution, or [Ctrl+C] to abort."
echo ""

# Phase 5: Final Execution
echo ">> Phase 5: Unleashing the final execution..."
chmod +x execute_rename.sh
./execute_rename.sh

echo ""
echo "--- The Ritual is Complete ---"