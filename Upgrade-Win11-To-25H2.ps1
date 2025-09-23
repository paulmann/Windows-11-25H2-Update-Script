<#
.SYNOPSIS
    Reliable upgrade script for Windows 11 24H2 → 25H2 (eKB KB5054156).

.DESCRIPTION
    - Auto-detects system architecture (x64/ARM64) or prompts user.
    - Validates admin privileges and execution policy.
    - Checks current Windows 11 version/build and skips if already 25H2.
    - Downloads update via BITS or HTTP fallback with retry logic.
    - Verifies MSU signature before installation.
    - Installs update silently via WUSA.
    - Manages reboot behavior with clear options.
    - Logs all actions via Start-Transcript.

.NOTES
    Author    : Mikhail Deynekin mid1977@gmail.com
    GitHub    : https://github.com/deynekin/Win11-Upgrade
    Website   : https://deynekin.com
    Location  : Moskva, Russia
    Requires  : PowerShell 7+, Windows 11 24H2 (Build 26100.5074+) or above
#>

namespace Win11.Upgrade

enum RebootOption {
	Prompt
	Force
	None
}

class UpgradeManager {
	#region Readonly properties
	readonly RebootOption $RebootBehavior
	readonly int          $RetryCount
	readonly int          $RetryDelaySec
	readonly string       $LogPath
	readonly [int]        $TargetBuild  = 26200
	readonly [int]        $TargetUbr    = 6718
	#endregion

