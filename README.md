# DNN-DynamicTruncateEventLogs
Automates truncation of log tables in non-system databases within SQL Server Always On Availability Groups. Supports dry runs, dynamic foreign key handling, detailed HTML logs, and email notifications. Ideal for DNN or similar environments.

## Overview

`DynamicTruncateEventLogs.ps1` is a PowerShell script designed to truncate event logs across all non-system databases on primary replicas within SQL Server Always On Availability Groups. It supports both dry runs and actual truncations, provides comprehensive logging, and sends summary emails upon completion.

## Features

- **Dry Run or Actual Truncation**: Choose to simulate the truncation process or execute it.
- **Automated Logging**: Generates HTML log files detailing the process.
- **Email Notifications**: Sends summary emails with log attachments.
- **Supports Multiple SQL Instances**: Manage multiple SQL Server instances simultaneously.
- **Handles Foreign Key Constraints**: Automatically drops and recreates foreign key constraints as needed.
- **Integration with dbatools**: Utilizes the `dbatools` PowerShell module for efficient SQL Server management.

## Prerequisites

- **PowerShell 5.1 or Later**
- **dbatools Module**: Install using `Install-Module dbatools -Scope CurrentUser`
- **SQL Server Access**: Ensure you have the necessary permissions to access and modify the target databases.
- **SMTP Server Access**: Required for sending email notifications.
- **Encrypted SMTP Password File**: Store your SMTP password securely in an encrypted file.

## Configuration

Before running the script, update the following configuration parameters within the script:

### SMTP Configuration
Set up the SMTP settings to enable email notifications.
```
$smtpServer = "your.mail.server"                        # Your SMTP server
$smtpPort = 587                                         # SMTP port (e.g., 25, 587, 465)
$smtpUser = "username@email.com"                        # SMTP username
$smtpPasswordPath = "C:\yourpath\smtp_password.txt"      # Path to encrypted SMTP password
$senderEmail = "your@email.com"                         # Sender email address
$recipientEmail = "recipient@email.com"                 # Recipient email address
$emailSubject = "Log Truncation Summary - $(Get-Date -Format 'yyyy-MM-dd')"
$emailBody = "Please find attached the summary of the log truncation process."
```

### Create Encrypted SMTP Password File:
```
Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File "C:\yourpath\smtp_password.txt"
```

### Tables to Truncate
Specify the list of tables to truncate.
```
$tablesToTruncate = @('EventLog', 'Exceptions', 'ExceptionEvents', 'ScheduleHistory')
```

### Logging Configuration
Set the path for log files.
```
$logPath = "C:\yourlogpath\"         # Directory for log files
```

### Dry Run Configuration
Set whether to perform a dry run or execute truncation.
```
$dryRun = $false                      # Set to $true for dry run, $false for actual truncation
```

### SQL Server Instances
Specify the SQL Server instances to manage.
```
$sqlInstances = @(
    "INSTANCE1",  # Replace with your SQL Server instance names
    "INSTANCE2"
    # Add more instances as needed
)
```
