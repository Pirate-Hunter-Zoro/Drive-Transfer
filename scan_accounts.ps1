$searchString = 'The Way of the Househusband'
$password = Get-Content -Path "scripts/scan_account_password.txt"

for ($accountNumber = 1; $accountNumber -le 104; $accountNumber++) {

    $email = "mikeyferguson49+anime_$($accountNumber)@icloud.com"
    $logFile = "scripts/found_files_log.txt"

    # Announce which account is being checked
    Write-Output ">>> Checking Account: $email"

    # Login to MEGA
    # The & operator is used to execute the command
    & "mega-login" $email $password

    # Check if login was successful before proceeding
    # mega-whoami will output information if logged in, or an error if not.
    $whoamiOutput = & "mega-whoami" 2>&1
    if ($whoamiOutput -like "*Not logged in*") {
        Write-Error "Login failed for $email. Please check credentials and account status."
    }
    else {
        Write-Output "Login successful. Searching for '$searchString'..."
        
        # Search for the file string and append to a log file
        & "mega-find" "*$searchString*" | ForEach-Object {
            if ($_ -ne $null -and $_.Length -gt 0) {
                $logEntry = "Found in account [$email]: $_"
                Write-Output $logEntry
                Add-Content -Path $logFile -Value $logEntry
            }
        }
        
        # Logout of the account to be clean
        Write-Output "Logging out of $email."
        & "mega-logout"
    }

    Write-Output ">>> Finished check for $email."

}