	UpgradeManager([RebootOption]$reboot = [RebootOption]::Prompt, [int]$retry = 3, [int]$delay = 5) {
		$this.RebootBehavior = $reboot
		$this.RetryCount     = $retry
		$this.RetryDelaySec  = $delay

		$logDir = Join-Path $env:ProgramData 'Win11-25H2'
		New-Item -Path $logDir -ItemType Directory -Force | Out-Null
		$this.LogPath = Join-Path $logDir ("Upgrade25H2_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

		Start-Transcript -Path $this.LogPath -IncludeInvocationHeader -Force | Out-Null
	}

	[void] Dispose() {
		Stop-Transcript | Out-Null
	}

	[void] Run() {
		try {
			$this.ValidateEnvironment()
			$osInfo = $this.GetOsInfo()

			Write-Host "Current OS: $($osInfo.ProductName) $($osInfo.DisplayVersion) Build $($osInfo.Build).$($osInfo.UBR)"
			if ($this.IsAlreadyUpdated($osInfo)) {
				Write-Host "System is already on or beyond Windows 11 25H2 (Build $($this.TargetBuild).$($this.TargetUbr)). No update needed."
				return
			}

			$this.EnsureOsVersion($osInfo)
			$arch = $this.DetermineArch($osInfo)
			$url  = $this.GetKbUrl($arch)
			$temp = Join-Path $env:TEMP 'kb5054156.msu'

			# Cleanup stale file
			if (Test-Path $temp) { Remove-Item $temp -Force }

			$this.DownloadWithRetry($url, $temp)
			$this.VerifySignature($temp)
			$this.InstallUpdate($temp)
		}
		catch {
			Write-Error $_.Exception.Message
			exit 1
		}
		finally {
			$this.Dispose()
		}
	}

	#region Validation
	[void] ValidateEnvironment() {
		if (-not ([Security.Principal.WindowsPrincipal] `
				[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
				[Security.Principal.WindowsBuiltinRole]::Administrator)) {
			throw 'Script must be run as Administrator.'
		}

		$policy = Get-ExecutionPolicy -Scope CurrentUser
		if ($policy -in @('Restricted','Undefined')) {
			throw "Execution policy '$policy' blocks script. Run:`n  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted"
		}
	}
	#endregion

	#region OS Info
	[pscustomobject] GetOsInfo() {
		$reg = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
		$p   = Get-ItemProperty -Path $reg
		[pscustomobject]@{
			ProductName    = $p.ProductName
			DisplayVersion = $p.DisplayVersion
			Build          = [int]$p.CurrentBuild
			UBR            = [int]$p.UBR
			Arch           = $env:PROCESSOR_ARCHITECTURE
		}
	}

	[bool] IsAlreadyUpdated([pscustomobject]$os) {
		return ($os.Build -gt $this.TargetBuild) `
			-or ($os.Build -eq $this.TargetBuild -and $os.UBR -ge $this.TargetUbr)
	}

	[void] EnsureOsVersion([pscustomobject]$os) {
		if ($os.Build -ne 26100 -or $os.UBR -lt 5074) {
			throw 'Requires Windows 11 24H2 (Build 26100.5074+) before applying eKB.'
		}
	}
	#endregion

	#region Architecture
	[string] DetermineArch([pscustomobject]$os) {
		$available = @('AMD64','ARM64')
		if ($available -contains $os.Arch.ToUpper()) {
			return $os.Arch.ToUpper()
		}
		Write-Host "Detected arch '$($os.Arch)' is unsupported."
		$choice = Read-Host "Select architecture to install (x64/ARM64)"
		switch ($choice.ToLower()) {
			'x64'   { return 'AMD64' }
			'arm64' { return 'ARM64' }
			default { throw 'Invalid architecture selection.' }
		}
	}

	[string] GetKbUrl([string]$arch) {
		return [match]$arch {
			'AMD64' => 'https://catalog.sf.dl.delivery.microsoft.com/filestreamingservice/files/fa84cc49-18b2-4c26-b389-90c96e6ae0d2/public/windows11.0-kb5054156-x64_a0c1638cbcf4cf33dbe9a5bef69db374b4786974.msu'
			'ARM64' => 'https://catalog.sf.dl.delivery.microsoft.com/filestreamingservice/files/78b265e5-83a8-4e0a-9060-efbe0bac5bde/public/windows11.0-kb5054156-arm64_3d5c91aaeb08a87e0717f263ad4a61186746e465.msu'
			default { throw "Unsupported arch '$arch'." }
		}
	}
	#endregion

	#region Download & Verification
	[void] DownloadWithRetry([string]$uri, [string]$outFile) {
		for ($i = 1; $i -le $this.RetryCount; $i++) {
			try {
				if (Get-Service BITS -ErrorAction SilentlyContinue) {
					Start-BitsTransfer -Source $uri -Destination $outFile -ErrorAction Stop
				}
				else {
					Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing -ErrorAction Stop
				}
				return
			}
			catch {
				if (Test-Path $outFile) { Remove-Item $outFile -Force }
				Start-Sleep -Seconds $this.RetryDelaySec
			}
		}
		throw 'Failed to download update package after retries.'
	}

	[void] VerifySignature([string]$path) {
		$sig = Get-AuthenticodeSignature -FilePath $path
		if ($sig.Status -ne 'Valid' -or `
			$sig.SignerCertificate.Subject -notmatch 'Microsoft') {
			throw 'Invalid or untrusted MSU signature.'
		}
	}
	#endregion

	#region Installation
	[void] InstallUpdate([string]$msu) {
		$args = "`"$msu`" /quiet /norestart"
		$p = Start-Process wusa.exe -ArgumentList $args -Wait -PassThru
		switch ($p.ExitCode) {
			0 { Write-Host 'Update installed successfully.' }
			default { throw "WUSA exit code $($p.ExitCode)." }
		}

		switch ($this.RebootBehavior) {
			'Reboot' { Restart-Computer -Force }
			'Prompt' {
				$resp = Read-Host 'Reboot now? (y/n)'
				if ($resp -ieq 'y') { Restart-Computer -Force }
			}
			'None' { Write-Host 'Reboot suppressed per policy.' }
		}
	}
	#endregion
}

#region Script EntryPoint
param(
	[Win11.Upgrade.RebootOption]$Reboot = [Win11.Upgrade.RebootOption]::Prompt,
	[switch]$NoRestart,
	[switch]$ForceReboot
)

if ($NoRestart)  { $Reboot = [Win11.Upgrade.RebootOption]::None }
elseif ($ForceReboot) { $Reboot = [Win11.Upgrade.RebootOption]::Force }

$manager = [Win11.Upgrade.UpgradeManager]::new($Reboot)
$manager.Run()
#endregion
