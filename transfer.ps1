<#
.SYNOPSIS
    Transfers video files from a Google Drive remote to multiple MEGA accounts using rclone and mega-cmd.

.DESCRIPTION
    This script handles the transfer of large video files (.mkv, .mp4)
    from a pre-configured rclone remote for Google Drive ('gdrive') to a series of
    MEGA.nz accounts. This is the definitive, corrected version.

.NOTES
    Author: Hiei
    Last Modified: 2025-07-31 (Definitive Version)
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
    # Corrected: The format string "sip" (Size, ID, Path) now
    # correctly matches the three headers provided to ConvertFrom-Csv.
    $csvHeader = "Size", "ID", "Path"
    $gdriveFiles = rclone lsf $gdriveRemote --include "*.{mkv,mp4}" --recursive --format "sip" --separator "," | ConvertFrom-Csv -Header $csvHeader -ErrorAction Stop
}
catch {
    Write-Error "Failed to get file list from rclone. Is '$gdriveRemote' configured correctly?"
    exit 1
}

Write-Host "Found $($gdriveFiles.Count) total video files. Beginning transfer process..."

foreach ($account in $accounts) {
    Write-Host "`n--- Processing account: $account ---"

    Write-Host "Ensuring previous session is terminated..."
    mega-logout

    Write-Host "Logging in..."
    mega-login $account $password

    Start-Sleep -Seconds 2
    
    Write-Host "Proceeding with file transfer for $account."

    $currentAccountSize = 0
    $accountLogFile = Join-Path $accountLogsDir "$($account).log"
    if (-not (Test-Path $accountLogFile)) {
        Add-Content -Path $accountLogFile -Value "--- Log for $($account) on $(Get-Date) ---"
    }

    foreach ($file in $gdriveFiles) {
        if ($processedIds.Contains($file.ID)) { continue }

        $fileSize = [long]$file.Size
        if (($currentAccountSize + $fileSize) -gt $maxSizeBytes) {
            Write-Host "Account storage limit reached. Moving to the next account."
            break
        }
        
        $fileName = [System.IO.Path]::GetFileName($file.Path)
        $fileName = $fileName.Replace(':', '-')
        
        $localFilePath = Join-Path $downloadDir $fileName
        
        # Corrected: The remote path is constructed by joining the remote name
        # (which already has a colon) and the file path. No extra colon.
        $remotePath = "$gdriveRemote$($file.Path)"

        Write-Host "Downloading '$fileName' ($([math]::Round($fileSize / 1MB, 2)) MB)..."
        rclone copyto $remotePath $localFilePath --progress

        Write-Host "Uploading '$fileName' to $account..."
        mega-put $localFilePath

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Upload of '$fileName' failed. Halting script to prevent data loss."
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