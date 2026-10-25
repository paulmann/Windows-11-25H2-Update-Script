<#
.SYNOPSIS
    Upgrade Windows 11 to version 26H2 (enablement package KB5121794) for PowerShell 5.1+ and 7.
.DESCRIPTION
    Turns Windows 11, version 26H2 on with the official enablement package KB5121794. Both Windows 11
    24H2 and 25H2 are supported: they share the 26H2 core files, so the package only flips the
    features on and needs a single restart.

    - Auto-detects AMD64/ARM64. ARM is tested first, so "ARM 64-bit Processor" is not mistaken for x64.
    - Validates administrator rights, then refuses editions outside Microsoft's "Applies To" list
      (LTSC 2024 and server SKUs share the same build numbers but are not supported).
    - Refuses hosts below the documented prerequisite (KB5124010): 26100.9546+ on 24H2,
      26200.9550+ on 25H2, and hosts on the separate 26H1 servicing branch (build 28000).
    - Does nothing when the host already runs 26H2 (any build 26300.x) or a newer build.
    - Downloads the package from Microsoft's delivery CDN with BITS and falls back to HTTP on every
      attempt, not only when the BITS service is missing.
    - Verifies the SHA-1 fingerprint published in the package file name and the Authenticode signature.
    - Installs with wusa.exe /quiet /norestart, then applies the reboot policy.
    - With -WhatIf nothing is written to disk at all: no log directory, no transcript, no download.
    - Keeps a transcript in %ProgramData%\Win11-26H2 (skipped with -WhatIf, or if transcription is
      not possible; the run then continues with console output only).
    - Exit code 0 means "the package was accepted and staged, a restart is still pending". It does
      not prove that the build changed: verify CurrentBuild = 26300 after the restart.
.PARAMETER Reboot
    Reboot behaviour after a successful installation: Prompt (default), Force or None. The
    enablement package always needs one restart, so Prompt and Force matter even when wusa.exe
    returns 0.
.PARAMETER RetryCount
    Number of download attempts, 1-10. Defaults to 3.
.PARAMETER RetryDelaySec
    Delay between download attempts in seconds, 1-60. Defaults to 5.
.PARAMETER Architecture
    Auto (default) detects the architecture. AMD64 or ARM64 force a package and are intended for
    imaging, for hosts that report an unusual architecture string, or for unattended -WhatIf runs on
    such hosts (otherwise the preflight refuses instead of prompting).
.PARAMETER PackagePath
    Install a locally available MSU instead of downloading one, for air-gapped hosts. The file name
    must contain KB5121794 and, when it names an architecture, that architecture must match; the
    Authenticode signature is always checked. The SHA-1 check is skipped because the fingerprint
    belongs to the catalog copy.
.EXAMPLE
    .\Upgrade-Win11-To-26H2.ps1 -WhatIf
    Read-only preflight: prints the detected build, the package that would be used and the target.
.EXAMPLE
    .\Upgrade-Win11-To-26H2.ps1 -Reboot None
    Installs the package and leaves the restart for a maintenance window.
.EXAMPLE
    .\Upgrade-Win11-To-26H2.ps1 -Architecture ARM64 -RetryCount 5 -RetryDelaySec 15
    Forces the ARM64 package and a slower retry cadence.
.NOTES
    Enablement package : KB5121794 (Windows 11, version 26H2)
    KB article         : https://support.microsoft.com/help/5121794
    Prerequisite       : KB5124010 (2026-09-22) or a later cumulative update: build 26100.9546+ on
                         24H2, 26200.9550+ on 25H2
    Repository         : https://github.com/paulmann/Windows-11-25H2-Update-Script
    Author             : Mikhail Deynekin (m@deynekin.com)
    Requires           : Windows 11 24H2/25H2, administrator rights, PowerShell 5.1+ or 7.
#>

