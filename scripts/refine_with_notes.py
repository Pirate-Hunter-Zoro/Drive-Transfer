import os
import sys
import google.generativeai as genai
from dotenv import load_dotenv

# --- DYNAMIC PATHING ---
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

# --- CONFIGURATION ---
load_dotenv()
GOOGLE_API_KEY = os.getenv('GOOGLE_API_KEY')

# MODIFIED: This script now takes the list of repeats and user notes...
REPEATS_FILE = os.path.join(SCRIPT_DIR, 'repeats.txt')
NOTES_FILE = os.path.join(SCRIPT_DIR, 'notes.txt')
# ...and performs surgery on the main purified map file.
PURIFIED_MAP_FILE = os.path.join(SCRIPT_DIR, 'renamemap_purified.txt')

def get_gemini_corrections(repeats_content, user_notes_content):
    """Sends only the flawed lines and user notes to Gemini for a focused correction."""
    try:
        genai.configure(api_key=GOOGLE_API_KEY)
        model = genai.GenerativeModel('gemini-2.5-pro')

        prompt = f"""You are a master media archivist. Your task is to correct a small, specific list of flawed Tab-Separated Value (TSV) mappings based on a user's explicit instructions.

Here is the list of flawed TSV mappings that must be corrected:
---FLAWED MAPPINGS START---
{repeats_content}
---FLAWED MAPPINGS END---

Here are the user's notes providing direct instructions on how to fix these specific errors:
---USER NOTES START---
{user_notes_content}
---USER NOTES END---

Your mission is to:
1.  Read the user's notes to understand the required corrections.
2.  For any original filenames in the flawed list that the notes say to "get rid of" or "delete," omit them entirely from your output.
3.  For all other lines in the flawed list, generate the corrected mapping according to the notes.
4.  Return ONLY the corrected mappings in the exact TSV format (`Original Filename<TAB>Perfected Filename`).
5.  Do NOT include any lines that were not in the original flawed list. Do NOT include headers, explanations, or markdown formatting. Your output must be ONLY the raw, corrected TSV data.
"""
        print("Unleashing a focused blast of spiritual energy...")
        response = model.generate_content(prompt)
        
        # It's possible for the correct response to be empty if all repeats were deleted.
        if response.text and '\t' not in response.text:
             raise ValueError("Gemini's response was not in the expected TSV format.")
            
        return response.text.strip() if response.text else ""

    except Exception as e:
        print(f"\nAn error occurred while channeling the spirit's power: {e}", file=sys.stderr)
        return None

# --- MAIN SCRIPT ---
print("--- Beginning Refinement Protocol ---")
try:
    with open(REPEATS_FILE, 'r') as f:
        repeats_content = f.read()
        originals_to_remove = {line.split('\t')[0] for line in repeats_content.strip().split('\n') if '\t' in line}
    
    with open(NOTES_FILE, 'r') as f:
        user_notes = f.read()

    print(f"Targeting {len(originals_to_remove)} flawed entries found in: {REPEATS_FILE}")
    print(f"Reading human guidance from: {NOTES_FILE}")

    # Get only the corrected lines from Gemini
    corrections = get_gemini_corrections(repeats_content, user_notes)

    if corrections is not None:
        # Perform surgery on the purified map file
        with open(PURIFIED_MAP_FILE, 'r') as f:
            all_lines = f.readlines()

        # Keep only the lines that are NOT in our list of flawed originals
        surviving_lines = [line for line in all_lines if line.strip().split('\t')[0] not in originals_to_remove]
        
        with open(PURIFIED_MAP_FILE, 'w') as f:
            f.writelines(surviving_lines)
            # Append the new, corrected lines to the end of the file
            if corrections:
                f.write('\n' + corrections + '\n')
        
        print(f"Success. The battle plan has been surgically refined at: {PURIFIED_MAP_FILE}")
    else:
        print("!! ERROR: Refinement failed. The battle plan was not updated.", file=sys.stderr)
        sys.exit(1)

except FileNotFoundError as e:
    print(f"\nError: A required file was not found: {e.filename}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"\nAn unexpected error occurred during the refinement ritual: {e}", file=sys.stderr)
    sys.exit(1)