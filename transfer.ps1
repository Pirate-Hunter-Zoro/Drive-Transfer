<#
.SYNOPSIS
    Transfers video files from a Google Drive remote to multiple MEGA accounts using rclone and mega-cmd.

.DESCRIPTION
    This script handles the transfer of large video files (.mkv, .mp4)
    from a pre-configured rclone remote for Google Drive ('gdrive') to a series of
    MEGA.nz accounts. This version includes resume capabilities.

.NOTES
    Author: Hiei
    Last Modified: 2025-08-02 (Resume Logic Added)
    Requires: rclone, mega-cmd (and to be in the system's PATH).
#>

# --- CONFIGURATION ---
# The name of your Google Drive rclone remote.
$gdriveRemote = "gdrive:"
# The directory where your account and password files are stored.
$scriptsDir = ".\scripts"
# The temporary directory for downloading files before they are uploaded.
$downloadDir = ".\downloads"
# The directory where logs will be stored.
$logsDir = ".\logs"
# The maximum storage to use per MEGA account. (19.5GB is a safe value).
$maxSizeBytes = 19.5 * 1GB
# --- END CONFIGURATION ---

# --- SCRIPT ---
$accountsFile = Join-Path $scriptsDir "accounts.txt"
$passwordFile = Join-Path $scriptsDir "passwords.txt"
$processedLog = Join-Path $logsDir "processed_files.log"
$accountLogsDir = Join-Path $logsDir "account_contents"

Write-Host "Preparing directories and logs..."
if (-not (Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
if (-not (Test-Path $accountLogsDir)) { New-Item -ItemType Directory -Path $accountLogsDir | Out-Null }
if (-not (Test-Path $processedLog)) { New-Item -ItemType File -Path $processedLog | Out-Null }

$password = Get-Content $passwordFile -TotalCount 1
if ([string]::IsNullOrWhiteSpace($password)) {
    Write-Error "Password file is empty or could not be read."
    exit 1
}

$accounts = Get-Content $accountsFile
$processedIds = New-Object System.Collections.Generic.HashSet[string]
Get-Content $processedLog | ForEach-Object { [void]$processedIds.Add($_) }

Write-Host "Fetching file list from Google Drive. This may take a moment..."
try {
    $csvHeader = "Size", "ID", "Path"
    $gdriveFiles = rclone lsf $gdriveRemote --include "*.{mkv,mp4}" --recursive --format "sip" --separator "," | ConvertFrom-Csv -Header $csvHeader -ErrorAction Stop
}
catch {
    Write-Error "Failed to get file list from rclone. Is '$gdriveRemote' configured correctly?"
    exit 1
}

Write-Host "Found $($gdriveFiles.Count) total video files. Beginning transfer process..."

# --- RESUME LOGIC ---
$startIndex = 0
$resumeAccountName = $null
$resumeAccountInitialSize = 0

Write-Host "Checking for previous sessions to resume..."
$lastLog = Get-ChildItem -Path $accountLogsDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($lastLog) {
    $resumeAccountName = $lastLog.BaseName
    $foundIndex = [array]::IndexOf($accounts, $resumeAccountName)

    if ($foundIndex -ge 0) {
        $startIndex = $foundIndex
        Write-Host "Found previous session. Resuming at account: $resumeAccountName"

        # Pre-calculate the size of files already in the resume account to properly track space.
        $accountLogFileForResume = Join-Path $accountLogsDir $lastLog.Name
        if (Test-Path $accountLogFileForResume) {
            # Create a quick lookup map for file sizes to avoid slow nested loops.
            $fileSizeMap = @{}
            $gdriveFiles | ForEach-Object { $fileSizeMap[$_.Path] = [long]$_.Size }

            # Read the log, ignoring the header line, and sum the sizes of already transferred files.
            Get-Content $accountLogFileForResume | Where-Object { -not $_.StartsWith("---") } | ForEach-Object {
                if ($fileSizeMap.ContainsKey($_)) {
                    $resumeAccountInitialSize += $fileSizeMap[$_]
                }
            }
            $usedSpaceGB = [math]::Round($resumeAccountInitialSize / 1GB, 2)
            Write-Host "Resume account '$resumeAccountName' already contains $usedSpaceGB GB of data."
        }
    }
    else {
        Write-Warning "Log file for '$resumeAccountName' found, but this account is not in accounts.txt. Starting from the beginning."
    }
}
else {
    Write-Host "No previous session logs found. Starting fresh."
}
# --- END RESUME LOGIC ---

for ($i = $startIndex; $i -lt $accounts.Count; $i++) {
    $account = $accounts[$i]
    Write-Host "`n--- Processing account: $account ---"

    Write-Host "Ensuring previous session is terminated..."
    mega-logout

    Write-Host "Logging in..."
    mega-login $account $password

    Start-Sleep -Seconds 2
    
    Write-Host "Proceeding with file transfer for $account."

    # If this is the account we're resuming, start with its previously calculated size.
    $currentAccountSize = 0
    if ($account -eq $resumeAccountName) {
        $currentAccountSize = $resumeAccountInitialSize
        # Clear the resume name so this logic only runs for the first account in the session.
        $resumeAccountName = $null 
    }
    
    $accountLogFile = Join-Path $accountLogsDir "$($account).log"
    if (-not (Test-Path $accountLogFile)) {
        Add-Content -Path $accountLogFile -Value "--- Log for $($account) on $(Get-Date) ---"
    }

    foreach ($file in $gdriveFiles) {
        if (-not $file -or [string]::IsNullOrWhiteSpace($file.Path)) {
            Write-Warning "Skipping a malformed or empty file entry from rclone output."
            continue
        }

        if ($processedIds.Contains($file.ID)) { continue }

        $fileSize = [long]$file.Size
        if (($currentAccountSize + $fileSize) -gt $maxSizeBytes) {
            Write-Host "Account storage limit reached. Moving to the next account."
            break
        }
        
        $fileName = [System.IO.Path]::GetFileName($file.Path)
        
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            Write-Warning "Could not determine filename for path: $($file.Path). Skipping."
            continue
        }

        $localFilePath = Join-Path $downloadDir $fileName
        $remotePath = "$gdriveRemote$($file.Path)"

        Write-Host "Downloading '$fileName' ($([math]::Round($fileSize / 1MB, 2)) MB)..."
        
        # --- CORRECTION ---
        # Replaced the unknown flag with one that limits streams to 1, effectively single-threading the download.
        rclone copyto $remotePath $localFilePath --progress --multi-thread-streams 1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Download of '$fileName' failed. Skipping to next file."
            continue
        }
        # --- END CORRECTION ---

        Write-Host "Uploading '$fileName' to $account..."
        mega-put $localFilePath

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Upload of '$fileName' failed. Halting script to prevent data loss."
            if (Test-Path $localFilePath) {
                Remove-Item $localFilePath
            }
            exit 1
        }

        Write-Host "Cleaning up local file..."
        Remove-Item $localFilePath

        [void]$processedIds.Add($file.ID)
        Add-Content -Path $processedLog -Value $file.ID
        Add-Content -Path $accountLogFile -Value $file.Path
        $currentAccountSize += $fileSize
        $usedSpaceGB = [math]::Round($currentAccountSize / 1GB, 2)
        Write-Host "File transferred. Current account usage: $usedSpaceGB GB."
    }
}

Write-Host "`n--- All accounts processed. Final logout. ---"
mega-logout
Write-Host "The task is complete."