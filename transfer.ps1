<#
.SYNOPSIS
    Transfers video files from a Google Drive remote to multiple MEGA accounts using rclone and mega-cmd.

.DESCRIPTION
    This script handles the transfer of large video files (.mkv, .mp4)
    from a pre-configured rclone remote for Google Drive ('gdrive') to a series of
    MEGA.nz accounts. This version uses direct account storage checking and a unified processed file log.

.NOTES
    Author: Hiei
    Last Modified: 2025-08-03 (Corrected storage parsing and rclone file listing)
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
$accountLogsDir = Join-Path $logsDir "account_contents"

# --- HELPER FUNCTION ---
# Interrogates mega-cmd for the current account's storage usage and returns it in bytes.
function Get-MegaUsageBytes {
    # The 'mega-df -h' command provides human-readable output that is parsed here.
    $output = mega-df -h 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get MEGA storage info. Output: $output"
        return $null
    }

    # --- MODIFICATION ---
    # Regex to capture the used storage value from the "USED STORAGE:" line.
    $match = $output | Select-String -Pattern 'USED STORAGE:\s*(\d+(?:\.\d+)?)\s*(GB|MB|KB|B)'
    # --- END MODIFICATION ---
    if ($match) {
        $value = [double]$match.Matches.Groups[1].Value
        $unit = $match.Matches.Groups[2].Value.ToUpper()
        
        switch ($unit) {
            "GB" { return [long]($value * 1GB) }
            "MB" { return [long]($value * 1MB) }
            "KB" { return [long]($value * 1KB) }
            "B"  { return [long]($value) }
            default { 
                Write-Warning "Unknown unit '$unit' in mega-df output. Assuming 0 bytes."
                return 0 
            }
        }
    } else {
        Write-Warning "Could not parse storage usage from 'mega-df' output. Assuming 0 bytes."
        Write-Warning "Output was: $output"
        return 0
    }
}
# --- END HELPER FUNCTION ---


Write-Host "Preparing directories..."
if (-not (Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
if (-not (Test-Path $accountLogsDir)) { New-Item -ItemType Directory -Path $accountLogsDir | Out-Null }

$password = Get-Content $passwordFile -TotalCount 1
if ([string]::IsNullOrWhiteSpace($password)) {
    Write-Error "Password file is empty or could not be read."
    exit 1
}

$accounts = Get-Content $accountsFile

# --- UNIFIED PROCESSED FILE TRACKING ---
Write-Host "Reading existing account logs to determine processed files..."
$processedFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
$existingLogFiles = Get-ChildItem -Path $accountLogsDir -Filter "*.log"
foreach ($logFile in $existingLogFiles) {
    Get-Content $logFile.FullName | Where-Object { -not $_.StartsWith("---") -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        [void]$processedFiles.Add($_)
    }
}
Write-Host "Found $($processedFiles.Count) previously processed files across all logs."

Write-Host "Fetching file list from Google Drive. This may take a moment..."
try {
    # --- MODIFICATION ---
    # Added --files-only to prevent rclone from listing directories.
    $csvHeader = "Size", "ID", "Path"
    $gdriveFiles = rclone lsf $gdriveRemote --include "*.{mkv,mp4}" --recursive --files-only --format "sip" --separator "," | ConvertFrom-Csv -Header $csvHeader -ErrorAction Stop
    # --- END MODIFICATION ---
}
catch {
    Write-Error "Failed to get file list from rclone. Is '$gdriveRemote' configured correctly?"
    exit 1
}

Write-Host "Found $($gdriveFiles.Count) total video files. Beginning transfer process..."

# --- Main processing loop. Iterates through all accounts from the beginning each time. ---
foreach ($account in $accounts) {
    Write-Host "`n--- Processing account: $account ---"

    Write-Host "Ensuring previous session is terminated..."
    mega-logout | Out-Null

    Write-Host "Logging in..."
    mega-login $account $password | Out-Null

    Start-Sleep -Seconds 2
    
    # --- DYNAMIC STORAGE CHECK ---
    Write-Host "Getting current storage usage for $account..."
    $currentAccountSize = Get-MegaUsageBytes
    if ($null -eq $currentAccountSize) {
        Write-Error "Could not determine storage for $account. Skipping account."
        continue
    }
    $usedSpaceGB = [math]::Round($currentAccountSize / 1GB, 2)
    Write-Host "Account currently has $usedSpaceGB GB used."
    
    if ($currentAccountSize -ge $maxSizeBytes) {
        Write-Host "Account is already full. Moving to the next account."
        continue
    }
    # --- END DYNAMIC STORAGE CHECK ---
    
    $accountLogFile = Join-Path $accountLogsDir "$($account).log"
    if (-not (Test-Path $accountLogFile)) {
        Add-Content -Path $accountLogFile -Value "--- Log for $($account) on $(Get-Date) ---"
    }

    foreach ($file in $gdriveFiles) {
        $fileName = [System.IO.Path]::GetFileName($file.Path)
        
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            # This should no longer happen with --files-only, but is kept for safety.
            Write-Warning "Could not determine filename for path: $($file.Path). Skipping."
            continue
        }

        if ($processedFiles.Contains($fileName)) { continue }

        $fileSize = [long]$file.Size
        
        if (($currentAccountSize + $fileSize) -gt $maxSizeBytes) {
            $requiredGB = [math]::Round(($currentAccountSize + $fileSize) / 1GB, 2)
            Write-Host "Account storage limit would be reached (Required: $requiredGB GB). Moving to the next account."
            break
        }
        
        $localFilePath = Join-Path $downloadDir $fileName
        $remotePath = "$gdriveRemote$($file.Path)"

        Write-Host "Downloading '$fileName' ($([math]::Round($fileSize / 1MB, 2)) MB)..."
        
        rclone copyto $remotePath $localFilePath --progress --multi-thread-streams 1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Download of '$fileName' failed. Skipping to next file."
            continue
        }

        Write-Host "Uploading '$fileName' to $account..."
        mega-put $localFilePath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Upload of '$fileName' failed. Halting script to prevent data loss."
            if (Test-Path $localFilePath) { Remove-Item $localFilePath }
            exit 1
        }

        Write-Host "Cleaning up local file..."
        Remove-Item $localFilePath

        [void]$processedFiles.Add($fileName)
        Add-Content -Path $accountLogFile -Value $fileName
        
        $currentAccountSize += $fileSize
        $usedSpaceGB = [math]::Round($currentAccountSize / 1GB, 2)
        Write-Host "File transferred. Current account usage estimate: $usedSpaceGB GB."
    }
}

Write-Host "`n--- All accounts processed. Final logout. ---"
mega-logout | Out-Null
Write-Host "The task is complete."