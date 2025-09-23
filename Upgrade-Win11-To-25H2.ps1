<#
.SYNOPSIS
    Upgrade Windows 11 24H2 → 25H2 (eKB KB5054156) for PowerShell 5.1+ and 7.

.DESCRIPTION
    - Auto-detect x64/ARM64 or prompt user.
    - Validate administrator privileges and execution policy.
    - Check current Windows build and skip if already 25H2.
    - Download via BITS/HTTP with retry logic.
    - Verify MSU signature.
    - Silent install via wusa.exe with reboot options.
    - Transcript logging.
    - Professional, user-friendly messaging and robust error handling.

.PARAMETER Reboot
    Reboot behavior after installation

.PARAMETER RetryCount
    Number of download retry attempts

.PARAMETER RetryDelaySec
    Delay between retry attempts in seconds

.AUTHOR
    Mikhail Deynekin (m@deynekin.com)

.NOTES
    GitHub  : https://github.com/paulmann/Windows-11-25H2-Update-Script
    Requires: PowerShell 5.1+ (Windows 11), Administrator rights.
#>

param(
    [ValidateSet('Prompt', 'Force', 'None')]
    [string]$Reboot = 'Prompt',
    
    [ValidateRange(1, 10)]
    [int]$RetryCount = 3,
    
    [ValidateRange(1, 60)]
    [int]$RetryDelaySec = 5
)

#region Constants
$Script:TargetBuild = 26200
$Script:TargetUbr = 6718
$Script:MinimumBuild = 26100
$Script:MinimumUbr = 5074

$Script:EnablementUrl = @{
    'AMD64' = 'https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/fa84cc49-18b2-4c26-b389-90c96e6ae0d2/public/windows11.0-kb5054156-x64_a0c1638cbcf4cf33dbe9a5bef69db374b4786974.msu'
    'ARM64' = 'https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/78b265e5-83a8-4e0a-9060-efbe0bac5bde/public/windows11.0-kb5054156-arm64_3d5c91aaeb08a87e0717f263ad4a61186746e465.msu'
}

$Script:LogDir = Join-Path $env:ProgramData 'Win11-25H2'
$Script:LogFile = Join-Path $Script:LogDir ("Upgrade_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
#endregion

#region Functions
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ConsoleColor]$Color = 'White',
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    Write-Host $formattedMessage -ForegroundColor $Color
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ExecutionPolicy {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    return $policy -notin @('Restricted', 'Undefined')
}

function Get-OSArchitecture {
    try {
        $osArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
        if ($osArch -like "*64-bit*") {
            return "AMD64"
        }
        elseif ($osArch -like "*ARM*") {
            return "ARM64"
        }
        else {
            return $env:PROCESSOR_ARCHITECTURE
        }
    }
    catch {
        # Fallback to environment variable if WMI fails
        return $env:PROCESSOR_ARCHITECTURE
    }
}

function Get-OSBuildInfo {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $regProperties = Get-ItemProperty -Path $regPath
    
    return [PSCustomObject]@{
        ProductName    = $regProperties.ProductName
        DisplayVersion = $regProperties.DisplayVersion
        CurrentBuild   = [int]$regProperties.CurrentBuild
        UBR            = [int]$regProperties.UBR
        Architecture   = Get-OSArchitecture
    }
}

function Test-TargetBuild {
    param($OSInfo)
    
    if ($OSInfo.CurrentBuild -gt $Script:TargetBuild) {
        return $true
    }
    
    if ($OSInfo.CurrentBuild -eq $Script:TargetBuild -and $OSInfo.UBR -ge $Script:TargetUbr) {
        return $true
    }
    
    return $false
}

function Test-MinimumBuild {
    param($OSInfo)
    
    if ($OSInfo.CurrentBuild -lt $Script:MinimumBuild) {
        return $false
    }
    
    if ($OSInfo.CurrentBuild -eq $Script:MinimumBuild -and $OSInfo.UBR -lt $Script:MinimumUbr) {
        return $false
    }
    
    return $true
}

function Get-ArchitectureChoice {
    do {
        $choice = Read-Host "Specify architecture (AMD64/ARM64) [Default: AMD64]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            return 'AMD64'
        }
        
        $normalizedChoice = $choice.Trim().ToUpper()
        if ($normalizedChoice -in @('AMD64', 'X64')) {
            return 'AMD64'
        }
        elseif ($normalizedChoice -eq 'ARM64') {
            return 'ARM64'
        }
        
        Write-Log "Invalid architecture: $choice. Please enter AMD64 or ARM64." -Color Yellow -Level Warning
    } while ($true)
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )
    
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Write-Log "Download attempt $attempt of $RetryCount..." -Color Cyan -Level Info
            
            if (Get-Service -Name BITS -ErrorAction SilentlyContinue) {
                Start-BitsTransfer -Source $Uri -Destination $OutFile -ErrorAction Stop
            }
            else {
                $progressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            }
            
            Write-Log "Download completed successfully" -Color Green -Level Success
            return
        }
        catch {
            Write-Log "Download attempt $attempt failed: $($_.Exception.Message)" -Color Yellow -Level Warning
            
            if ($attempt -lt $RetryCount) {
                Write-Log "Retrying in $RetryDelaySec seconds..." -Color Cyan -Level Info
                Start-Sleep -Seconds $RetryDelaySec
            }
            else {
                throw "Failed to download after $RetryCount attempts: $($_.Exception.Message)"
            }
        }
    }
}

