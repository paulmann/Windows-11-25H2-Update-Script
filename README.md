# Upgrade-Win11-To-25H2.ps1

A reliable, production-ready PowerShell module to automate upgrading Windows 11 from 24H2 to 25H2 via the official enablement package (KB5054156). Features architecture detection, signature validation, BITS download with retry logic, silent installation, configurable reboot behavior, and transcript logging.

## Table of Contents

- [Introduction](#introduction)  
- [Features](#features)  
- [Requirements](#requirements)  
- [Installation](#installation)  
  - [Using Git](#using-git)  
  - [Without Git](#without-git)  
- [Setup](#setup)  
  - [Administrator Privileges](#administrator-privileges)  
  - [Execution Policy](#execution-policy)  
- [Usage](#usage)  
  - [Basic Run](#basic-run)  
  - [Parameters](#parameters)  
  - [Examples](#examples)  
- [Logging](#logging)  
- [Error Handling](#error-handling)  
- [Contributing](#contributing)  
- [License](#license)  

---

## Introduction

`Upgrade-Win11-To-25H2.ps1` streamlines the one-minute upgrade process for Windows 11 24H2 to 25H2 by leveraging the official enablement package (eKB KB5054156). It supports both x64 and ARM64 architectures, automatically detects or prompts architecture choice, validates digital signatures, and manages reboots—all with robust error handling and detailed logging.

## Features

- Automatic OS version check (requires Windows 11 24H2 Build 26100.5074+).  
- Auto-detects or prompts for CPU architecture (x64/ARM64).  
- Resilient download via BITS with fallback to HTTP and configurable retries.  
- Verifies MSU Authenticode signature to ensure authenticity.  
- Silent installation through `wusa.exe` with controlled reboot options.  
- Transcript logging for audit and troubleshooting.  
- Clean, modular, object-oriented design with typed enums and match expressions.  

## Requirements

- Windows 11, version 24H2 (Build 26100.5074 or later)  
- PowerShell 5.1+  
- Administrative privileges  
- Execution policy set to allow script execution (`Unrestricted`, `RemoteSigned`, etc.)  

## Installation

### Using Git

If you have Git for Windows installed:

```
# Clone the repository via HTTPS
git clone https://github.com/paulmann/Windows-11-25H2-Update-Script.git
# Change to script directory
Set-Location .\Windows-11-25H2-Update-Script
```

### Without Git

If Git is not available, download and extract ZIP via PowerShell or CMD:

```
# Define variables
$zipUrl   = 'https://github.com/paulmann/Windows-11-25H2-Update-Script/archive/refs/heads/main.zip'
$zipPath  = "$env:TEMP\Win11Update.zip"
$destPath = "$env:USERPROFILE\Downloads\Windows-11-25H2-Update-Script"

# Download repository ZIP
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

# Extract to destination folder
Expand-Archive -Path $zipPath -DestinationPath $destPath -Force

# Change to script directory
Set-Location "$destPath\Windows-11-25H2-Update-Script-main"
```

Alternatively, using CMD with built-in tools:

```
curl -L -o "%TEMP%\Win11Update.zip" ^
  "https://github.com/paulmann/Windows-11-25H2-Update-Script/archive/refs/heads/main.zip"
powershell -Command "Expand-Archive -Path '%TEMP%\\Win11Update.zip' -DestinationPath '%USERPROFILE%\\Downloads\\Windows-11-25H2-Update-Script' -Force"
cd "%USERPROFILE%\Downloads\Windows-11-25H2-Update-Script\Windows-11-25H2-Update-Script-main"
```

After installation or extraction, ensure `Upgrade-Win11-To-25H2.ps1` is in your current directory.

## Setup

### Administrator Privileges

**This script MUST be run as Administrator** to install the Windows update. Right-click on PowerShell and select **Run as Administrator**, or use:

```
powershell.exe -Command "Start-Process PowerShell -Verb RunAs"
```

### Execution Policy

If you encounter “execution of scripts is disabled on this system”, adjust the execution policy:

- **One-time bypass** (recommended):
  ```
  powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1"
  ```
- **Set for current user**:
  ```
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  ```
- **Temporary session policy**:
  ```
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
  ```

*Security note:* `RemoteSigned` allows locally created scripts to run unsigned while requiring signatures for downloaded scripts.

## Usage

### Basic Run

Open PowerShell **as Administrator** and execute:

```
.\Upgrade-Win11-To-25H2.ps1
```

By default, the script will:  
1. Validate environment and OS version.  
2. Check if system already has Windows 11 25H2.  
3. Detect or prompt for architecture.  
4. Download KB5054156.  
5. Verify the MSU signature.  
6. Install the update silently.  
7. Prompt to reboot when complete.

### Parameters

| Parameter        | Type               | Default  | Description                                                             |
|------------------|--------------------|----------|-------------------------------------------------------------------------|
| `-Reboot`        | `[RebootOption]`   | `Prompt` | Reboot behavior: `Prompt`, `Force`, `None`.                             |
| `-NoRestart`     | `[switch]`         | `False`  | Suppress reboot entirely (`-Reboot None`).                              |
| `-ForceReboot`   | `[switch]`         | `False`  | Force immediate reboot on success (`-Reboot Force`).                    |
| `-RetryCount`    | `[int]`            | `3`      | Number of download retry attempts.                                      |
| `-RetryDelaySec` | `[int]`            | `5`      | Delay in seconds between retries.                                       |

### Examples

- **Default behavior (prompt to reboot):**  
  ```
  .\Upgrade-Win11-To-25H2.ps1
  ```
- **Force immediate reboot:**  
  ```
  .\Upgrade-Win11-To-25H2.ps1 -ForceReboot
  ```
- **Suppress reboot:**  
  ```
  .\Upgrade-Win11-To-25H2.ps1 -NoRestart
  ```
- **Custom retry settings:**  
  ```
  .\Upgrade-Win11-To-25H2.ps1 -RetryCount 5 -RetryDelaySec 10
  ```
- **One-time execution with bypass:**  
  ```
  powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1" -ForceReboot
  ```

## Logging

All actions are recorded via `Start-Transcript` to:

```
C:\ProgramData\Win11-25H2\Upgrade25H2_<Timestamp>.log
```

Use these logs for auditing and troubleshooting.

## Error Handling

The script writes descriptive errors and exits with code 1 if any of the following occur:

- Not run as Administrator.  
- Execution policy blocks script.  
- OS build or UBR is unsupported.  
- System already has Windows 11 25H2 or later.  
- Download fails after retries.  
- MSU signature is invalid.  
- WUSA exit code is non-zero.  

## Contributing

Contributions welcome! Submit pull requests for:

- Bug fixes  
- Feature enhancements (e.g., proxy support, localization)  
- Documentation improvements  

**Workflow:**

1. Fork the repository  
2. Create a feature branch  
3. Commit changes with clear messages  
4. Open a pull request  

## License

Released under the [MIT License](LICENSE).  
