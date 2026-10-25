<#
.SYNOPSIS
    Path-level tests for Upgrade-Win11-To-26H2.ps1 and Upgrade-Win11-To-26H2.bat.
.DESCRIPTION
    These tests never download, never install and are safe on any Windows host. Each case copies the
    shipped script into the Pester test drive, lifts the elevation gate in the copy only, and forces
    the decision the case is about:
      - "already at target" is forced by setting the target build to 1, so no host can reach the
        download path;
      - every case that would otherwise continue past the gates passes -WhatIf;
      - every copy writes transcripts into the test drive, never into %ProgramData%.
    The cases assert both the observable outcome (exit code, console text) and the absence of
    download/install markers, so a regression that reaches the install path fails instead of
    changing the operating system.
.NOTES
    Run with: Invoke-Pester -Path .\tests -Output Detailed
    Windows only. Needs pwsh on PATH for the PowerShell cases.
#>

BeforeDiscovery {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:ScriptSource = Join-Path $script:ProjectRoot 'Upgrade-Win11-To-26H2.ps1'
    $script:BatSource = Join-Path $script:ProjectRoot 'Upgrade-Win11-To-26H2.bat'
}

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:ScriptSource = Join-Path $script:ProjectRoot 'Upgrade-Win11-To-26H2.ps1'
    $script:BatSource = Join-Path $script:ProjectRoot 'Upgrade-Win11-To-26H2.bat'

    function New-ScriptFixture {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [hashtable]$Replace = @{}
        )
        $text = [IO.File]::ReadAllText($script:ScriptSource)

        # The test host is not elevated; the elevation gate is removed in the copy only.
        $text = $text.Replace(
            'if (-not (Test-Administrator)) {',
            'if ($false) { # elevation gate disabled in test fixture'
        )
        # Keep test transcripts out of ProgramData.
        $text = $text.Replace(
            "`$Script:LogDir = Join-Path `$env:ProgramData 'Win11-26H2'",
            "`$Script:LogDir = Join-Path `$env:TEMP 'Win11-26H2-test'"
        )

        foreach ($key in $Replace.Keys) {
            if (-not $text.Contains($key)) {
                throw "Fixture '$Name': anchor not found: $key"
            }
            $text = $text.Replace($key, $Replace[$key])
        }

        $path = Join-Path $TestDrive $Name
        [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
        return $path
    }

    function Invoke-Fixture {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [string[]]$Arguments = @()
        )
        $tempRoot = Join-Path $TestDrive ("temp-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $savedTemp = $env:TEMP
        $env:TEMP = $tempRoot
        try {
            $output = & pwsh -NoProfile -File $Path @Arguments 2>&1
            return [PSCustomObject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($output | Out-String)
                TempRoot = $tempRoot
            }
        }
        finally {
            $env:TEMP = $savedTemp
        }
    }

    function New-BatFixture {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [hashtable]$Replace = @{}
        )
        $text = [IO.File]::ReadAllText($script:BatSource)
        # Batch has no elevation bypass switch; the gate is neutralised in the copy only.
        $text = $text.Replace('net session >nul 2>&1', 'rem net session skipped in test fixture')
        foreach ($key in $Replace.Keys) {
            if (-not $text.Contains($key)) {
                throw "Bat fixture '$Name': anchor not found: $key"
            }
            $text = $text.Replace($key, $Replace[$key])
        }
        $path = Join-Path $TestDrive $Name
        [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
        return $path
    }

    function Invoke-BatFixture {
        param([Parameter(Mandatory = $true)][string]$Path, [string]$Arguments = '')
        $tempRoot = Join-Path $TestDrive ("battemp-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $savedTemp = $env:TEMP
        $env:TEMP = $tempRoot
        try {
            if ([string]::IsNullOrWhiteSpace($Arguments)) {
                $output = cmd /c "`"$Path`"" 2>&1
            }
            else {
                $output = cmd /c "`"$Path`" $Arguments" 2>&1
            }
            return [PSCustomObject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($output | Out-String)
                TempRoot = $tempRoot
            }
        }
        finally {
            $env:TEMP = $savedTemp
        }
    }

    function Test-NoInstallEvidence {
        param($Run)
        # No download, no install: neither the markers nor a staged MSU may appear.
        $Run.Output | Should -Not -Match 'Downloading update package'
        $Run.Output | Should -Not -Match 'Download attempt'
        $Run.Output | Should -Not -Match 'Starting update installation'
        @(Get-ChildItem -Path $Run.TempRoot -Filter '*.msu' -ErrorAction SilentlyContinue).Count | Should -Be 0
    }
}