function Test-FileSignature {
    param([Parameter(Mandatory = $true)][string]$FilePath)
    
    Write-Log "Verifying digital signature..." -Color Cyan -Level Info
    
    $signature = Get-AuthenticodeSignature -FilePath $FilePath
    
    if ($signature.Status -ne 'Valid') {
        throw "Invalid signature status: $($signature.Status)"
    }
    
    if ($signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw "Untrusted signer: $($signature.SignerCertificate.Subject)"
    }
    
    Write-Log "Signature validation successful" -Color Green -Level Success
}

function Install-UpdatePackage {
    param([Parameter(Mandatory = $true)][string]$MsuPath)
    
    Write-Log "Starting update installation..." -Color Cyan -Level Info
    
    $arguments = "`"$MsuPath`" /quiet /norestart"
    $process = Start-Process -FilePath 'wusa.exe' -ArgumentList $arguments -Wait -PassThru
    
    switch ($process.ExitCode) {
        0 { 
            Write-Log "Update installed successfully" -Color Green -Level Success 
        }
        3010 { 
            Write-Log "Update installed successfully. Reboot required." -Color Yellow -Level Warning 
        }
        default { 
            throw "Installation failed with exit code $($process.ExitCode). See Microsoft documentation for error details." 
        }
    }
}

function Invoke-RebootHandler {
    param([string]$RebootBehavior)
    
    switch ($RebootBehavior.ToLower()) {
        'force' {
            Write-Log "Forcing system reboot..." -Color Yellow -Level Warning
            Restart-Computer -Force
        }
        'prompt' {
            $response = Read-Host "Reboot required to complete installation. Reboot now? (Y/N)"
            if ($response -eq 'Y' -or $response -eq 'y') {
                Write-Log "Initiating system reboot..." -Color Cyan -Level Info
                Restart-Computer -Force
            }
            else {
                Write-Log "Reboot deferred. Please reboot manually to complete the installation." -Color Yellow -Level Warning
            }
        }
        'none' {
            Write-Log "Reboot suppressed. Please reboot manually to complete the installation." -Color Yellow -Level Warning
        }
    }
}
#endregion

#region Main Execution
try {
    # Initialize logging
    New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
    Start-Transcript -Path $Script:LogFile -Force | Out-Null
    
    Write-Log "Windows 11 25H2 Upgrade Script started" -Color Cyan -Level Info
    Write-Log "Log file: $Script:LogFile" -Color Gray -Level Info
    
    # Validate prerequisites
    if (-not (Test-Administrator)) {
        throw "Administrator privileges are required. Please run PowerShell as Administrator."
    }
    
    if (-not (Test-ExecutionPolicy)) {
        throw @"
Current execution policy blocks script execution.
Options to resolve:
1. One-time bypass: 
   powershell.exe -ExecutionPolicy Bypass -File $($MyInvocation.MyCommand.Name)
2. Set for current user:
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
3. Session only:
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
"@
    }
    
    # Get system information
    $osInfo = Get-OSBuildInfo
    Write-Log "Current OS: $($osInfo.DisplayVersion) Build $($osInfo.CurrentBuild).$($osInfo.UBR), Architecture: $($osInfo.Architecture)" -Color Cyan -Level Info
    
    # Check if already on target build
    if (Test-TargetBuild -OSInfo $osInfo) {
        Write-Log "System is already on Windows 11 25H2 or newer. No update required." -Color Green -Level Success
        exit 0
    }
    
    # Verify minimum requirements
    if (-not (Test-MinimumBuild -OSInfo $osInfo)) {
        throw @"
Unsupported Windows version: $($osInfo.DisplayVersion) Build $($osInfo.CurrentBuild).$($osInfo.UBR)
This script requires Windows 11 24H2 (Build $Script:MinimumBuild.$Script:MinimumUbr or newer).
Please install the latest updates before running this script.
"@
    }
    
    # Determine architecture
    $architecture = if ($Script:EnablementUrl.ContainsKey($osInfo.Architecture)) {
        $osInfo.Architecture
    }
    else {
        Get-ArchitectureChoice
    }
    
    Write-Log "Selected architecture: $architecture" -Color Cyan -Level Info
    
    # Download update package
    $downloadUrl = $Script:EnablementUrl[$architecture]
    $tempFile = Join-Path $env:TEMP "kb5054156_$architecture.msu"
    
    if (Test-Path $tempFile) {
        Write-Log "Removing existing temporary file..." -Color Yellow -Level Warning
        Remove-Item $tempFile -Force
    }
    
    Write-Log "Downloading update package..." -Color Cyan -Level Info
    Write-Log "Source: $downloadUrl" -Color Gray -Level Info
    Write-Log "Destination: $tempFile" -Color Gray -Level Info
    
    Invoke-FileDownload -Uri $downloadUrl -OutFile $tempFile
    
    # Verify and install
    Test-FileSignature -FilePath $tempFile
    Install-UpdatePackage -MsuPath $tempFile
    
    # Cleanup temporary file
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    Write-Log "Temporary files cleaned up" -Color Green -Level Success
    
    # Handle reboot
    Invoke-RebootHandler -RebootBehavior $Reboot
    
    Write-Log "Windows 11 25H2 upgrade completed successfully" -Color Green -Level Success
}
catch {
    Write-Log "Error: $($_.Exception.Message)" -Color Red -Level Error
    Write-Log "Script execution failed" -Color Red -Level Error
    exit 1
}
finally {
    Stop-Transcript | Out-Null
    Write-Log "Log file saved to: $Script:LogFile" -Color Gray -Level Info
}
#endregion