# The console is the user interface here; coloured progress output is deliberate.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool: coloured progress output is the user interface.')]
# Microsoft publishes a SHA-1 fingerprint in the package file name. It is a transport check; the
# Authenticode signature below is the actual security boundary.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingBrokenHashAlgorithms', '', Justification = 'SHA-1 is the fingerprint Microsoft publishes in the MSU file name; authenticity is proven separately by Authenticode.')]
# Write-Log is not a built-in cmdlet on stock Windows PowerShell 5.1 or PowerShell 7; the rule
# matches a community module of the same name. The name is kept for consistency with the 25H2 script.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Write-Log is not a built-in cmdlet on Windows PowerShell 5.1 or PowerShell 7; the name is kept for consistency with the 25H2 script.')]
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Prompt', 'Force', 'None')]
    [string]$Reboot = 'Prompt',

    [ValidateRange(1, 10)]
    [int]$RetryCount = 3,

    [ValidateRange(1, 60)]
    [int]$RetryDelaySec = 5,

    [ValidateSet('Auto', 'AMD64', 'ARM64')]
    [string]$Architecture = 'Auto',

    [string]$PackagePath
)

# Ensure UTF-8 output to avoid garbage characters in the console.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 'utf8NoBOM' exists only in PowerShell 6+; on 5.1 the default must stay untouched, because an
# invalid default value would make any later Out-File call fail.
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
}

#region Constants
$Script:TargetVersion = '26H2'
# Any build 26300.x is 26H2; 26300.9457 was the first GA build, shown only for recognition.
$Script:TargetBuild = 26300
$Script:FirstGaBuild = '26300.9457'

$Script:MinimumBuild = 26100
# KB5124010 or later is required. The prerequisite build differs per servicing ladder: the KB article
# states 26100.9546 for 24H2, and the release table lists 26200.9550 for 25H2.
$Script:MinimumUbr = @{
    26100 = 9546
    26200 = 9550
}
$Script:DefaultMinimumUbr = 9546
$Script:PrerequisiteKb = 'KB5124010'

# 26H1 (build 28000) is a separate servicing branch for new devices, not an in-place path to 26H2.
$Script:OtherBranchBuild = 28000
$Script:OtherBranchVersion = '26H1'

# KB5121794's "Applies To" list covers Home, Pro, Enterprise, Education, Enterprise multi-session and
# IoT Enterprise on 24H2/25H2. It excludes the LTSC editions and Windows Server, which share build
# 26100/26200 and would otherwise pass every build gate.
$Script:UnsupportedEditionIds = @('EnterpriseS', 'IoTEnterpriseS', 'EnterpriseSN', 'IoTEnterpriseSN')

$Script:EnablementKb = 'KB5121794'
$Script:EnablementUrl = @{
    'AMD64' = 'https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/94520a88-858f-4832-a57d-7211f6d84a4e/public/Windows11.0-KB5121794-x64_5e20a3cce48d6611b16bdec42b07167f5456586a.msu'
    'ARM64' = 'https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/9d8dc3d0-9cbf-4eb1-9411-722e3e6a19b3/public/Windows11.0-KB5121794-arm64_77a76caf2d362bb293a4d18058388f2717365abe.msu'
}

# SHA-1 published by Microsoft in the package file name; verified after the download.
$Script:EnablementSha1 = @{
    'AMD64' = '5e20a3cce48d6611b16bdec42b07167f5456586a'
    'ARM64' = '77a76caf2d362bb293a4d18058388f2717365abe'
}

# A real package is about 174 KB; anything this small is an error page or a cut download.
$Script:MinimumPackageBytes = 100000

$Script:LogDir = Join-Path $env:ProgramData 'Win11-26H2'
$Script:LogFile = Join-Path $Script:LogDir ('Upgrade_{0:yyyyMMdd_HHmmss}.log' -f (Get-Date))
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
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $Color
}

