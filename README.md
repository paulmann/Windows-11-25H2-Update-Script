# Windows 11 25H2 Update Script 🚀✨

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/paulmann/Windows-11-25H2-Update-Script)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Batch](https://img.shields.io/badge/batch-cmd-orange.svg)](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/cmd)
[![Platform](https://img.shields.io/badge/platform-Windows%2011-blue.svg)](https://www.microsoft.com/windows/)

> **A production-ready automation tool for seamlessly upgrading Windows 11 from 24H2 to 25H2 via official enablement package (KB5054156)**

Windows 11 25H2 Update Script is a robust, enterprise-grade automation solution designed to streamline the upgrade process from Windows 11 24H2 to 25H2. It supports both PowerShell and Batch file execution, automatically detects system architecture, validates digital signatures, and manages the complete upgrade workflow with comprehensive error handling and logging.

## ⚡ Quick Start

### PowerShell Version (Recommended)
```powershell
# Clone and install
git clone https://github.com/paulmann/Windows-11-25H2-Update-Script.git
cd Windows-11-25H2-Update-Script

# Run as Administrator
.\Upgrade-Win11-To-25H2.ps1

# With custom parameters
.\Upgrade-Win11-To-25H2.ps1 -ForceReboot -RetryCount 5

# One-time bypass execution policy
powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1"
```

### Batch Version (Alternative)
```cmd
# Download and run (Administrator required)
curl -L -o Upgrade-Win11-To-25H2.bat "https://github.com/paulmann/Windows-11-25H2-Update-Script/raw/main/Upgrade-Win11-To-25H2.bat"
Upgrade-Win11-To-25H2.bat

# Or run from repository
git clone https://github.com/paulmann/Windows-11-25H2-Update-Script.git
cd Windows-11-25H2-Update-Script
Upgrade-Win11-To-25H2.bat
```

## 📋 Table of Contents

- [🚀 Why Windows 11 25H2?](#-why-windows-11-25h2)
  - [The Enablement Package Advantage](#the-enablement-package-advantage)
  - [Real-World Benefits](#real-world-benefits)
- [✨ Key Features](#-key-features)
  - [🛡️ Enterprise-Grade Safety](#️-enterprise-grade-safety)
  - [🎯 Intelligent Processing](#-intelligent-processing)
  - [📊 Comprehensive Reporting](#-comprehensive-reporting)
  - [🔄 Multi-Format Support](#-multi-format-support)
- [📋 Installation & Usage](#-installation--usage)
  - [System Requirements](#system-requirements)
  - [Installation Options](#installation-options)
  - [PowerShell Setup](#powershell-setup)
  - [Batch File Setup](#batch-file-setup)
  - [Usage Examples](#usage-examples)
- [🏗️ Advanced Features](#️-advanced-features)
  - [Architecture Detection](#architecture-detection)
  - [Digital Signature Validation](#digital-signature-validation)
  - [Retry Logic](#retry-logic)
  - [Logging System](#logging-system)
- [🔗 DevOps Integration](#-devops-integration)
  - [CI/CD Pipeline Integration](#cicd-pipeline-integration)
  - [Group Policy Deployment](#group-policy-deployment)
  - [SCCM Integration](#sccm-integration)
- [🏢 Enterprise Usage](#-enterprise-usage)
  - [Mass Deployment](#mass-deployment)
  - [Automated Workflows](#automated-workflows)
  - [Monitoring and Reporting](#monitoring-and-reporting)
- [🔍 Troubleshooting](#-troubleshooting)
  - [Common Issues](#common-issues)
  - [Error Codes](#error-codes)
  - [Diagnostic Commands](#diagnostic-commands)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [👨‍💻 Author & Support](#-author--support)
- [🎯 Roadmap](#-roadmap)

## 🚀 Why Windows 11 25H2?

### The Enablement Package Advantage

Windows 11 25H2 uses the **enablement package (eKB)** technology, making the upgrade process incredibly efficient:

```powershell
# Traditional feature update: 3-5 GB download, 30+ minutes
# Enablement package: ~50 KB download, 1-2 minutes!

# Features are pre-staged in 24H2, just activated by eKB
Target Build: 26200.6718 (from 26100.5074+)
Package: KB5054156
```

### Real-World Benefits

- **⚡ Lightning Fast**: Upgrade completes in under 2 minutes with just a restart
- **📦 Minimal Download**: Tiny enablement package vs. multi-GB traditional updates
- **🔄 Shared Servicing**: Uses same servicing branch as 24H2 for compatibility
- **🛡️ Production Ready**: Leverages Microsoft's proven eKB technology
- **📈 Extended Support**: Fresh 24-36 month support lifecycle begins

## ✨ Key Features

### 🛡️ **Enterprise-Grade Safety**
- **Administrator Validation**: Automatic privilege checking with clear error messages
- **Digital Signature Verification**: Validates MSU package authenticity (PowerShell only)
- **System Compatibility**: Comprehensive build version and architecture checks
- **Rollback Protection**: Safe failure handling with detailed error reporting

### 🎯 **Intelligent Processing**
- **Architecture Detection**: Automatic x64/ARM64 detection with fallback prompts
- **Version Checking**: Smart detection of current build and upgrade requirements
- **Download Optimization**: BITS service with HTTP fallback and retry logic
- **Installation Control**: Silent installation with configurable reboot behavior

### 📊 **Comprehensive Reporting**
- **Detailed Logging**: Full transcript logging for audit and troubleshooting
- **Progress Tracking**: Real-time status updates with color-coded messages
- **Error Classification**: Structured error handling with resolution suggestions
- **Exit Code Management**: Standard exit codes for automated deployment

### 🔄 **Multi-Format Support**
- **PowerShell Version**: Full-featured with advanced error handling and logging
- **Batch Version**: Simplified alternative that works without ExecutionPolicy changes
- **Cross-Platform**: Both versions support x64 and ARM64 architectures
- **Deployment Ready**: Perfect for Group Policy, SCCM, or manual execution

## 📋 Installation & Usage

### System Requirements

- **Operating System**: Windows 11, version 24H2 (Build 26100.5074 or later)
- **Architecture**: x64 (AMD64) or ARM64
- **Privileges**: Administrator rights required
- **Network**: Internet connection for package download
- **PowerShell**: Version 5.1+ (for PowerShell script)
- **Execution Policy**: RemoteSigned or Unrestricted (for PowerShell script)

### Installation Options

#### Option 1: Git Clone
```bash
# Clone repository
git clone https://github.com/paulmann/Windows-11-25H2-Update-Script.git
cd Windows-11-25H2-Update-Script

# Choose your preferred version:
# PowerShell: .\Upgrade-Win11-To-25H2.ps1
# Batch:      .\Upgrade-Win11-To-25H2.bat
```

#### Option 2: Direct Download
```powershell
# PowerShell version
$url = 'https://github.com/paulmann/Windows-11-25H2-Update-Script/raw/main/Upgrade-Win11-To-25H2.ps1'
Invoke-WebRequest -Uri $url -OutFile 'Upgrade-Win11-To-25H2.ps1'

# Batch version
$url = 'https://github.com/paulmann/Windows-11-25H2-Update-Script/raw/main/Upgrade-Win11-To-25H2.bat'
Invoke-WebRequest -Uri $url -OutFile 'Upgrade-Win11-To-25H2.bat'
```

#### Option 3: Package Manager
```powershell
# Using PowerShell Gallery (future)
# Install-Script -Name Windows11-25H2-Update

# Using Chocolatey (future)
# choco install windows11-25h2-update
```

### PowerShell Setup

#### Administrator Privileges
**This script MUST be run as Administrator**. Right-click PowerShell and select **Run as Administrator**, or use:

```powershell
# Start PowerShell as Administrator
powershell.exe -Command "Start-Process PowerShell -Verb RunAs"
```

#### Execution Policy
If you encounter "execution of scripts is disabled on this system":

```powershell
# One-time bypass (recommended)
powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1"

# Set for current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Temporary session policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

### Batch File Setup

#### Administrator Privileges
**The batch file MUST also run as Administrator**:

```cmd
# Right-click on batch file → "Run as administrator"
# Or from Administrator Command Prompt:
cd /d "C:\path\to\script"
Upgrade-Win11-To-25H2.bat
```

#### Advantages of Batch Version
- ✅ **No ExecutionPolicy issues** - works out of the box
- ✅ **Simpler deployment** - single .bat file
- ✅ **Universal compatibility** - works on any Windows system
- ✅ **Group Policy friendly** - easier to deploy via GPO
- ❌ **No signature validation** - less security verification
- ❌ **Simpler error handling** - basic error reporting

### Usage Examples

#### PowerShell Usage

```powershell
# Basic usage with default settings
.\Upgrade-Win11-To-25H2.ps1

# Force immediate reboot after installation
.\Upgrade-Win11-To-25H2.ps1 -ForceReboot

# Suppress reboot (manual reboot required later)
.\Upgrade-Win11-To-25H2.ps1 -NoRestart

# Custom retry settings for unstable networks
.\Upgrade-Win11-To-25H2.ps1 -RetryCount 10 -RetryDelaySec 30

# One-time execution with bypass
powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1" -ForceReboot
```

#### Batch Usage

```cmd
REM Basic usage
Upgrade-Win11-To-25H2.bat

REM The batch version automatically handles:
REM - Architecture detection
REM - Download with retry logic  
REM - Installation with progress display
REM - Reboot prompting
```

#### Parameters Comparison

| Feature | PowerShell Version | Batch Version |
|---------|-------------------|---------------|
| **Reboot Control** | `-Reboot`, `-ForceReboot`, `-NoRestart` | Interactive prompt |
| **Retry Logic** | `-RetryCount`, `-RetryDelaySec` | Fixed (3 attempts, 5s delay) |
| **Logging** | Full transcript logging | Console output only |
| **Signature Check** | Yes (Get-AuthenticodeSignature) | No |
| **Error Handling** | Detailed with recommendations | Basic with codes |
| **ExecutionPolicy** | Required setup | Not applicable |

## 🏗️ Advanced Features

### Architecture Detection

Both scripts automatically detect your system architecture:

```powershell
# Automatic detection logic
if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
    $downloadUrl = $x64Url
} elseif ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    $downloadUrl = $arm64Url
} else {
    # Fallback to user prompt (PowerShell only)
    Write-Host "Unable to detect architecture automatically"
    $choice = Read-Host "Specify architecture (AMD64/ARM64) [Default: AMD64]"
}
```

**Supported URLs:**
- **x64**: KB5054156 for AMD64 architecture
- **ARM64**: KB5054156 for ARM64 architecture (Surface Pro X, etc.)

### Digital Signature Validation

PowerShell version includes comprehensive signature validation:

```powershell
# Signature validation process
$signature = Get-AuthenticodeSignature -FilePath $msuFile

# Verify signature status
if ($signature.Status -ne 'Valid') {
    throw "Invalid signature status: $($signature.Status)"
}

# Verify Microsoft as signer
if ($signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
    throw "Untrusted signer: $($signature.SignerCertificate.Subject)"
}
```

### Retry Logic

Robust download handling with configurable retry:

```powershell
# PowerShell retry logic
for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
    try {
        # Try BITS first, fallback to HTTP
        if (Get-Service -Name BITS -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $Uri -Destination $OutFile
        } else {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
        }
        break
    }
    catch {
        if ($attempt -lt $RetryCount) {
            Start-Sleep -Seconds $RetryDelaySec
        } else {
            throw "Failed after $RetryCount attempts"
        }
    }
}
```

### Logging System

**PowerShell Logging:**
```powershell
# Comprehensive logging location
$logPath = "C:\ProgramData\Win11-25H2\Upgrade_20251001_142530.log"

# Log levels: Info, Warning, Error, Success
Write-Log "Starting Windows 11 25H2 upgrade process" -Level Info
Write-Log "Administrator privileges confirmed" -Level Success
Write-Log "Retrying download in 5 seconds..." -Level Warning
Write-Log "Installation failed with exit code 2359302" -Level Error
```

**Batch Logging:**
```cmd
REM Basic console output with timestamps
echo [2025-10-01 14:25:30] [INFO] Starting update process
echo [2025-10-01 14:25:31] [SUCCESS] Administrator privileges confirmed
echo [2025-10-01 14:25:45] [WARNING] Download failed, retrying...
echo [2025-10-01 14:26:15] [SUCCESS] Installation completed successfully
```

## 🔗 DevOps Integration

### CI/CD Pipeline Integration

#### GitHub Actions

```yaml
name: Deploy Windows 11 25H2 Update
on:
  schedule:
    - cron: '0 2 * * 1' # Weekly on Monday 2 AM
  workflow_dispatch:

jobs:
  deploy-update:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy PowerShell Version
        run: |
          powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1" -NoRestart
        shell: cmd
        
      - name: Deploy Batch Version (Alternative)
        run: |
          .\Upgrade-Win11-To-25H2.bat
        shell: cmd
```

#### Azure DevOps

```yaml
trigger:
  branches:
    include:
    - main

pool:
  name: 'Windows-Agents'

steps:
- powershell: |
    .\Upgrade-Win11-To-25H2.ps1 -RetryCount 5 -RetryDelaySec 10
  displayName: 'Upgrade to Windows 11 25H2'
  
- script: |
    if errorlevel 3010 (
        echo Reboot required - scheduling maintenance window
    )
  displayName: 'Handle Reboot Requirements'
```

### Group Policy Deployment

Create a Group Policy Object (GPO) for mass deployment:

```powershell
# PowerShell script deployment via GPO
# Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown)
# Add: powershell.exe -ExecutionPolicy Bypass -File "\\domain\sysvol\scripts\Upgrade-Win11-To-25H2.ps1"

# Batch file deployment via GPO (simpler)
# Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown)  
# Add: \\domain\sysvol\scripts\Upgrade-Win11-To-25H2.bat
```

### SCCM Integration

**Application Deployment:**
```cmd
REM Detection Method
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild | find "26200"

REM Installation Command (PowerShell)
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ".\Upgrade-Win11-To-25H2.ps1" -NoRestart

REM Installation Command (Batch - Recommended for SCCM)
Upgrade-Win11-To-25H2.bat

REM Return Codes
REM 0 = Success
REM 3010 = Success, reboot required
REM 1 = Failure
```

## 🏢 Enterprise Usage

### Mass Deployment

#### PowerShell DSC Configuration
```powershell
Configuration Windows11_25H2_Update {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    
    Node "localhost" {
        Script UpdateWindows11 {
            SetScript = {
                & "C:\Scripts\Upgrade-Win11-To-25H2.ps1" -NoRestart
            }
            TestScript = {
                $build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
                return [int]$build -ge 26200
            }
            GetScript = {
                return @{ Result = "Windows 11 25H2 Update Status" }
            }
        }
    }
}
```

#### Intune Deployment (Win32 App)
```powershell
# Package the batch file for Intune deployment
# Create intunewin file with Microsoft Win32 Content Prep Tool

# Install command
cmd /c "Upgrade-Win11-To-25H2.bat"

# Detection rule
if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild -ge 26200) {
    Write-Output "Installed"
    exit 0
} else {
    exit 1
}

# Return codes
# 0 = Success
# 3010 = Success (reboot required)  
# Other = Failure
```

### Automated Workflows

#### Task Scheduler Integration
```xml
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2025-10-01T02:00:00</StartBoundary>
      <ScheduleByWeek>
        <WeeksInterval>1</WeeksInterval>
        <DaysOfWeek>
          <Monday />
        </DaysOfWeek>
      </ScheduleByWeek>
    </CalendarTrigger>
  </Triggers>
  <Actions>
    <Exec>
      <Command>C:\Scripts\Upgrade-Win11-To-25H2.bat</Command>
    </Exec>
  </Actions>
  <Principals>
    <Principal>
      <UserId>S-1-5-18</UserId> <!-- SYSTEM account -->
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
</Task>
```

### Monitoring and Reporting

#### Event Log Integration
```powershell
# PowerShell version writes to Application log
Write-EventLog -LogName Application -Source "Windows11Update" -EventId 1000 -Message "Upgrade started"

# Check upgrade status across domain
Get-ADComputer -Filter * | ForEach-Object {
    $build = Invoke-Command -ComputerName $_.Name -ScriptBlock {
        (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    } -ErrorAction SilentlyContinue
    
    [PSCustomObject]@{
        ComputerName = $_.Name
        CurrentBuild = $build
        Is25H2 = [int]$build -ge 26200
    }
} | Export-Csv "Windows11_25H2_Status.csv"
```

## 🔍 Troubleshooting

### Common Issues

#### Permission Errors
```cmd
REM Problem: "Access denied" or "Administrator privileges required"
REM Solution: Always run as Administrator

REM Check current privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Administrator privileges required
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)
```

#### ExecutionPolicy Issues (PowerShell Only)
```powershell
# Problem: "cannot be loaded because running scripts is disabled"
# Solution: Use one-time bypass or adjust policy

# Quick fix - one-time bypass
powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1"

# Permanent fix for current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Check current policy
Get-ExecutionPolicy -List
```

#### Download Failures
```powershell
# Problem: Network issues, proxy, or firewall blocking
# Solutions:

# 1. Check internet connectivity
Test-NetConnection -ComputerName catalog.sf.dl.delivery.mp.microsoft.com -Port 443

# 2. Configure proxy (if needed)
netsh winhttp set proxy proxy-server:8080

# 3. Temporarily disable antivirus/firewall
# 4. Use batch version (simpler HTTP handling)
```

#### System Compatibility
```powershell
# Problem: "Unsupported Windows version" 
# Check current build
$build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion")
Write-Host "Current Build: $($build.CurrentBuild).$($build.UBR)"

# Requirements:
# Minimum: 26100.5074 (Windows 11 24H2)
# Target: 26200.6718 (Windows 11 25H2)

# Solution: Update to 24H2 first via Windows Update
```

### Error Codes

| Exit Code | PowerShell | Batch | Description | Solution |
|-----------|------------|--------|-------------|----------|
| **0** | ✅ Success | ✅ Success | Installation completed | No action needed |
| **3010** | ✅ Success, reboot required | ✅ Success, reboot required | Installation successful | Reboot system |
| **1** | ❌ General failure | ❌ General failure | Various errors | Check logs |
| **2359302** | ❌ Update not applicable | ❌ Update not applicable | Already installed or incompatible | Verify system version |
| **2359303** | ❌ Installation in progress | ❌ Installation in progress | Another update running | Wait and retry |
| **2147943458** | ❌ Access denied | ❌ Access denied | Insufficient privileges | Run as Administrator |

### Diagnostic Commands

```powershell
# System Information
winver                          # GUI version info
systeminfo | find "OS Version"  # Command line version info
Get-ComputerInfo | Select WindowsVersion, WindowsEditionId

# Registry Check
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR

# Architecture Check  
echo %PROCESSOR_ARCHITECTURE%   # CMD
$env:PROCESSOR_ARCHITECTURE     # PowerShell

# Download Test
ping catalog.sf.dl.delivery.mp.microsoft.com
nslookup catalog.sf.dl.delivery.mp.microsoft.com

# Service Status
sc query BITS                   # BITS service status
sc query wuauserv              # Windows Update service
```

## 🤝 Contributing

We welcome contributions! Here's how to get involved:

### Development Setup
```bash
# Fork and clone the repository
git clone https://github.com/yourusername/Windows-11-25H2-Update-Script.git
cd Windows-11-25H2-Update-Script

# Test both versions
# PowerShell testing
powershell.exe -ExecutionPolicy Bypass -File ".\Upgrade-Win11-To-25H2.ps1" -WhatIf

# Batch testing in test environment
.\Upgrade-Win11-To-25H2.bat
```

### Contribution Guidelines

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/awesome-feature`)
3. **Test** thoroughly on multiple Windows 11 systems
4. **Update documentation** if needed
5. **Commit** changes (`git commit -m 'Add awesome feature'`)
6. **Push** to branch (`git push origin feature/awesome-feature`)
7. **Open** a Pull Request

### Code Standards

- ✅ **PowerShell**: Follow PowerShell best practices and PSScriptAnalyzer rules
- ✅ **Batch**: Use modern CMD syntax, proper error handling
- ✅ **Documentation**: Update README.md for new features
- ✅ **Testing**: Test on both x64 and ARM64 if possible
- ✅ **Compatibility**: Maintain Windows 11 24H2+ compatibility

### Areas for Contribution

- **Proxy Support**: Enhanced network configuration handling
- **Localization**: Multi-language support for error messages
- **GUI Version**: Windows Forms or WPF interface
- **Reporting**: HTML/JSON output formats
- **Integration**: Additional deployment methods (Chocolatey, winget)

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Mikhail Deynekin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

## 👨‍💻 Author & Support

**Mikhail Deynekin**
- 🌐 Website: [deynekin.com](https://deynekin.com)
- 📧 Email: mid1977@gmail.com  
- 🐙 GitHub: [@paulmann](https://github.com/paulmann)

### Getting Help

- 📖 **Documentation**: Read this README thoroughly
- 🐛 **Bug Reports**: [Open an issue](https://github.com/paulmann/Windows-11-25H2-Update-Script/issues/new)
- 💡 **Feature Requests**: [Request features](https://github.com/paulmann/Windows-11-25H2-Update-Script/issues/new)
- 💬 **Questions**: Check [Discussions](https://github.com/paulmann/Windows-11-25H2-Update-Script/discussions)

### Related Projects

- [Microsoft-Activation-Scripts](https://github.com/massgravel/Microsoft-Activation-Scripts) - Windows activation tools
- [Windows11Debloat](https://github.com/Raphire/Win11Debloat) - Remove Windows 11 bloatware
- [PowerShell-Suite](https://github.com/FuzzySecurity/PowerShell-Suite) - PowerShell utilities collection

## 🎯 Roadmap

### Upcoming Features

- [ ] **GUI Version**: User-friendly Windows Forms interface
- [ ] **Package Managers**: Chocolatey and winget support  
- [ ] **Proxy Support**: Enhanced corporate network compatibility
- [ ] **Scheduling**: Built-in task scheduler integration
- [ ] **Rollback**: Automated rollback capabilities
- [ ] **Multi-Language**: Localized error messages and UI

### Version History

- **v1.0.0** (2025-10-01):
  - ✅ Initial PowerShell version with full feature set
  - ✅ Added Batch file alternative for ExecutionPolicy-free deployment  
  - ✅ Comprehensive documentation and examples
  - ✅ Enterprise deployment guides
  - ✅ CI/CD integration examples

### Feature Comparison Roadmap

| Feature | Current Status | PowerShell | Batch | GUI (Planned) |
|---------|---------------|------------|-------|---------------|
| **Architecture Detection** | ✅ Complete | ✅ | ✅ | ✅ |
| **Download with Retry** | ✅ Complete | ✅ | ✅ | ✅ |
| **Digital Signature Check** | ⚠️ PS Only | ✅ | ❌ | ✅ |
| **Comprehensive Logging** | ⚠️ PS Only | ✅ | ⚠️ | ✅ |
| **Parameter Support** | ⚠️ PS Only | ✅ | ❌ | ✅ |
| **Progress Reporting** | 🚧 Basic | ⚠️ | ⚠️ | ✅ |
| **Rollback Support** | ❌ Planned | 🚧 | 🚧 | 🚧 |
| **Proxy Support** | ❌ Planned | 🚧 | 🚧 | 🚧 |

**Legend:** ✅ Complete | ⚠️ Partial | 🚧 In Progress | ❌ Not Available

---

### ⭐ Star this repository if it helped you!

**Windows 11 25H2 Update Script** - *Making Windows updates fast, reliable, and enterprise-ready* 🚀✨

[Report Bug](https://github.com/paulmann/Windows-11-25H2-Update-Script/issues) · [Request Feature](https://github.com/paulmann/Windows-11-25H2-Update-Script/issues) · [Documentation](https://github.com/paulmann/Windows-11-25H2-Update-Script/wiki)
