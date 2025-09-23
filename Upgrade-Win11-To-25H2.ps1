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

# Set UTF-8 encoding for proper symbol display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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

function Write-ErrorPretty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [string]$ErrorCode = $null,
        [string]$Recommendations = $null
    )
    
    # Title in red
    Write-Host "`n[ERROR] " -NoNewline -ForegroundColor Red
    Write-Host $Title -ForegroundColor Red
    
    if ($ErrorCode) {
        Write-Host "   Error Code: " -NoNewline -ForegroundColor DarkGray
        Write-Host $ErrorCode -ForegroundColor Yellow
    }
    
    # Description in cyan
    Write-Host "   Description: " -NoNewline -ForegroundColor DarkGray
    Write-Host $Description -ForegroundColor Cyan
    
    if ($Recommendations) {
        Write-Host "`n   Recommendations:" -ForegroundColor DarkGray
        $recLines = $Recommendations -split "`n"
        foreach ($line in $recLines) {
            if ($line.Trim() -ne "") {
                Write-Host "     - " -NoNewline -ForegroundColor DarkGray
                Write-Host $line.Trim() -ForegroundColor White
            }
        }
    }
    
    Write-Host ""
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

function Get-ExitCodeMessage {
    param([int]$ExitCode)
    
    $errorMessages = @{
        0 = @{
            Title = "Installation completed successfully"
            Type = "Success"
        }
        3010 = @{
            Title = "Installation completed successfully"
            Description = "A reboot is required to finalize the update"
            Type = "Warning"
        }
        2359302 = @{
            Title = "Update not applicable"
            Description = "This update cannot be installed on your system"
            Details = "The update is already installed, your system has a newer version, or prerequisites are missing"
            Recommendations = @(
                "Check Windows Update history to see if this update is already installed",
                "Run 'winver' to verify your current Windows version", 
                "Check if newer updates are available via Windows Update"
            )
            Type = "Error"
        }
        2359303 = @{
            Title = "Installation in progress"
            Description = "Another installation is already in progress"
            Recommendations = @("Wait for current installation to complete and try again")
            Type = "Error"
        }
        2359299 = @{
            Title = "Update not applicable"
            Description = "The update is not applicable to your computer"
            Type = "Error"
        }
        2147943458 = @{
            Title = "Access denied"
            Description = "Administrator privileges required"
            Recommendations = @("Run PowerShell as Administrator")
            Type = "Error"
        }
    }
    
    if ($errorMessages.ContainsKey($ExitCode)) {
        return $errorMessages[$ExitCode]
    }
    else {
        return @{
            Title = "Installation failed"
            Description = "Unknown error occurred during installation"
            Details = "Exit code: $ExitCode"
            Type = "Error"
        }
    }
}

