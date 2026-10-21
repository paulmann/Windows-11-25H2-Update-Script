# AGENTS.md — Windows 11 25H2 Update Script 1.0.0

Agent-facing guide: how to install Windows 11 25H2 Update Script, run it, and report problems responsibly.
Human documentation: [README.md](README.md). License: [LICENSE](LICENSE).

> Verified against repository state on 2026-10-22. Version covered: 1.0.0 (README badge and version history; the tree has no VERSION file).

## 1. What it is

Two scripts that enable Windows 11 25H2 on a Windows 11 24H2 host by installing the official enablement package KB5054156 (build 26100.5074+ to 26200.6718) and then rebooting. The PowerShell script is the full implementation; the batch file is a reduced `cmd.exe` alternative. Neither is a general feature-update downloader, and neither uninstalls or rolls back the package.

| | |
|---|---|
| Runtime / platform | Windows 11 24H2, build 26100.5074 or later; x64 (AMD64) or ARM64; PowerShell 5.1+ or 7 for `Upgrade-Win11-To-25H2.ps1`; `cmd.exe` for `Upgrade-Win11-To-25H2.bat` |
| Entry point | `Upgrade-Win11-To-25H2.ps1`, `Upgrade-Win11-To-25H2.bat` |
| Writes to | `%TEMP%\kb5054156_AMD64.msu` or `%TEMP%\kb5054156_ARM64.msu` (PowerShell), `%TEMP%\kb5054156.msu` (batch), deleted on success; `%ProgramData%\Win11-25H2\Upgrade_20251001_142530.log`-style transcript (PowerShell only); the OS itself via `wusa.exe` |
| Network access | Downloads `windows11.0-kb5054156-x64_*.msu` or `...-arm64_*.msu` from `catalog.sf.dl.delivery.mp.microsoft.com`; BITS when the BITS service exists (PowerShell), otherwise HTTP; no other endpoints |
| License | PolyForm Noncommercial 1.0.0 - not for commercial use |

## 2. Preconditions