function Write-ErrorPretty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [string]$ErrorCode = $null,
        [string[]]$Recommendations = @()
    )
    Write-Host "`n[x] " -NoNewline -ForegroundColor Red
    Write-Host $Title -ForegroundColor Red
    if ($ErrorCode) {
        Write-Host "   Error Code: " -NoNewline -ForegroundColor DarkGray
        Write-Host $ErrorCode -ForegroundColor Yellow
    }
    Write-Host "   Description: " -NoNewline -ForegroundColor DarkGray
    Write-Host $Description -ForegroundColor Cyan
    if ($Recommendations.Count -gt 0) {
        Write-Host "`n   Recommendations:" -ForegroundColor DarkGray
        foreach ($line in $Recommendations) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
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

function Resolve-Architecture {
    param([string[]]$Candidates)
    # ARM is tested first on purpose: an ARM64 host can report "ARM 64-bit Processor", which also
    # matches "64-bit". Reversing the order misclassifies such hosts as x64.
    if (-not $Candidates) { return $null }
    foreach ($candidate in $Candidates) {
        if ($candidate -match 'ARM') { return 'ARM64' }
    }
    foreach ($candidate in $Candidates) {
        if ($candidate -match 'AMD64|X64|64-bit') { return 'AMD64' }
    }
    return $null
}

function Get-OSArchitecture {
    $candidates = @()
    if ($env:PROCESSOR_ARCHITEW6432) { $candidates += $env:PROCESSOR_ARCHITEW6432 }
    if ($env:PROCESSOR_ARCHITECTURE) { $candidates += $env:PROCESSOR_ARCHITECTURE }

    # CIM is optional: with module autoloading disabled or in constrained language it can be absent,
    # and that must not abort the run. The environment variables above are enough on their own.
    try {
        $cim = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($cim -and $cim.OSArchitecture) { $candidates += $cim.OSArchitecture }
    }
    catch {
        $cim = $null
    }

    $resolved = Resolve-Architecture -Candidates $candidates
    if ($resolved) { return $resolved }
    return $env:PROCESSOR_ARCHITECTURE
}

function Get-OSBuildInfo {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $regProperties = Get-ItemProperty -Path $regPath -ErrorAction Stop
    $ubr = 0
    if ($null -ne $regProperties.UBR) {
        $ubr = [int]$regProperties.UBR
    }
    return [PSCustomObject]@{
        ProductName      = $regProperties.ProductName
        DisplayVersion   = $regProperties.DisplayVersion
        EditionID        = $regProperties.EditionID
        InstallationType = $regProperties.InstallationType
        CurrentBuild     = [int]$regProperties.CurrentBuild
        UBR              = $ubr
        Architecture     = Get-OSArchitecture
    }
}

function Test-SupportedEdition {
    param($OSInfo)
    if ($OSInfo.InstallationType -eq 'Server') {
        return [PSCustomObject]@{
            Supported = $false
            Reason    = 'Windows Server is not in KB5121794''s "Applies To" list'
        }
    }
    foreach ($edition in $Script:UnsupportedEditionIds) {
        if ($OSInfo.EditionID -eq $edition) {
            return [PSCustomObject]@{
                Supported = $false
                Reason    = "Edition $edition is an LTSC edition, which KB5121794 does not support"
            }
        }
    }
    if ($OSInfo.ProductName -match 'LTSC') {
        return [PSCustomObject]@{
            Supported = $false
            Reason    = 'The product name reports an LTSC edition, which KB5121794 does not support'
        }
    }
    return [PSCustomObject]@{
        Supported = $true
        Reason    = $null
    }
}

function Test-TargetBuild {
    param($OSInfo)
    # Any 26H2 build counts, whatever its UBR: 26300 itself is the version marker.
    return ($OSInfo.CurrentBuild -ge $Script:TargetBuild)
}

function Get-MinimumUbr {
    param([int]$Build)
    if ($Script:MinimumUbr.ContainsKey($Build)) {
        return $Script:MinimumUbr[$Build]
    }
    return $Script:DefaultMinimumUbr
}

function Test-MinimumBuild {
    param($OSInfo)
    if ($OSInfo.CurrentBuild -lt $Script:MinimumBuild) {
        return $false
    }
    return ($OSInfo.UBR -ge (Get-MinimumUbr -Build $OSInfo.CurrentBuild))
}

function Test-OtherBranch {
    param($OSInfo)
    # 26H1 (build 28000) is newer by number but is not an upgrade path to 26H2.
    return ($OSInfo.CurrentBuild -ge $Script:OtherBranchBuild)
}

function Get-ArchitectureChoiceValue {
    param([string]$Choice)
    if ([string]::IsNullOrWhiteSpace($Choice)) { return 'AMD64' }
    $normalized = $Choice.Trim().ToUpperInvariant()
    if ($normalized -in @('AMD64', 'X64')) { return 'AMD64' }
    if ($normalized -eq 'ARM64') { return 'ARM64' }
    return $null
}

function Get-ArchitectureChoice {
    do {
        $choice = Read-Host 'Specify architecture (AMD64/ARM64) [Default: AMD64]'
        $resolved = Get-ArchitectureChoiceValue -Choice $choice
        if ($resolved) { return $resolved }
        Write-Log "Invalid architecture: $choice. Please enter AMD64 or ARM64." -Color Yellow -Level Warning
    } while ($true)
}

function Test-PackageIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string]$Architecture
    )
    if ($FileName -notmatch 'KB5121794') {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = "the file name does not contain KB5121794, so it is not the 26H2 enablement package"
        }
    }
    if ($FileName -match '(?i)arm64' -and $Architecture -ne 'ARM64') {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = 'the file name names an ARM64 package but the host needs AMD64'
        }
    }
    if ($FileName -match '(?i)(x64|amd64)' -and $Architecture -ne 'AMD64') {
        return [PSCustomObject]@{
            Valid  = $false
            Reason = 'the file name names an x64 package but the host needs ARM64'
        }
    }
    return [PSCustomObject]@{
        Valid  = $true
        Reason = $null
    }
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$OutFile,
        [Parameter(Mandatory = $true)]
        [int]$Attempts,
        [Parameter(Mandatory = $true)]
        [int]$DelaySec
    )
    $bitsAvailable = [bool](Get-Service -Name BITS -ErrorAction SilentlyContinue)
    $bitsDisplayName = "Win11-26H2-$($Script:EnablementKb)"

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $methods = @()
        if ($bitsAvailable) { $methods += 'BITS' }
        $methods += 'HTTP'

        foreach ($method in $methods) {
            try {
                Write-Log "Download attempt $attempt of $Attempts via $method..." -Color Cyan -Level Info
                if ($method -eq 'BITS') {
                    Start-BitsTransfer -Source $Uri -Destination $OutFile -DisplayName $bitsDisplayName -ErrorAction Stop
                }
                else {
                    $savedProgress = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'
                    try {
                        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
                    }
                    finally {
                        $ProgressPreference = $savedProgress
                    }
                }

                if (-not (Test-Path -LiteralPath $OutFile)) {
                    throw 'Downloaded file is missing'
                }
                $size = (Get-Item -LiteralPath $OutFile).Length
                if ($size -lt $Script:MinimumPackageBytes) {
                    throw "Downloaded file is only $size bytes, below the $($Script:MinimumPackageBytes)-byte sanity limit"
                }
                Write-Log "Download completed successfully ($size bytes)" -Color Green -Level Success
                return
            }
            catch {
                Write-Log "$method attempt $attempt failed: $($_.Exception.Message)" -Color Yellow -Level Warning
                # A failed BITS transfer can leave a job holding the target file; drop it before the
                # HTTP fallback tries the same path.
                if ($method -eq 'BITS') {
                    Get-BitsTransfer -Name $bitsDisplayName -ErrorAction SilentlyContinue |
                        Remove-BitsTransfer -ErrorAction SilentlyContinue
                }
                Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            }
        }

        if ($attempt -lt $Attempts) {
            Write-Log "Retrying in $DelaySec seconds..." -Color Cyan -Level Info
            Start-Sleep -Seconds $DelaySec
        }
    }

    throw "Failed to download the enablement package after $Attempts attempts: $Uri"
}

