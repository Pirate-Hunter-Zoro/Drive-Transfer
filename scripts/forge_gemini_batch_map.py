import os
import google.generativeai as genai
from dotenv import load_dotenv

# --- DYNAMIC PATHING ---
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

# --- CONFIGURATION ---
load_dotenv() 
GOOGLE_API_KEY = os.getenv('GOOGLE_API_KEY')
BATCH_SIZE = 150 # Optimal size for efficiency and stability

# --- MODIFICATION: Input is now the master list, output will be a fresh renamemap.
INPUT_FILE = os.path.join(SCRIPT_DIR, 'file_list.txt') 
OUTPUT_FILE = os.path.join(SCRIPT_DIR, 'renamemap.txt')
FAILURE_LOG_FILE = os.path.join(SCRIPT_DIR, 'gemini_failures.txt')
# --- END MODIFICATION ---

def get_gemini_final_plan(filenames_list):
    try:
        genai.configure(api_key=GOOGLE_API_KEY)
        model = genai.GenerativeModel('gemini-2.5-pro') # Using 2.5 Pro for its larger context and reliability
        filenames_text = "\n".join(filenames_list)
        
        prompt = f"""You are a master media archivist with perfect knowledge of The Movie Database (TMDB). Your only task is to transform a list of chaotic filenames into the perfect, TMDB-compliant format.

The required output format is a Tab-Separated Value (TSV) list:
`Original Filename<TAB>Perfected Filename`

For TV shows, the format is `Show Name - SXXEXX.mkv`.
For movies, the format is `Movie Name (YYYY).mkv`.

Do not include a header or any explanation. For every single line of input, you must provide a corresponding line of output in the TSV format. Return ONLY the TSV data.

**EXAMPLE 1 (TV Show):**
INPUT: `[Kayoanime] Claymore - 01 - Great Sword.mkv`
OUTPUT: `[Kayoanime] Claymore - 01 - Great Sword.mkv	Claymore - S01E01.mkv`

**EXAMPLE 2 (Movie):**
INPUT: `1a. Ghost in the Shell - The Movie (1995 - 1080p DUAL Audio).mkv`
OUTPUT: `1a. Ghost in the Shell - The Movie (1995 - 1080p DUAL Audio).mkv	Ghost in the Shell (1995).mkv`

**EXAMPLE 3 (Complex TV Show):**
INPUT: `Eureka Seven AO - 01.mkv`
OUTPUT: `Eureka Seven AO - 01.mkv	Eureka Seven AO - S01E01.mkv`

Here is the complete list of filenames to process:
{filenames_text}
"""
        print("Unleashing the full power of Gemini...")
        response = model.generate_content(prompt)
        if '\t' not in response.text:
            raise ValueError("Gemini response is not in the expected TSV format.")
        return response.text.strip()
        
    except Exception as e:
        print(f"\nAn error occurred while channeling the spirit: {e}")
        return None

# --- MAIN SCRIPT ---
print("Preparing the final technique...")
# --- MODIFICATION: Overwrite output files at the start
with open(OUTPUT_FILE, 'w') as f: f.write('')
with open(FAILURE_LOG_FILE, 'w') as f: f.write('')
# --- END MODIFICATION ---

try:
    with open(INPUT_FILE, 'r') as infile:
        all_files = [line.strip() for line in infile if line.strip()]
    
    total_files = len(all_files)
    print(f"Found {total_files} total targets to interrogate.")

    # --- MODIFICATION: Process the entire list in batches
    for i in range(0, total_files, BATCH_SIZE):
        batch = all_files[i:i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        total_batches = (total_files + BATCH_SIZE - 1) // BATCH_SIZE
        
        print(f"\n--- Interrogating Batch {batch_num} of {total_batches} ---")
        
        response_text = get_gemini_final_plan(batch)
        
        if not response_text:
            print(f"!! WARNING: Gemini returned no confessions for batch {batch_num}. Logging failures.")
            with open(FAILURE_LOG_FILE, 'a') as fail_log:
                for filename in batch:
                    fail_log.write(f"{filename}\n")
            continue

        processed_in_batch = set()
        with open(OUTPUT_FILE, 'a') as outfile:
            for line in response_text.split('\n'):
                if '\t' in line:
                    original, perfected = line.strip().split('\t', 1)
                    outfile.write(f"{original}\t{perfected}\n")
                    processed_in_batch.add(original)

        # Log any files from the batch that Gemini didn't respond for
        unprocessed = [f for f in batch if f not in processed_in_batch]
        if unprocessed:
            print(f"!! WARNING: Gemini ignored {len(unprocessed)} targets in this batch. Logging them.")
            with open(FAILURE_LOG_FILE, 'a') as fail_log:
                for filename in unprocessed:
                    fail_log.write(f"{filename}\n")

    print(f"\n--- Interrogation Complete ---")
    print(f"Gemini's final plan has been written to: {OUTPUT_FILE}")
    print(f"Any targets that resisted interrogation are logged in: {FAILURE_LOG_FILE}")

except FileNotFoundError:
    print(f"\nError: Input file not found at {INPUT_FILE}.")
except Exception as e:
    print(f"\nAn unexpected error occurred during the ritual: {e}")