function Install-UpdatePackage {
    param([Parameter(Mandatory = $true)][string]$MsuPath)
    
    Write-Log "Starting update installation..." -Color Cyan -Level Info
    
    $arguments = "`"$MsuPath`" /quiet /norestart"
    $process = Start-Process -FilePath 'wusa.exe' -ArgumentList $arguments -Wait -PassThru
    
    Write-Log "wusa.exe completed with exit code: $($process.ExitCode)" -Color Cyan -Level Info
    
    $exitInfo = Get-ExitCodeMessage -ExitCode $process.ExitCode
    
    switch ($process.ExitCode) {
        0 { 
            Write-Log $exitInfo.Title -Color Green -Level Success 
        }
        3010 { 
            Write-Log $exitInfo.Title -Color Green -Level Success
            Write-Log $exitInfo.Description -Color Yellow -Level Warning 
        }
        2359302 {
            # Special handling for "not applicable" error - check if we're already on target build
            $currentOs = Get-OSBuildInfo
            if (Test-TargetBuild -OSInfo $currentOs) {
                Write-Log "Update not required - system is already on target build or newer" -Color Green -Level Success
                Write-Log "Current version: $($currentOs.CurrentBuild).$($currentOs.UBR) >= Target: $Script:TargetBuild.$Script:TargetUbr" -Color Green -Level Success
                return 0
            }
            else {
                throw "Installation failed with exit code 2359302. The update is not applicable to this system."
            }
        }
        default { 
            if ($exitInfo.Type -eq "Error") {
                throw "Installation failed with exit code $($process.ExitCode). $($exitInfo.Description)"
            }
        }
    }
    
    return $process.ExitCode
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
        Write-ErrorPretty -Title "Administrator privileges required" `
                         -Description "Please run PowerShell as Administrator" `
                         -Recommendations "Right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }
    
    if (-not (Test-ExecutionPolicy)) {
        Write-ErrorPretty -Title "Execution policy blocks script execution" `
                         -Description "Current PowerShell execution policy prevents script execution" `
                         -Recommendations @(
                             "One-time bypass: powershell.exe -ExecutionPolicy Bypass -File $($MyInvocation.MyCommand.Name)",
                             "Set for current user: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned",
                             "Session only: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned"
                         )
        exit 1
    }
    
    # Get system information
    $osInfo = Get-OSBuildInfo
    Write-Log "Current OS: $($osInfo.DisplayVersion) Build $($osInfo.CurrentBuild).$($osInfo.UBR), Architecture: $($osInfo.Architecture)" -Color Cyan -Level Info
    
    # Check if already on target build
    if (Test-TargetBuild -OSInfo $osInfo) {
        Write-Log "[SUCCESS] System is already on Windows 11 25H2 or newer. No update required." -Color Green -Level Success
        Write-Log "   Current version: $($osInfo.CurrentBuild).$($osInfo.UBR) >= Target: $Script:TargetBuild.$Script:TargetUbr" -Color Green -Level Success
        exit 0
    }
    
    # Verify minimum requirements
    if (-not (Test-MinimumBuild -OSInfo $osInfo)) {
        Write-ErrorPretty -Title "Unsupported Windows version" `
                         -Description "This script requires Windows 11 24H2 (Build $Script:MinimumBuild.$Script:MinimumUbr or newer)" `
                         -Recommendations @(
                             "Install the latest updates via Windows Update",
                             "Ensure you are running Windows 11 24H2 or later"
                         )
        exit 1
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
    $exitCode = Install-UpdatePackage -MsuPath $tempFile
    
    # Cleanup temporary file
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    Write-Log "Temporary files cleaned up" -Color Green -Level Success
    
    # Handle reboot (only if installation was successful and not already on target)
    $currentOsAfter = Get-OSBuildInfo
    if (-not (Test-TargetBuild -OSInfo $currentOsAfter) -and $exitCode -eq 3010) {
        Invoke-RebootHandler -RebootBehavior $Reboot
    }
    
    Write-Log "[SUCCESS] Windows 11 25H2 upgrade completed successfully" -Color Green -Level Success
}
catch {
    # Extract exit code from error message if possible
    $errorMessage = $_.Exception.Message
    Write-Log "Error encountered: $errorMessage" -Color Red -Level Error
    
    # Try to extract exit code from error message
    if ($errorMessage -match 'exit code (\d+)') {
        $exitCode = [int]$matches[1]
        $exitInfo = Get-ExitCodeMessage -ExitCode $exitCode
        
        $recommendations = if ($exitInfo.Recommendations) {
            ($exitInfo.Recommendations -join "`n")
        } else { $null }
        
        Write-ErrorPretty -Title $exitInfo.Title `
                         -Description $exitInfo.Description `
                         -ErrorCode "0x$($exitCode.ToString('X8')) ($exitCode)" `
                         -Recommendations $recommendations
    }
    else {
        # Standard error message
        Write-ErrorPretty -Title "Script execution failed" `
                         -Description $errorMessage `
                         -Recommendations "Check the log file for detailed information: $Script:LogFile"
    }
    
    exit 1
}
finally {
    Stop-Transcript | Out-Null
    Write-Log "Log file saved to: $Script:LogFile" -Color Gray -Level Info
}
#endregion