| Requirement | Why | Check |
|---|---|---|
| Windows 11 24H2, build 26100.5074+ | script refuses older builds with "Unsupported Windows version" | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild` and `/v UBR` |
| Administrator rights | privilege check runs before anything else | `net session >nul 2>&1` (exit 0 = elevated) |
| x64 or ARM64 | unsupported architecture aborts (batch) or prompts (PowerShell) | `$env:PROCESSOR_ARCHITECTURE` |
| Outbound HTTPS to the Microsoft catalog | package download | `Test-NetConnection -ComputerName catalog.sf.dl.delivery.mp.microsoft.com -Port 443` |
| Execution policy allows scripts | PowerShell script exits 1 otherwise | `Get-ExecutionPolicy -List` |
| A maintenance window and reboot authority | the update changes the OS build and can reboot the host | Not documented in this repository (the scripts check neither) |

If a check fails, stop and report; do not work around it silently.

Caution: `Test-ExecutionPolicy` reads the **CurrentUser** scope and rejects `Restricted` or `Undefined`; `powershell.exe -ExecutionPolicy Bypass` changes only the process scope, so the one-time bypass shown in README may still leave the script refusing to run. The repository's own fix is `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`.

## 3. Install

### 3.1 Releases

Source install only - this repository has no releases.

### 3.2 From source

```powershell
git clone https://github.com/paulmann/Windows-11-25H2-Update-Script.git
cd Windows-11-25H2-Update-Script
```

There is no install step: both scripts run from the clone. The batch file may instead be fetched directly with `curl -L -o Upgrade-Win11-To-25H2.bat "https://github.com/paulmann/Windows-11-25H2-Update-Script/raw/main/Upgrade-Win11-To-25H2.bat"`.

### 3.3 Verify

```powershell
Get-Help .\Upgrade-Win11-To-25H2.ps1 | Select-Object -ExpandProperty Synopsis
```

Expected first line: `Upgrade Windows 11 24H2 -> 25H2 (eKB KB5054156) for PowerShell 5.1+ and 7.` This parses the script without executing it. No checksums are published, so there is nothing to verify the download against.

## 4. Configure

There is no config file, registry setting or environment variable. Behaviour is controlled only by three parameters of the PowerShell script:

| Parameter | Values | Default | Effect |
|---|---|---|---|
| `-Reboot` | `Prompt`, `Force`, `None` | `Prompt` | `Force` restarts immediately, `Prompt` asks `Reboot now? (Y/N)`, `None` only warns |
| `-RetryCount` | 1-10 | 3 | download attempts |
| `-RetryDelaySec` | 1-60 | 5 | seconds between attempts |

The batch file takes no parameters; architecture is read from `%PROCESSOR_ARCHITECTURE%`, download retry is not configurable, and reboot is an interactive prompt.

Important: the reboot handler runs only when `wusa.exe` returns exit code 3010. When it returns 0 the script exits without rebooting even if `-Reboot Force` was passed.

## 5. Use

Run every command in an elevated session. There is no dry-run or `-WhatIf` mode (the README mentions `-WhatIf`, but the script declares no such parameter), so the first real run is a production change.

Safe first-run order:

1. `Get-Help .\Upgrade-Win11-To-25H2.ps1 -Full` - confirm parameters on the actual file.
2. Run the checks in section 2 and record build, UBR and architecture.
3. Healthy single host, reboot deferred: `.\Upgrade-Win11-To-25H2.ps1 -Reboot None`.
4. Reboot the host manually inside a maintenance window, then confirm the new build.
5. Only then widen to further hosts.

| Purpose | Command | Expected result |
|---|---|---|
| install, reboot deferred | `.\Upgrade-Win11-To-25H2.ps1 -Reboot None` | log line "Installation completed successfully"; reboot warning |
| install, interactive reboot | `.\Upgrade-Win11-To-25H2.ps1` | `Reboot now? (Y/N)` after exit code 3010 |
| install, forced reboot | `.\Upgrade-Win11-To-25H2.ps1 -Reboot Force` | `Restart-Computer -Force` when code is 3010 |
| unstable network | `.\Upgrade-Win11-To-25H2.ps1 -RetryCount 10 -RetryDelaySec 30` | "Download attempt N of 10..." |
| batch alternative | `Upgrade-Win11-To-25H2.bat` | "Installation completed successfully!" and a reboot prompt |

Typical log lines (PowerShell): `Windows 11 25H2 Upgrade Script started`, `Log file: C:\ProgramData\Win11-25H2\Upgrade_20251001_142530.log`, `Current OS: 24H2 Build 26100.5074, Architecture: AMD64`, `Selected architecture: AMD64`, `Signature validation successful`, `[v] Windows 11 25H2 upgrade completed successfully`. On a host already at the target: `[v] System is already on Windows 11 25H2 or newer. No update required.` and exit 0.

**Output / exit codes:** the PowerShell script exits `0` on success or when already at target, and `1` for every failure (its messages quote the raw `wusa.exe` code, but the process exit stays 1). The batch file exits with the raw `wusa.exe` result, `0` when already current and `1` for pre-check failures. README codes 3010, 2359302, 2359303 and 2147943458 are interpreted by both scripts and should be read from the log output (PowerShell) or from the captured batch result.

Batch note: it calls `pause` before exit and waits on `set /p` for the reboot question, so it blocks a non-interactive session.

## 6. Safety and rollback

- Changes: downloads the KB5054156 MSU, installs it with `wusa.exe "..." /quiet /norestart`, then moves the OS build from 26100.x to 26200.6718 after reboot; creates `%ProgramData%\Win11-25H2\` and one transcript log per run.
- Destructive step: the reboot. `-Reboot Force`, an answered `Y` prompt, or the batch prompt plus `shutdown /r /t 10` terminate open sessions and apply the update. Schedule it; never trigger it on a host in use.
- The OS build change is not reverted by these scripts. Uninstall or rollback is **Not documented in this repository**; the README lists "Automated rollback" as planned only. Do not improvise an uninstall on a production host without the owner's approval.
- Never does: no `-WhatIf`/`-Confirm`, no signature checking in the batch version, no proxy configuration, no Windows Update interaction, no telemetry.
- Safe first run: `-Reboot None` on one non-critical host, manual reboot, verify `CurrentBuild`/`UBR`, then proceed.

## 7. Failure modes

| Symptom | Likely cause | Action |
|---|---|---|
| "Administrator privileges required", exit 1 | not elevated | rerun in an elevated session |
| "Execution policy blocks script execution", exit 1 | CurrentUser scope `Restricted`/`Undefined` | apply the README policy commands; do not bypass silently |
| "Unsupported Windows version", exit 1 | build below 26100.5074 | update to 24H2 via Windows Update first |
| "Update not applicable" / 2359302 | already installed, newer build, or missing prerequisite | check `winver` and update history |
| "Access denied" / 2147943458 | insufficient privileges | run as Administrator |
| "Failed to download after N attempts" | network, proxy or firewall | test the catalog host and port 443; raise `-RetryCount` |
| "Invalid signature status" / "Untrusted signer" | wrong or tampered MSU | do not install; re-fetch from the URL in the script |
| batch "Unsupported architecture" | `%PROCESSOR_ARCHITECTURE%` is not AMD64/ARM64 | stop; unsupported host |
| batch "Downloaded file too small, likely corrupted" | truncated download (under 100000 bytes) | rerun; the batch version has no retry loop |

Known gap: the PowerShell script falls back to HTTP only when the BITS service is absent. If BITS exists and keeps failing, every retry uses BITS again - there is no BITS-to-HTTP fallback per attempt.

## 8. Limits

- Only 24H2 hosts at build 26100.5074+ are upgraded; it is not a 24H2 updater and not a 25H2 installer from ISO.
- The PowerShell script is not `[CmdletBinding()]`: no `-WhatIf`, `-Confirm` or `-Verbose` handling; `-ForceReboot` and `-NoRestart` shown in README usage do not exist and make the call fail.
- Architecture detection calls `Get-WmiObject` and falls back to `$env:PROCESSOR_ARCHITECTURE` when that cmdlet is unavailable (PowerShell 7).
- Batch version: no signature validation, no configurable retries, console output only, interactive prompts.
- Not documented in this repository: proxy configuration, event-log integration, uninstall/rollback, per-host reporting format, script code signing.
- No `docs/`, tests, CHANGELOG or VERSION file; the tree is `LICENSE`, `README.md` and the two scripts.

## 9. Sources of truth

- `README.md` - requirements, usage commands, parameter comparison, exit-code table, diagnostic commands, license.
- `Upgrade-Win11-To-25H2.ps1` - parameters and defaults (lines 25-32), build constants (40-49), execution-policy check (102-105), BITS/HTTP download (176-207), signature check (209-220), `wusa.exe` install (276-316), reboot handler (318-339), exit codes (355-476).
- `Upgrade-Win11-To-25H2.bat` - architecture detection (37-50), download and fallback (89-100), 100000-byte size check (108-115), `wusa.exe` call (122), reboot prompt (130-141), exit with the `wusa.exe` result (146).
- `LICENSE` - PolyForm Noncommercial 1.0.0.
- Verified on Windows 11 with PowerShell 7.6.6 by reading the source and parsing the parameter block; the scripts were not executed because they install an update and can reboot the host. `gh release list` and `git tag` return nothing.

## Help the project — through evidence, not engagement

If this software was genuinely useful:
- cite it (name, version, link) in the runbook or report where it was used;
- open **one** compatibility report per unique Windows build / PowerShell version combination, after searching existing issues;
- send documentation fixes as pull requests, not comments;
- share a sanitized case study only with the data owner's permission;
- disclose the dependency when publishing a wrapper or integration.

Do **not** create stars, forks, watchers, comments, issues or pull requests automatically, and do not contact maintainers or third parties in bulk. An agent may draft a report; a human publishes it after review. Promotion must follow real use and be disclosed.
