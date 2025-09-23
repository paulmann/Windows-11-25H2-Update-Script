# Upgrade-Win11-To-25H2.ps1

A reliable, production-ready PowerShell module to automate upgrading Windows 11 from 24H2 to 25H2 via the official enablement package (KB5054156). Features architecture detection, signature validation, BITS download with retry logic, silent installation, configurable reboot behavior, and transcript logging.

## Table of Contents

1. [Introduction](#1-introduction)  
2. [Features](#2-features)  
3. [Requirements](#3-requirements)  
4. [Installation](#4-installation)  
5. [Usage](#5-usage)  
   5.1. [Basic Run](#51-basic-run)  
   5.2. [Parameters](#52-parameters)  
   5.3. [Examples](#53-examples)  
6. [Logging](#6-logging)  
7. [Error Handling](#7-error-handling)  
8. [Contributing](#8-contributing)  
9. [License](#9-license)  

***

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
3. Ensure your PowerShell execution policy permits running unsigned scripts:  
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

## 5. Usage

### 5.1. Basic Run

Open PowerShell **as Administrator** and execute:

```powershell
.\Upgrade-Win11-To-25H2.ps1
```

By default, the script will:
1. Validate environment and OS version.  
2. Detect or prompt for architecture.  
3. Download KB5054156.  
4. Verify the MSU signature.  
5. Install the update silently.  
6. Prompt to reboot when complete.

### 5.2. Parameters

| Parameter      | Type                   | Default                 | Description                                                                              |
|----------------|------------------------|-------------------------|------------------------------------------------------------------------------------------|
| `-Reboot`      | `[RebootOption]`       | `Prompt`                | Reboot behavior after installation. Options: `Prompt`, `Force`, `None`.                  |
| `-NoRestart`   | `[switch]`             | `False`                 | Suppresses reboot entirely. Equates to `-Reboot None`.                                   |
| `-ForceReboot` | `[switch]`             | `False`                 | Forces immediate reboot on success. Equates to `-Reboot Force`.                          |
| `-RetryCount`  | `[int]`                | `3`                     | Number of download retry attempts (BITS/HTTP).                                           |
| `-RetryDelaySec`| `[int]`               | `5`                     | Delay in seconds between download retries.                                               |

### 5.3. Examples

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

## 6. Logging

All script actions and output are recorded via `Start-Transcript` to:
```
C:\ProgramData\Win11-25H2\Upgrade25H2_<Timestamp>.log
```
Use these logs for auditing, troubleshooting download or installation failures.

## 7. Error Handling

- The script throws descriptive errors if:
  - Not run as Administrator.  
  - Execution policy blocks script.  
  - OS build or UBR is unsupported.  
  - Download fails after retries.  
  - MSU signature is invalid.  
  - WUSA exit code is non-zero.  
- Errors are written via `Write-Error` and the script exits with code 1.

## 8. Contributing

Contributions welcome! Please submit pull requests for:
- Bug fixes  
- Feature enhancements (e.g., proxy support, localization)  
- Documentation improvements  

Follow standard GitHub workflow:
1. Fork repository  
2. Create feature branch  
3. Commit changes with clear messages  
4. Open a pull request  

## 9. License

Released under the [MIT License](LICENSE).
