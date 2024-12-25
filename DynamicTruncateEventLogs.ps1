# =============================================================================
# Script Name: DynamicTruncateEventLogs.ps1
# Description: Performs a dry run or actual truncation of logs across all non-system
#              databases on primary replicas within SQL Server Always On Availability Groups.
#              Sends a summary email and generates detailed log files.
# =============================================================================

# Import dbatools module
Import-Module dbatools

# ---------------------------
# Configuration Parameters
# ---------------------------

# === SMTP Configuration ===
$smtpServer = "your.mail.server"                        # Replace with your SMTP server
$smtpPort = 587                                            # Common ports: 25, 587, 465
$smtpUser = "username@email.com"                         # Replace with your SMTP username
$smtpPasswordPath = "C:\yourpath\smtp_password.txt"      # Path to encrypted SMTP password file
$senderEmail = "your@email.com"                      # Replace with sender email
$recipientEmail = "recipient@email.com"                   # Replace with recipient email
$emailSubject = "Log Truncation Summary - $(Get-Date -Format 'yyyy-MM-dd')"
$emailBody = "Please find attached the summary of the log truncation process."

# === Tables to Truncate ===
$tablesToTruncate = @('EventLog', 'Exceptions', 'ExceptionEvents', 'ScheduleHistory')

# === Logging Configuration ===
$logPath = "C:\yourlogpath\"         # Ensure this path exists or will be created
if (!(Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}
$logFileName = "LogTruncationSummary_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$logFilePath = Join-Path -Path $logPath -ChildPath $logFileName

# === Dry Run Configuration ===
# Set $dryRun to $true for dry run, $false for actual truncation
$dryRun = $false

# ---------------------------
# Function Definitions
# ---------------------------

# Function to Load Encrypted SMTP Password
function Get-SMTPPassword {
    param (
        [string]$Path
    )
    try {
        if (!(Test-Path -Path $Path)) {
            throw "Encrypted SMTP password file not found at path: $Path"
        }
        $encryptedPassword = Get-Content $Path | ConvertTo-SecureString
        return $encryptedPassword
    }
    catch {
        Write-Error "Failed to retrieve SMTP password from $Path. $_"
        exit 1
    }
}

# Function to Log Messages to Console and HTML Log
function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO"  # Levels: INFO, WARNING, ERROR
    )

    # Define color based on level
    switch ($Level.ToUpper()) {
        "INFO" { $color = "Black" }
        "WARNING" { $color = "Yellow" }
        "ERROR" { $color = "Red" }
        default { $color = "Black" }
    }

    # Write to Console
    Write-Host $Message -ForegroundColor $color

    # Append to HTML Log
    switch ($Level.ToUpper()) {
        "INFO" { $levelClass = "info" }
        "WARNING" { $levelClass = "warning" }
        "ERROR" { $levelClass = "error" }
        default { $levelClass = "info" }
    }
    $global:logContent += "<p class='$levelClass'>$Message</p>`n"
}

