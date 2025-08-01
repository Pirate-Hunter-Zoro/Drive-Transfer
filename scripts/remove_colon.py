import os.path
import io

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# --- CONTROL ---
# Set to True to only see what would be renamed without making changes.
# Set to False to perform the actual renaming operation.
DRY_RUN = False
# ---------------

# This scope grants full read/write/modify access. Do not grant it lightly.
SCOPES = ['https://www.googleapis.com/auth/drive']

def main():
    """
    Finds all .mkv and .mp4 files owned by the user in Google Drive with a 
    colon in the name and replaces the colon with ' -'.
    """
    creds = None
    # The file token.json stores the user's access and refresh tokens.
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'client_secrets.json', SCOPES)
            creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())

    try:
        service = build('drive', 'v3', credentials=creds)

        if DRY_RUN:
            print("--- THIS IS A DRY RUN ---")
            print("No files will actually be renamed. Set DRY_RUN to False to execute.")
            print("-------------------------\n")

        page_token = None
        # Query for all .mkv and .mp4 files containing a colon, owned by you.
        query = "'me' in owners and name contains ':' and (fileExtension='mkv' or fileExtension='mp4')"
        
        print("Searching for files you own...")
        found_files = False

        while True:
            response = service.files().list(q=query,
                                            spaces='drive',
                                            fields='nextPageToken, files(id, name)',
                                            pageToken=page_token).execute()
            files = response.get('files', [])

            if files:
                found_files = True

            for file in files:
                original_name = file.get('name')
                file_id = file.get('id')
                
                # Replace all instances of the colon
                new_name = original_name.replace(':', ' -')

                # Only proceed if the name has actually changed
                if new_name != original_name:
                    if DRY_RUN:
                        print(f"[DRY RUN] Would rename '{original_name}' to '{new_name}'")
                    else:
                        print(f"Renaming '{original_name}' to '{new_name}'...")
                        file_metadata = {'name': new_name}
                        service.files().update(fileId=file_id, body=file_metadata).execute()

            page_token = response.get('nextPageToken', None)
            if page_token is None:
                break
        
        if not found_files:
            print("Hmph. No matching files were found in your territory.")

        if DRY_RUN:
             print("\nDry run complete. No changes were made.")
        else:
             print("\nFinished. The task is done.")

    except HttpError as error:
        print(f'An error occurred: {error}')


if __name__ == '__main__':
    main()