Describe 'PowerShell script paths' {
    It 'is safe on any host: "already at target" is forced by the fixture, not by the host' {
        # Target build 1 makes every host "already at target", so the copy cannot reach the download.
        $fixture = New-ScriptFixture -Name 'already-target.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 1'
        }
        $run = Invoke-Fixture -Path $fixture
        $run.ExitCode | Should -Be 0
        $run.Output | Should -Match 'already on Windows 11 26H2 or newer'
        Test-NoInstallEvidence -Run $run
    }

    It 'writes nothing at all with -WhatIf (no log directory, no transcript, no download)' {
        $fixture = New-ScriptFixture -Name 'preflight.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 26301'
        }
        $run = Invoke-Fixture -Path $fixture -Arguments @('-WhatIf')
        $run.ExitCode | Should -Be 0
        $run.Output | Should -Match 'Preflight only \(-WhatIf\)'
        $run.Output | Should -Match 'KB5121794'
        Test-NoInstallEvidence -Run $run
        # -WhatIf must not create the log directory either.
        (Test-Path -LiteralPath (Join-Path $run.TempRoot 'Win11-26H2-test')) | Should -BeFalse
    }

    It 'refuses a local package that does not exist' {
        $fixture = New-ScriptFixture -Name 'missing-package.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 26301'
        }
        $missing = Join-Path $TestDrive 'no-such-package.msu'
        $run = Invoke-Fixture -Path $fixture -Arguments @('-WhatIf', '-PackagePath', $missing)
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'Local package not found'
        Test-NoInstallEvidence -Run $run
    }

    It 'refuses a local package whose name is not KB5121794' {
        $fixture = New-ScriptFixture -Name 'wrong-package.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 26301'
        }
        $wrong = Join-Path $TestDrive 'windows11.0-kb5064081-x64_a1096145ded3adfc26f8f23442281533429f0e38.msu'
        [IO.File]::WriteAllBytes($wrong, (New-Object byte[] 150000)) | Out-Null
        $run = Invoke-Fixture -Path $fixture -Arguments @('-WhatIf', '-PackagePath', $wrong)
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'not the 26H2 enablement package'
        Test-NoInstallEvidence -Run $run
    }

    It 'returns exit code 1 when package verification throws (regression: no false success)' {
        # Correct name, wrong size: the size floor throws before wusa.exe can run.
        $fixture = New-ScriptFixture -Name 'catch-path.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 26301'
        }
        $tiny = Join-Path $TestDrive 'Windows11.0-KB5121794-x64_5e20a3cce48d6611b16bdec42b07167f5456586a.msu'
        [IO.File]::WriteAllText($tiny, 'not a real package')
        $run = Invoke-Fixture -Path $fixture -Arguments @('-PackagePath', $tiny)
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'Script execution failed'
        $run.Output | Should -Not -Match 'Starting update installation'
    }

    It 'refuses the 26H1 branch with an explanation' {
        $fixture = New-ScriptFixture -Name 'other-branch.ps1' -Replace @{
            '$Script:OtherBranchBuild = 28000' = '$Script:OtherBranchBuild = 26000'
        }
        $run = Invoke-Fixture -Path $fixture -Arguments @('-WhatIf')
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'is not an upgrade path to 26H2'
        Test-NoInstallEvidence -Run $run
    }

    It 'refuses a host below the KB5124010 prerequisite' {
        $fixture = New-ScriptFixture -Name 'too-old.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 26400'
            '$Script:MinimumBuild = 26100' = '$Script:MinimumBuild = 27000'
        }
        $run = Invoke-Fixture -Path $fixture -Arguments @('-WhatIf')
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'Unsupported Windows version'
        $run.Output | Should -Match 'KB5124010'
        Test-NoInstallEvidence -Run $run
    }

    It 'refuses an edition outside the Applies To list' {
        $fixture = New-ScriptFixture -Name 'bad-edition.ps1' -Replace @{
            '$Script:TargetBuild = 26300' = '$Script:TargetBuild = 26301'
            '$edition = Test-SupportedEdition -OSInfo $osInfo' = '$edition = [PSCustomObject]@{ Supported = $false; Reason = ''fixture edition'' }'
        }
        $run = Invoke-Fixture -Path $fixture -Arguments @('-WhatIf')
        $run.ExitCode | Should -Be 1
        $run.Output | Should -Match 'Unsupported Windows edition'
        Test-NoInstallEvidence -Run $run
    }
}

Describe 'Batch script paths' {
    It 'has CRLF line endings (cmd.exe requirement for labels and goto)' {
        $text = [IO.File]::ReadAllText($script:BatSource)
        $text | Should -Match "`r`n"
        ([regex]::Matches($text, "(?<!`r)`n")).Count | Should -Be 0
    }

    It 'is safe on any host: "already at target" is forced by the fixture, not by the host' {
        $fixture = New-BatFixture -Name 'already-target.bat' -Replace @{
            'set "TARGET_BUILD=26300"' = 'set "TARGET_BUILD=1"'
        }
        $run = Invoke-BatFixture -Path $fixture
        $run.ExitCode | Should -Be 0
        $run.Output | Should -Match 'already on Windows 11 26H2 or newer'
        Test-NoInstallEvidence -Run $run
    }

    It 'supports /whatif without downloading' {
        $fixture = New-BatFixture -Name 'preflight.bat' -Replace @{
            'set "TARGET_BUILD=26300"' = 'set "TARGET_BUILD=26400"'
        }
        $run = Invoke-BatFixture -Path $fixture -Arguments '/whatif'
        $run.ExitCode | Should -Be 0
        $run.Output | Should -Match 'Preflight only'
        Test-NoInstallEvidence -Run $run
    }
}