function Perform-LogTruncation {
    param (
        [string]$SqlInstance,
        [string]$DatabaseName
    )

    Log-Message "----------------------------------------" "INFO"
    Log-Message "Processing Database: '$DatabaseName' on Instance: '$SqlInstance'" "INFO"

    try {
        Log-Message "Checking if database '$DatabaseName' is on the primary replica..." "INFO"
        $agDatabase = Get-DbaAgDatabase -SqlInstance $SqlInstance -Database $DatabaseName -ErrorAction Stop

        if ($agDatabase.LocalReplicaRole -ne "Primary") {
            Log-Message "Database '$DatabaseName' is not on the Primary replica. Skipping." "WARNING"
            return
        }

        if ($agDatabase.SynchronizationState -ne "Synchronized") {
            Log-Message "Database '$DatabaseName' is not in a synchronized state. Skipping." "WARNING"
            return
        }
    } catch {
        Log-Message "Error determining database role or synchronization state for '$DatabaseName': $_" "ERROR"
        return
    }

    # Check DNN Version
    try {
        $versionQuery = "SELECT TOP(1) (Major * 10000 + Minor * 100 + Build) AS Version FROM [Version] ORDER BY CreatedDate DESC"
        $versionResult = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $versionQuery -ErrorAction Stop
        $dnnVersion = $versionResult.Version
        Log-Message "DNN Version for database '$DatabaseName': $dnnVersion" "INFO"
    } catch {
        Log-Message "Failed to determine DNN version for database '$DatabaseName'. Skipping." "ERROR"
        return
    }

    $tablesToTruncate = @("ScheduleHistory", "ExceptionEvents", "Exceptions", "EventLog")

    foreach ($table in $tablesToTruncate) {
        try {
            # Drop foreign key constraints dynamically
            Log-Message "Dropping foreign key constraints for table '$table'..." "INFO"
            $dropFKQuery = @"
DECLARE @constraintName NVARCHAR(128);
DECLARE fk_cursor CURSOR FOR
SELECT name 
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID(N'[$table]');
OPEN fk_cursor;
FETCH NEXT FROM fk_cursor INTO @constraintName;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('ALTER TABLE [$table] DROP CONSTRAINT ' + @constraintName);
    FETCH NEXT FROM fk_cursor INTO @constraintName;
END;
CLOSE fk_cursor;
DEALLOCATE fk_cursor;
"@
            Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $dropFKQuery -ErrorAction Stop

            # Verify no constraints remain
            $checkConstraintsQuery = "SELECT COUNT(*) AS ConstraintCount FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'[$table]')"
            $constraintCheckResult = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $checkConstraintsQuery -ErrorAction Stop
            if ($constraintCheckResult.ConstraintCount -gt 0) {
                throw "Constraints still exist for table '$table'."
            }
            Log-Message "Dropped all foreign key constraints for table '$table'." "INFO"
        } catch {
            Log-Message "Failed to drop foreign key constraints for table '$table' in database '$DatabaseName'. Error: $_" "ERROR"
            continue
        }

        # Get row count before truncation
        try {
            $rowCountBeforeQuery = "SELECT COUNT(*) AS [RowCount] FROM [$table]"
            $rowCountBeforeResult = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $rowCountBeforeQuery -ErrorAction Stop
            $rowCountBefore = $rowCountBeforeResult.RowCount
            Log-Message "Table '$table' in database '$DatabaseName' has $rowCountBefore rows before truncation." "INFO"
        } catch {
            Log-Message "Failed to retrieve row count for table '$table' in database '$DatabaseName'. Error: $_" "ERROR"
            continue
        }

        if (-not $dryRun) {
            try {
                # Truncate the table
                $truncateQuery = "TRUNCATE TABLE [$table]"
                Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $truncateQuery -ErrorAction Stop
                Log-Message "Successfully truncated table '$table' in database '$DatabaseName'." "INFO"
            } catch {
                Log-Message "Failed to truncate table '$table' in database '$DatabaseName'. Error: $_" "ERROR"
                continue
            }
        } else {
            Log-Message "Dry Run: Would truncate table '$table' in database '$DatabaseName'." "INFO"
        }
    }

    if ($dnnVersion -ge 70400 -and -not $dryRun) {
        try {
            # Recreate foreign key constraints for EventLog
            Log-Message "Recreating foreign key constraints for EventLog..." "INFO"
            $recreateFKQuery = @"
ALTER TABLE [ExceptionEvents]
    ADD CONSTRAINT FK_ExceptionEvents_EventLog
    FOREIGN KEY (LogEventID) REFERENCES EventLog (LogEventID) ON DELETE CASCADE;
ALTER TABLE [EventLog]
    ADD CONSTRAINT FK_EventLog_Exceptions
    FOREIGN KEY (ExceptionHash) REFERENCES Exceptions (ExceptionHash) ON DELETE NO ACTION;
"@
            Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $recreateFKQuery -ErrorAction Stop
            Log-Message "Recreated foreign key constraints for EventLog." "INFO"
        } catch {
            Log-Message "Failed to recreate foreign key constraints for EventLog in database '$DatabaseName'. Error: $_" "ERROR"
        }
    }

    Log-Message "Completed processing database '$DatabaseName' on instance '$SqlInstance'." "INFO"
}


# Retrieve user databases dynamically
try {
    $databases = Get-DbaDatabase -SqlInstance $primary -ExcludeSystem -ErrorAction Stop

    # Validate the result
    if ($null -eq $databases -or $databases.Count -eq 0) {
        Log-Message "No user databases found on primary replica '$primary'. Skipping." "WARNING"
        continue
    }

    # Process each database
    foreach ($db in $databases) {
        if (-not $db.PSObject.Properties['Name']) {
            # Log a warning if the 'Name' property is missing
            Log-Message "Database object missing 'Name' property: $($db | Out-String). Skipping..." "WARNING"
            continue
        }

        # Extract database name and process it
        $dbName = $db.Name
        Log-Message "Processing database: '$dbName' on instance: '$primary'" "INFO"

        # Call the log truncation function
        Perform-LogTruncation -SqlInstance $primary -DatabaseName $dbName
    }
} catch {
    Log-Message "Failed to retrieve databases from primary replica '$primary'. Error: $_" "ERROR"
    continue
}