function Test-PackageSize {
    param([Parameter(Mandatory = $true)][string]$FilePath)
    $size = (Get-Item -LiteralPath $FilePath).Length
    if ($size -lt $Script:MinimumPackageBytes) {
        throw "Package file is only $size bytes, which is too small to be a valid MSU"
    }
    return $size
}

function Test-PackageHash {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha1
    )
    Write-Log 'Verifying SHA-1 fingerprint from the package file name...' -Color Cyan -Level Info
    $actual = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha1.ToLowerInvariant()) {
        throw "SHA-1 mismatch: expected $ExpectedSha1, got $actual"
    }
    Write-Log 'SHA-1 verification successful' -Color Green -Level Success
}

function Test-FileSignature {
    param([Parameter(Mandatory = $true)][string]$FilePath)
    Write-Log 'Verifying digital signature...' -Color Cyan -Level Info
    $signature = Get-AuthenticodeSignature -FilePath $FilePath
    if ($signature.Status -ne 'Valid') {
        throw "Invalid signature status: $($signature.Status)"
    }
    if ($signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw "Untrusted signer: $($signature.SignerCertificate.Subject)"
    }
    Write-Log 'Signature validation successful' -Color Green -Level Success
}

function Get-ExitCodeMessage {
    param([long]$ExitCode)
    # wusa.exe returns Win32 errors as signed 32-bit values, so 0x800F0823 arrives as -2146498525.
    # Normalise to the unsigned form before the lookup, and accept already-unsigned callers too.
    $code = [long]$ExitCode
    if ($code -lt 0) { $code = $code + 4294967296 }
    $errorMessages = @{
        0 = @{
            Title       = 'Installation completed successfully'
            Description = 'The enablement package was installed; restart the device to activate Windows 11 26H2'
            Type        = 'Success'
        }
        3010 = @{
            Title           = 'Installation completed successfully'
            Description     = 'A restart is required to finalise the update'
            Recommendations = @('Restart the device to activate Windows 11 26H2')
            Type            = 'Warning'
        }
        2359302 = @{
            Title       = 'Update not applicable'
            Description = 'This update cannot be installed on this system'
            Details     = 'The update is already installed, the system is newer, or prerequisites are missing'
            Recommendations = @(
                'Check Windows Update history for KB5121794',
                'Run winver to confirm the current version',
                'Make sure KB5124010 or a later cumulative update is installed'
            )
            Type        = 'Error'
        }
        2359303 = @{
            Title           = 'Installation in progress'
            Description     = 'Another installation is already in progress'
            Recommendations = @('Wait for the running installation to finish and run the script again')
            Type            = 'Error'
        }
        2359299 = @{
            Title       = 'Update not applicable'
            Description = 'The update is not applicable to this computer'
            Type        = 'Error'
        }
        2147942405 = @{
            Title           = 'Access denied (0x80070005)'
            Description     = 'Administrator privileges are required'
            Recommendations = @('Run PowerShell as Administrator')
            Type            = 'Error'
        }
        2148468771 = @{
            Title       = 'Prerequisites not satisfied (0x800F0823)'
            Description = 'The enablement package requires a newer cumulative update or servicing stack'
            Details     = 'The script checks the documented prerequisite build, but the servicing stack can still be older'
            Recommendations = @(
                'Install all pending updates via Windows Update',
                'Install KB5124010 or a later cumulative update, restart, then run the script again'
            )
            Type        = 'Error'
        }
    }
    # Hashtable literal keys are Int32 for small values; normalise the lookup so that 0 and 3010
    # match an Int64 argument too.
    $normalized = @{}
    foreach ($key in $errorMessages.Keys) {
        $normalized[[long]$key] = $errorMessages[$key]
    }
    if ($normalized.ContainsKey($code)) {
        return $normalized[$code]
    }
    return @{
        Title       = 'Installation failed'
        Description = 'Unknown error occurred during installation'
        Details     = ('Exit code: {0} (0x{0:X8})' -f $code)
        Type        = 'Error'
    }
}

