# Upgrade-Win11-To-25H2.ps1

A reliable, production-ready PowerShell module to automate upgrading Windows 11 from 24H2 to 25H2 via the official enablement package (KB5054156). Features architecture detection, signature validation, BITS download with retry logic, silent installation, configurable reboot behavior, and transcript logging.

## Table of Contents

1. [Introduction](#1-introduction)  
2. [Features](#2-features)  
3. [Requirements](#3-requirements)  
4. [Installation](#4-installation)  
5. [Setup](#5-setup):         
         -          [Administrator Privileges](#51-administrator-privileges)
         -          [Execution Policy](#52-execution-policy)
6. [Usage](#6-usage):         
         -          [Basic Run](#61-basic-run)
         -          [Parameters](#62-parameters)
         -          [Examples](#63-examples)  
7. [Logging](#7-logging)  
8. [Error Handling](#8-error-handling)  
9. [Contributing](#9-contributing)  
10. [License](#10-license)  

---

## 1. Introduction

`Upgrade-Win11-To-25H2.ps1` streamlines the one-minute upgrade process for Windows 11 24H2 to 25H2 by leveraging the official enablement package (eKB KB5054156). It supports both x64 and ARM64 architectures, automatically detects or prompts architecture choice, validates digital signatures, and manages reboots—all with robust error handling and detailed logging.

## 2. Features

- Automatic OS version check (requires Windows 11 24H2 Build 26100.5074+).  
- Auto-detects or prompts for CPU architecture (x64/ARM64).  
- Resilient download via BITS with fallback to HTTP and configurable retries.  
- Verifies MSU Authenticode signature to ensure authenticity.  
- Silent installation through `wusa.exe` with controlled reboot options.  
- Transcript logging for audit and troubleshooting.  
- Clean, modular, object-oriented design with typed enums and match expressions.  

## 3. Requirements

- Windows 11, version 24H2 (Build 26100.5074 or later)  
- PowerShell 7+  
- Administrative privileges  
- Execution policy set to allow script execution (`Unrestricted`, `RemoteSigned`, etc.)  

## 4. Installation

1. Clone or download this repository.  
2. Place `Upgrade-Win11-To-25H2.ps1` in your desired scripts folder.  

## 5. Setup

### 5.1. Administrator Privileges

**This script MUST be run as Administrator** to install the Windows update. Right-click on PowerShell and select "Run as Administrator" or use one of these methods:

**Method 1: Windows Terminal**
1. Open Windows Terminal as Administrator
2. Navigate to the script directory
3. Run the script

**Method 2: Command Line**
```cmd
powershell.exe -Command "Start-Process PowerShell -Verb RunAs"
```

### 5.2. Execution Policy

If you encounter the error "execution of scripts is disabled on this system", you need to adjust the PowerShell execution policy.

#### Option 1: One-time bypass (Recommended for security)
```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1"
```

#### Option 2: Set policy for current user
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

#### Option 3: Temporary session policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

**Security Note:** `RemoteSigned` allows locally created scripts to run without a signature while requiring signatures for downloaded scripts. This provides a good balance of security and usability.

## 6. Usage

### 6.1. Basic Run

Open PowerShell **as Administrator** and execute:

```powershell
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

### 6.2. Parameters

| Parameter      | Type                   | Default                 | Description                                                                              |
|----------------|------------------------|-------------------------|------------------------------------------------------------------------------------------|
| `-Reboot`      | `[RebootOption]`       | `Prompt`                | Reboot behavior after installation. Options: `Prompt`, `Force`, `None`.                  |
| `-NoRestart`   | `[switch]`             | `False`                 | Suppresses reboot entirely. Equates to `-Reboot None`.                                   |
| `-ForceReboot` | `[switch]`             | `False`                 | Forces immediate reboot on success. Equates to `-Reboot Force`.                          |
| `-RetryCount`  | `[int]`                | `3`                     | Number of download retry attempts (BITS/HTTP).                                           |
| `-RetryDelaySec`| `[int]`               | `5`                     | Delay in seconds between download retries.                                               |

### 6.3. Examples

1. **Default behavior (prompt to reboot)**  
   ```powershell
   .\Upgrade-Win11-To-25H2.ps1
   ```

2. **Force immediate reboot on success**  
   ```powershell
   .\Upgrade-Win11-To-25H2.ps1 -ForceReboot
   ```

3. **Suppress reboot entirely**  
   ```powershell
   .\Upgrade-Win11-To-25H2.ps1 -NoRestart
   ```

4. **Custom retry settings**  
   ```powershell
   .\Upgrade-Win11-To-25H2.ps1 -RetryCount 5 -RetryDelaySec 10
   ```

5. **One-time execution with policy bypass**
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1" -ForceReboot
   ```

## 7. Logging

All script actions and output are recorded via `Start-Transcript` to:
```
C:\ProgramData\Win11-25H2\Upgrade25H2_<Timestamp>.log
```
Use these logs for auditing, troubleshooting download or installation failures.

## 8. Error Handling

- The script throws descriptive errors if:
  - Not run as Administrator.  
  - Execution policy blocks script.  
  - OS build or UBR is unsupported.
  - System already has Windows 11 25H2 or later.
  - Download fails after retries.  
  - MSU signature is invalid.  
  - WUSA exit code is non-zero.  
- Errors are written via `Write-Error` and the script exits with code 1.

## 9. Contributing

Contributions welcome! Please submit pull requests for:
- Bug fixes  
- Feature enhancements (e.g., proxy support, localization)  
- Documentation improvements  

Follow standard GitHub workflow:
1. Fork repository  
2. Create feature branch  
3. Commit changes with clear messages  
4. Open a pull request  

## 10. License

Released under the [MIT License](LICENSE).