# ---------------------------
# Main Script Execution
# ---------------------------

# Initialize HTML Log Content
$global:logContent = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #2E8B57; }
        h2 { color: #4682B4; }
        h3 { color: #DAA520; }
        p.info { color: Black; }
        p.warning { color: Yellow; }
        p.error { color: Red; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
        th { background-color: #f2f2f2; }
        tr.success { background-color: #d4edda; }
        tr.failed { background-color: #f8d7da; }
    </style>
</head>
<body>
    <h1>Log Truncation Summary for $(Get-Date -Format 'yyyy-MM-dd')</h1>
"@

# Load SMTP Credentials
$smtpSecurePassword = Get-SMTPPassword -Path $smtpPasswordPath
$smtpCredential = New-Object System.Management.Automation.PSCredential ($smtpUser, $smtpSecurePassword)

# Retrieve Primary Replicas
$sqlInstances = @(
    "INSTANCE1",  # Replace with your SQL Server instance names
    "INSTANCE2"
    # Add more instances as needed
)
$primaryReplicas = Get-PrimaryReplicas -SqlInstances $sqlInstances

if ($primaryReplicas.Count -eq 0) {
    Log-Message "No primary replicas found. Exiting script." "ERROR"
    exit 1
}

# Iterate Through Each Primary Replica and Retrieve Databases
foreach ($primary in $primaryReplicas) {
    Log-Message "Connecting to Primary Replica: '$primary'" "INFO"

    # Retrieve user databases dynamically
    try {
        $databases = Get-DbaDatabase -SqlInstance $primary -ExcludeSystem -ErrorAction Stop
        $databaseNames = $databases | Select-Object -ExpandProperty Name
    } catch {
        Log-Message "Failed to retrieve databases from primary replica '$primary'. Error: $_" "ERROR"
        continue
    }

    if ($databaseNames.Count -eq 0) {
        Log-Message "No user databases found on primary replica '$primary'. Skipping." "WARNING"
        continue
    }

    foreach ($db in $databaseNames) {
        Perform-LogTruncation -SqlInstance $primary -DatabaseName $db
    }
}

# Finalize HTML Log Content
$global:logContent += "</body></html>"

# Save HTML Summary to File
$summaryHtmlPath = $logFilePath
$global:logContent | Out-File -FilePath $summaryHtmlPath -Encoding UTF8

# Send Summary Email
try {
    Send-MailMessage -From $senderEmail `
                     -To $recipientEmail `
                     -Subject $emailSubject `
                     -Body $emailBody `
                     -BodyAsHtml `
                     -Attachments $summaryHtmlPath `
                     -SmtpServer $smtpServer `
                     -Port $smtpPort `
                     -UseSsl `
                     -Credential $smtpCredential

    Log-Message "Summary email sent successfully to '$recipientEmail'." "INFO"
}
catch {
    Log-Message "Failed to send summary email. Error: $_" "ERROR"
}

# Append Log to HTML Content
$global:logContent += @"
    <h2>Detailed Log</h2>
    <pre>
        $(Get-Content -Path $summaryHtmlPath | Out-String)
    </pre>
    <p>Generated by DynamicTruncateEventLogs.ps1</p>
</body>
</html>
"@

# Update the log file with detailed log
$global:logContent | Out-File -FilePath $summaryHtmlPath -Encoding UTF8

# Execution Summary Output
$totalDatabases = $databaseNames.Count
$processedDatabases = $databaseNames.Count
$failedDatabases = ($logContent -split "`n" | Where-Object { $_ -like "*Failed to process*" }).Count

Log-Message "===============================" "INFO"
Log-Message "Execution Summary:" "INFO"
Log-Message "Total Databases     : $totalDatabases" "INFO"
Log-Message "Processed Databases : $processedDatabases" "INFO"
Log-Message "Failed Databases    : $failedDatabases" "INFO"
Log-Message "Detailed log saved at: $summaryHtmlPath" "INFO"
Log-Message "===============================" "INFO"
Log-Message "Execution completed at: $(Get-Date)" "INFO"