function Install-UpdatePackage {
    param([Parameter(Mandatory = $true)][string]$MsuPath)
    $wusaPath = Join-Path $env:SystemRoot 'System32\wusa.exe'
    if (-not (Test-Path -LiteralPath $wusaPath)) {
        throw "wusa.exe not found at $wusaPath"
    }
    Write-Log 'Starting update installation...' -Color Cyan -Level Info
    $arguments = "`"$MsuPath`" /quiet /norestart"
    $process = Start-Process -FilePath $wusaPath -ArgumentList $arguments -Wait -PassThru
    return [int]$process.ExitCode
}

function Invoke-RebootHandler {
    param([string]$RebootBehavior)
    switch ($RebootBehavior.ToLower()) {
        'force' {
            Write-Log 'Forcing system reboot...' -Color Yellow -Level Warning
            Restart-Computer -Force
        }
        'prompt' {
            $response = Read-Host 'Reboot required to complete installation. Reboot now? (Y/N)'
            if ($response -eq 'Y' -or $response -eq 'y') {
                Write-Log 'Initiating system reboot...' -Color Cyan -Level Info
                Restart-Computer -Force
            }
            else {
                Write-Log 'Reboot deferred. Please reboot manually to complete the installation.' -Color Yellow -Level Warning
            }
        }
        'none' {
            Write-Log 'Reboot suppressed. Please reboot manually to complete the installation.' -Color Yellow -Level Warning
        }
    }
}
#endregion

#region Main Execution
# Everything below runs only when this file is executed, never when it is dot-sourced, so tests can
# load the functions above without touching the operating system.
if ($MyInvocation.InvocationName -ne '.') {
    $downloadedPackage = $false
    $tempFile = $null
    $transcriptStarted = $false
    $preflightOnly = $WhatIfPreference

    try {
        # The privilege gate runs before any file is written, so a refused run leaves nothing behind.
        if (-not (Test-Administrator)) {
            Write-ErrorPretty -Title 'Administrator privileges required' `
                -Description 'Please run PowerShell as Administrator' `
                -Recommendations 'Right-click PowerShell and select "Run as Administrator"'
            exit 1
        }

        # A preflight writes nothing at all: no log directory, no transcript.
        if (-not $preflightOnly) {
            New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
            try {
                Start-Transcript -Path $Script:LogFile -Force | Out-Null
                $transcriptStarted = $true
            }
            catch {
                Write-Host "Warning: transcript could not be started ($($_.Exception.Message)). Continuing with console output only." -ForegroundColor Yellow
            }
        }

        Write-Log "Windows 11 $($Script:TargetVersion) Upgrade Script started" -Color Cyan -Level Info
        if ($transcriptStarted) {
            Write-Log "Log file: $($Script:LogFile)" -Color Gray -Level Info
        }
        if ($preflightOnly) {
            Write-Log 'Preflight mode: this run will not write files, download or install anything.' -Color Yellow -Level Warning
        }

        $osInfo = Get-OSBuildInfo
        Write-Log "Current OS: $($osInfo.DisplayVersion) Build $($osInfo.CurrentBuild).$($osInfo.UBR), Edition: $($osInfo.EditionID), Architecture: $($osInfo.Architecture)" -Color Cyan -Level Info
        Write-Log "Execution policy: $(Get-ExecutionPolicy) (informational: the script already runs, so the policy allowed it)" -Color Gray -Level Info

        if (Test-OtherBranch -OSInfo $osInfo) {
            Write-ErrorPretty -Title "Windows 11 $($Script:OtherBranchVersion) is not an upgrade path to $($Script:TargetVersion)" `
                -Description "This host runs build $($osInfo.CurrentBuild) ($($osInfo.DisplayVersion)); $($Script:OtherBranchVersion) is a separate branch for new devices" `
                -Recommendations @(
                    "The $($Script:EnablementKb) enablement package applies to 24H2 and 25H2 hosts only",
                    'No action is required: this host is already on a newer, separately serviced branch'
                )
            exit 1
        }

        if (Test-TargetBuild -OSInfo $osInfo) {
            Write-Log "[v] System is already on Windows 11 $($Script:TargetVersion) or newer (build $($osInfo.CurrentBuild).$($osInfo.UBR)). No update required." -Color Green -Level Success
            exit 0
        }

        $edition = Test-SupportedEdition -OSInfo $osInfo
        if (-not $edition.Supported) {
            Write-ErrorPretty -Title 'Unsupported Windows edition' `
                -Description $edition.Reason `
                -Recommendations @(
                    "KB5121794 applies to Home, Pro, Enterprise, Education, Enterprise multi-session and IoT Enterprise on 24H2/25H2",
                    'Do not force the package on an LTSC or server host; use the servicing channel for that SKU'
                )
            exit 1
        }

        if (-not (Test-MinimumBuild -OSInfo $osInfo)) {
            $floor = Get-MinimumUbr -Build $osInfo.CurrentBuild
            Write-ErrorPretty -Title 'Unsupported Windows version' `
                -Description "This script requires Windows 11 24H2 or 25H2 at build $($Script:MinimumBuild).$floor or newer (KB5124010)" `
                -Recommendations @(
                    'Install all pending updates via Windows Update',
                    "Install $($Script:PrerequisiteKb) or a later cumulative update, restart, then run the script again",
                    'Verify the build with: Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"'
                )
            exit 1
        }

        # Resolve the package to install.
        $architecture = $Architecture
        if ($architecture -eq 'Auto') {
            $detected = Get-OSArchitecture
            if ($Script:EnablementUrl.ContainsKey($detected)) {
                $architecture = $detected
            }
            elseif ($preflightOnly) {
                Write-ErrorPretty -Title 'Architecture could not be determined' `
                    -Description "The host reports '$detected', which is neither AMD64 nor ARM64" `
                    -Recommendations 'Pass -Architecture AMD64 or -Architecture ARM64 to see the preflight plan'
                exit 1
            }
            else {
                Write-Log "Architecture could not be detected reliably (reported: $detected)" -Color Yellow -Level Warning
                $architecture = Get-ArchitectureChoice
            }
        }
        Write-Log "Selected architecture: $architecture" -Color Cyan -Level Info

        if ($PackagePath) {
            if (-not (Test-Path -LiteralPath $PackagePath)) {
                Write-ErrorPretty -Title 'Local package not found' `
                    -Description "The file does not exist: $PackagePath" `
                    -Recommendations 'Point -PackagePath at a Windows11.0-KB5121794-*.msu file'
                exit 1
            }
            $localName = Split-Path -Path $PackagePath -Leaf
            $identity = Test-PackageIdentity -FileName $localName -Architecture $architecture
            if (-not $identity.Valid) {
                Write-ErrorPretty -Title 'Local package is not the 26H2 enablement package' `
                    -Description "$localName : $($identity.Reason)" `
                    -Recommendations @(
                        'Use the file downloaded from the URL pinned in this script, or the one from Windows Update',
                        'A cumulative-update MSU is Microsoft-signed too, but it is not KB5121794 and must not be installed here'
                    )
                exit 1
            }
            $tempFile = (Resolve-Path -LiteralPath $PackagePath).Path
            $downloadUrl = '(local package)'
        }
        else {
            $downloadUrl = $Script:EnablementUrl[$architecture]
            $tempFile = Join-Path $env:TEMP ("kb5121794_$architecture.msu")
        }

        $targetDescription = "Windows 11 $($Script:TargetVersion) (build $($Script:TargetBuild).x) via $($Script:EnablementKb) on $architecture"
        Write-Log "Target: $targetDescription" -Color Cyan -Level Info
        Write-Log "Source: $downloadUrl" -Color Gray -Level Info

        if (-not $PSCmdlet.ShouldProcess($targetDescription, 'Download and install the enablement package')) {
            Write-Log 'Preflight only (-WhatIf): nothing was downloaded or installed.' -Color Yellow -Level Warning
            exit 0
        }

        if (-not $PackagePath) {
            if (Test-Path -LiteralPath $tempFile) {
                Write-Log 'Removing existing temporary file...' -Color Yellow -Level Warning
                Remove-Item -LiteralPath $tempFile -Force
            }
            Write-Log 'Downloading update package...' -Color Cyan -Level Info
            Invoke-FileDownload -Uri $downloadUrl -OutFile $tempFile -Attempts $RetryCount -DelaySec $RetryDelaySec
            $downloadedPackage = $true
            Test-PackageSize -FilePath $tempFile | Out-Null
            Test-PackageHash -FilePath $tempFile -ExpectedSha1 $Script:EnablementSha1[$architecture]
        }
        else {
            Write-Log "Using local package: $tempFile" -Color Cyan -Level Info
            Test-PackageSize -FilePath $tempFile | Out-Null
            Write-Log 'SHA-1 check skipped for a local package; the signature check below still applies' -Color Yellow -Level Warning
        }

        Test-FileSignature -FilePath $tempFile

        $exitCode = Install-UpdatePackage -MsuPath $tempFile
        $exitInfo = Get-ExitCodeMessage -ExitCode $exitCode

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Log $exitInfo.Title -Color Green -Level Success
            if ($exitInfo.Description) {
                Write-Log $exitInfo.Description -Color Yellow -Level Warning
            }
        }
        elseif ($exitCode -eq 2359302) {
            # Defensive: the gates above should have caught this. It only reaches here if another
            # process changed the host between the check and the install.
            $currentOs = Get-OSBuildInfo
            if (Test-TargetBuild -OSInfo $currentOs) {
                Write-Log 'Update not required: the system is already on the target build or newer' -Color Green -Level Success
                exit 0
            }
            Write-ErrorPretty -Title $exitInfo.Title `
                -Description $exitInfo.Description `
                -ErrorCode '2359302' `
                -Recommendations $exitInfo.Recommendations
            if ($exitInfo.Details) {
                Write-Log "Details: $($exitInfo.Details)" -Color Cyan -Level Info
            }
            exit 1
        }
        else {
            $unsignedCode = [long]$exitCode
            if ($unsignedCode -lt 0) { $unsignedCode = $unsignedCode + 4294967296 }
            $hexCode = '0x{0:X8} ({1})' -f $unsignedCode, $exitCode
            Write-ErrorPretty -Title $exitInfo.Title `
                -Description $exitInfo.Description `
                -ErrorCode $hexCode `
                -Recommendations $exitInfo.Recommendations
            if ($exitInfo.Details) {
                Write-Log "Details: $($exitInfo.Details)" -Color Cyan -Level Info
            }
            exit 1
        }

        if ($downloadedPackage -and $tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
            Write-Log 'Temporary files cleaned up' -Color Green -Level Success
        }

        # The enablement package always needs one restart, including when wusa.exe returned 0. The
        # build cannot change until that restart, so there is nothing to verify here: a successful
        # exit means "staged", not "upgraded". The operator (or the deployment tool) must confirm
        # CurrentBuild = 26300 after the restart.
        Invoke-RebootHandler -RebootBehavior $Reboot
        Write-Log "[v] Windows 11 $($Script:TargetVersion) enablement package accepted by wusa.exe; the version becomes active after the restart" -Color Green -Level Success
        Write-Log "    Verify after the restart: (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild must be $($Script:TargetBuild)" -Color Gray -Level Info
        exit 0
    }
    catch {
        $recommendation = if ($transcriptStarted) {
            "Check the log file for detailed information: $($Script:LogFile)"
        }
        else {
            'Re-run the script from an elevated PowerShell session and read the console output above'
        }
        Write-ErrorPretty -Title 'Script execution failed' `
            -Description $_.Exception.Message `
            -Recommendations $recommendation
        exit 1
    }
    finally {
        if ($downloadedPackage -and $tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
        if ($transcriptStarted) {
            Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Log file saved to: $($Script:LogFile)" -Color DarkGray -Level Info
        }
    }
}
#endregion
