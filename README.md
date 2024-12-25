# DNN-DynamicTruncateEventLogs
Automates truncation of log tables in non-system databases within SQL Server Always On Availability Groups. Supports dry runs, dynamic foreign key handling, detailed HTML logs, and email notifications. Ideal for DNN or similar environments.

Overview

DynamicTruncateEventLogs.ps1 is a PowerShell script designed to manage and truncate event logs across all non-system databases hosted on primary replicas within SQL Server Always On Availability Groups. The script can perform either a dry run or actual truncation, providing comprehensive logging and sending summary reports via email.
Features

    Dry Run or Actual Truncation: Choose to simulate the truncation process without making changes or execute the truncation.
    Automated Logging: Generates detailed HTML log files capturing the process.
    Email Notifications: Sends summary emails upon completion.
    Handles Multiple SQL Instances: Supports managing multiple SQL Server instances.
    Dynamic Foreign Key Constraint Management: Drops and recreates foreign key constraints as needed during truncation.
    Integration with dbatools: Utilizes the dbatools PowerShell module for SQL Server management.

Prerequisites

    PowerShell 5.1 or Later: Ensure you have the required version of PowerShell installed.

    dbatools Module: The script relies on the dbatools PowerShell module. Install it using:

    Install-Module dbatools -Scope CurrentUser

    SQL Server Access: Appropriate permissions to access and modify the target SQL Server databases.

    SMTP Server Access: Credentials and access to an SMTP server for sending email notifications.

    Encrypted SMTP Password File: The SMTP password should be stored securely in an encrypted file.

Configuration

Before running the script, configure the following parameters:
SMTP Configuration

Set up the SMTP settings to enable email notifications.

# === SMTP Configuration ===
$smtpServer = "your.mail.server"                        # Replace with your SMTP server
$smtpPort = 587                                         # Common ports: 25, 587, 465
$smtpUser = "username@email.com"                        # Replace with your SMTP username
$smtpPasswordPath = "C:\yourpath\smtp_password.txt"      # Path to encrypted SMTP password file
$senderEmail = "your@email.com"                         # Replace with sender email
$recipientEmail = "recipient@email.com"                 # Replace with recipient email
$emailSubject = "Log Truncation Summary - $(Get-Date -Format 'yyyy-MM-dd')"
$emailBody = "Please find attached the summary of the log truncation process."

    SMTP Server: Specify your SMTP server address.

    SMTP Port: Common ports include 25, 587, and 465.

    SMTP User: Your SMTP username.

    SMTP Password Path: Path to the encrypted SMTP password file. To create an encrypted password file:

    Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File "C:\yourpath\smtp_password.txt"

    Enter the SMTP password when prompted.

    Sender and Recipient Emails: Specify the sender and recipient email addresses.

    Email Subject and Body: Customize as needed.

Tables to Truncate

Specify the list of tables to truncate:

# === Tables to Truncate ===
$tablesToTruncate = @('EventLog', 'Exceptions', 'ExceptionEvents', 'ScheduleHistory')

Logging Configuration

Set the path for log files:

# === Logging Configuration ===
$logPath = "C:\yourlogpath\"         # Ensure this path exists or will be created

Ensure the specified log path exists or the script will create it.
Dry Run Configuration

Set whether to perform a dry run or execute truncation:

# === Dry Run Configuration ===
# Set $dryRun to $true for dry run, $false for actual truncation
$dryRun = $false

    $dryRun = $true: Simulates the truncation process without making changes.
    $dryRun = $false: Executes the truncation.

SQL Server Instances

Specify the SQL Server instances to manage:

# Retrieve Primary Replicas
$sqlInstances = @(
    "INSTANCE1",  # Replace with your SQL Server instance names
    "INSTANCE2"
    # Add more instances as needed
)

Replace "INSTANCE1" and "INSTANCE2" with your actual SQL Server instance names. Add more instances to the array as needed.
Usage

    Configure the Script: Update the configuration parameters as described above.

    Prepare the SMTP Password File: Create an encrypted password file for the SMTP credentials.

Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File "C:\yourpath\smtp_password.txt"

Enter the SMTP password when prompted.

Run the Script: Execute the script in PowerShell.

    .\DynamicTruncateEventLogs.ps1

    Ensure you run PowerShell with sufficient permissions to access and modify SQL Server databases.

    Monitor Execution: The script will log messages to the console and generate an HTML log file at the specified $logPath.

    Review Email Summary: After execution, a summary email will be sent to the specified recipient with the log file attached.

Script Details
Main Components

    Import dbatools Module: The script starts by importing the dbatools module for SQL Server management.

    Configuration Parameters: SMTP settings, tables to truncate, logging paths, dry run settings, and SQL Server instances.

    Function Definitions:
        Get-SMTPPassword: Loads the encrypted SMTP password.
        Log-Message: Logs messages to both the console and the HTML log file with appropriate levels (INFO, WARNING, ERROR).
        Perform-LogTruncation: Core function that handles truncation of logs for each database, including foreign key constraint management and DNN version checks.

    Main Execution:
        Initializes HTML log content.
        Loads SMTP credentials.
        Retrieves primary replicas from specified SQL Server instances.
        Iterates through each primary replica and processes user databases.
        Finalizes the HTML log and saves it.
        Sends a summary email with the log file attached.
        Outputs an execution summary to the console.

Logging

    Logs are written both to the console and to an HTML file for easy review.
    The HTML log includes color-coded messages based on severity levels.

Error Handling

    The script includes comprehensive error handling, logging errors, and continuing processing as appropriate.
    If critical errors occur (e.g., unable to retrieve SMTP password), the script will exit with an error.

Extensibility

    You can customize the list of tables to truncate by modifying the $tablesToTruncate array.
    Add or remove SQL Server instances as needed in the $sqlInstances array.

Security Considerations

    Secure SMTP Password Storage: The SMTP password is stored in an encrypted file. Ensure the file is stored securely and access is restricted.
    Execution Permissions: Run the script with a user account that has the necessary permissions to perform truncations on SQL Server databases.
    Logging Sensitive Information: Be cautious of logging sensitive data. Review log contents to ensure compliance with your organization's security policies.
