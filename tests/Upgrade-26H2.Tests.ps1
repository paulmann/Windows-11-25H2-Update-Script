<#
.SYNOPSIS
    Unit tests for Upgrade-Win11-To-26H2.ps1 decision logic.
.DESCRIPTION
    The script installs an operating-system update, so it is never executed here. The file
    dot-sources the script (the script skips its main block when dot-sourced) and exercises the pure
    functions: build gating, edition gating, architecture normalisation, package identity, exit-code
    mapping and package verification.
.NOTES
    Run with: Invoke-Pester -Path .\tests -Output Detailed
    Requires PowerShell 7 and Pester 5.1+.
#>

BeforeAll {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Upgrade-Win11-To-26H2.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Script not found: $scriptPath"
    }

    # Loads the functions without running the main block.
    . $scriptPath

    function New-OsInfo {
        param(
            [int]$Build,
            [int]$Ubr,
            [string]$DisplayVersion = '',
            [string]$Architecture = 'AMD64',
            [string]$EditionID = 'Professional',
            [string]$InstallationType = 'Client',
            [string]$ProductName = 'Windows 10 Pro'
        )
        [PSCustomObject]@{
            ProductName      = $ProductName
            DisplayVersion   = $DisplayVersion
            EditionID        = $EditionID
            InstallationType = $InstallationType
            CurrentBuild     = $Build
            UBR              = $Ubr
            Architecture     = $Architecture
        }
    }
}

Describe 'Script shape' {
    It 'parses without syntax errors' {
        $errors = $null
        $tokens = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path (Split-Path -Parent $PSScriptRoot) 'Upgrade-Win11-To-26H2.ps1'),
            [ref]$tokens,
            [ref]$errors
        ) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'declares the documented parameters, including WhatIf' {
        $command = Get-Command -Name (Join-Path (Split-Path -Parent $PSScriptRoot) 'Upgrade-Win11-To-26H2.ps1')
        foreach ($name in @('Reboot', 'RetryCount', 'RetryDelaySec', 'Architecture', 'PackagePath', 'WhatIf')) {
            $command.Parameters.Keys | Should -Contain $name
        }
    }

    It 'uses exit codes for every script-scope termination (no bare return N)' {
        $path = Join-Path (Split-Path -Parent $PSScriptRoot) 'Upgrade-Win11-To-26H2.ps1'
        $bareReturns = Select-String -Path $path -Pattern '^\s{8}return [01]$'
        $bareReturns.Count | Should -Be 0
    }
}

Describe 'Version constants' {
    It 'targets build 26300 and only uses it as a marker' {
        $Script:TargetBuild | Should -Be 26300
        $Script:TargetVersion | Should -Be '26H2'
        $Script:FirstGaBuild | Should -Be '26300.9457'
    }

    It 'requires KB5124010 with a per-ladder build floor' {
        $Script:MinimumBuild | Should -Be 26100
        $Script:PrerequisiteKb | Should -BeExactly 'KB5124010'
        $Script:MinimumUbr[26100] | Should -Be 9546
        $Script:MinimumUbr[26200] | Should -Be 9550
        Get-MinimumUbr -Build 26200 | Should -Be 9550
        Get-MinimumUbr -Build 26100 | Should -Be 9546
        Get-MinimumUbr -Build 99999 | Should -Be 9546
    }

    It 'refuses the 26H1 branch from build 28000' {
        $Script:OtherBranchBuild | Should -Be 28000
        $Script:OtherBranchVersion | Should -Be '26H1'
    }

    It 'lists the LTSC edition IDs that KB5121794 excludes' {
        $Script:UnsupportedEditionIds | Should -Contain 'EnterpriseS'
        $Script:UnsupportedEditionIds | Should -Contain 'IoTEnterpriseS'
    }

    It 'points every download URL at KB5121794 on the Microsoft CDN' {
        $Script:EnablementUrl.Keys | Should -Contain 'AMD64'
        $Script:EnablementUrl.Keys | Should -Contain 'ARM64'
        foreach ($arch in @('AMD64', 'ARM64')) {
            $Script:EnablementUrl[$arch] | Should -Match '^https://catalog\.sf\.dl\.delivery\.mp\.microsoft\.com/'
            $Script:EnablementUrl[$arch] | Should -Match 'KB5121794'
            if ($arch -eq 'AMD64') {
                $Script:EnablementUrl[$arch] | Should -Match '-x64_'
            }
            else {
                $Script:EnablementUrl[$arch] | Should -Match '-arm64_'
            }
        }
    }

    It 'pins the SHA-1 fingerprints published in the package file names' {
        $Script:EnablementSha1['AMD64'] | Should -BeExactly '5e20a3cce48d6611b16bdec42b07167f5456586a'
        $Script:EnablementSha1['ARM64'] | Should -BeExactly '77a76caf2d362bb293a4d18058388f2717365abe'
        foreach ($arch in @('AMD64', 'ARM64')) {
            $Script:EnablementSha1[$arch] | Should -Match '^[0-9a-f]{40}$'
            $Script:EnablementUrl[$arch] | Should -Match ([regex]::Escape($Script:EnablementSha1[$arch]))
        }
    }

    It 'keeps a download sanity floor well below the real 174 KB package' {
        $Script:MinimumPackageBytes | Should -Be 100000
    }
}

Describe 'Test-TargetBuild' {
    It 'accepts any 26300 build, including an early UBR' {
        Test-TargetBuild -OSInfo (New-OsInfo -Build 26300 -Ubr 1) | Should -BeTrue
        Test-TargetBuild -OSInfo (New-OsInfo -Build 26300 -Ubr 9457) | Should -BeTrue
        Test-TargetBuild -OSInfo (New-OsInfo -Build 26300 -Ubr 9711) | Should -BeTrue
    }

    It 'rejects 25H2 (26200.9550)' {
        Test-TargetBuild -OSInfo (New-OsInfo -Build 26200 -Ubr 9550) | Should -BeFalse
    }

    It 'rejects 24H2 (26100.9550)' {
        Test-TargetBuild -OSInfo (New-OsInfo -Build 26100 -Ubr 9550) | Should -BeFalse
    }

    It 'treats a later build as newer' {
        Test-TargetBuild -OSInfo (New-OsInfo -Build 26400 -Ubr 1) | Should -BeTrue
    }
}

Describe 'Test-MinimumBuild' {
    It 'accepts 24H2 at 26100.9546 (KB article prerequisite)' {
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 26100 -Ubr 9546) | Should -BeTrue
    }

    It 'rejects 24H2 one revision below the floor' {
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 26100 -Ubr 9545) | Should -BeFalse
    }

    It 'accepts 25H2 at 26200.9550' {
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 26200 -Ubr 9550) | Should -BeTrue
    }

    It 'rejects 25H2 one revision below its own, higher floor' {
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 26200 -Ubr 9549) | Should -BeFalse
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 26200 -Ubr 9278) | Should -BeFalse
    }

    It 'rejects Windows 11 23H2 (22631)' {
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 22631 -Ubr 7652) | Should -BeFalse
    }

    It 'rejects build 26100 with a missing UBR' {
        Test-MinimumBuild -OSInfo (New-OsInfo -Build 26100 -Ubr 0) | Should -BeFalse
    }
}

Describe 'Test-OtherBranch' {
    It 'flags 26H1 (28000)' {
        Test-OtherBranch -OSInfo (New-OsInfo -Build 28000 -Ubr 3231) | Should -BeTrue
    }

    It 'flags any later branch' {
        Test-OtherBranch -OSInfo (New-OsInfo -Build 29000 -Ubr 1) | Should -BeTrue
    }

    It 'does not flag 26H2 or older versions' {
        Test-OtherBranch -OSInfo (New-OsInfo -Build 26300 -Ubr 9711) | Should -BeFalse
        Test-OtherBranch -OSInfo (New-OsInfo -Build 26200 -Ubr 9550) | Should -BeFalse
    }
}

Describe 'Test-SupportedEdition' {
    It 'accepts the editions KB5121794 lists' {
        (Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID 'Professional')).Supported | Should -BeTrue
        (Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID 'Enterprise')).Supported | Should -BeTrue
        (Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID 'IoTEnterprise')).Supported | Should -BeTrue
        (Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID 'Core')).Supported | Should -BeTrue
    }

    It 'refuses Windows Server by installation type' {
        $result = Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID 'ServerStandard' -InstallationType 'Server')
        $result.Supported | Should -BeFalse
        $result.Reason | Should -Match 'Windows Server'
    }

    It 'refuses the LTSC edition IDs' {
        foreach ($edition in @('EnterpriseS', 'IoTEnterpriseS')) {
            $result = Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID $edition)
            $result.Supported | Should -BeFalse
            $result.Reason | Should -Match 'LTSC'
        }
    }

    It 'refuses an LTSC product name even with an unknown edition ID' {
        $result = Test-SupportedEdition -OSInfo (New-OsInfo -Build 26100 -Ubr 9546 -EditionID 'SomethingNew' -ProductName 'Windows 11 IoT Enterprise LTSC')
        $result.Supported | Should -BeFalse
    }
}

Describe 'Architecture resolution' {
    It 'classifies "ARM 64-bit Processor" as ARM64 (ARM first)' {
        Resolve-Architecture -Candidates @('ARM 64-bit Processor') | Should -Be 'ARM64'
        Resolve-Architecture -Candidates @('ARM64') | Should -Be 'ARM64'
    }

    It 'classifies x64 candidates as AMD64' {
        Resolve-Architecture -Candidates @('64-bit') | Should -Be 'AMD64'
        Resolve-Architecture -Candidates @('AMD64') | Should -Be 'AMD64'
        Resolve-Architecture -Candidates @('X64') | Should -Be 'AMD64'
    }

    It 'prefers an ARM candidate even when a 64-bit candidate comes first' {
        Resolve-Architecture -Candidates @('64-bit', 'ARM 64-bit Processor') | Should -Be 'ARM64'
    }

    It 'returns null when no candidate is recognised' {
        Resolve-Architecture -Candidates @() | Should -BeNullOrEmpty
        Resolve-Architecture -Candidates @('MIPS') | Should -BeNullOrEmpty
    }

    It 'normalises interactive architecture input' {
        Get-ArchitectureChoiceValue -Choice 'arm64' | Should -Be 'ARM64'
        Get-ArchitectureChoiceValue -Choice ' x64 ' | Should -Be 'AMD64'
        Get-ArchitectureChoiceValue -Choice 'AMD64' | Should -Be 'AMD64'
        Get-ArchitectureChoiceValue -Choice '' | Should -Be 'AMD64'
        Get-ArchitectureChoiceValue -Choice 'risc-v' | Should -BeNullOrEmpty
    }

    It 'maps the live host to a supported package architecture' {
        Get-OSArchitecture | Should -BeIn @('AMD64', 'ARM64')
    }
}

Describe 'Package identity' {
    It 'accepts the real x64 and ARM64 file names' {
        (Test-PackageIdentity -FileName 'Windows11.0-KB5121794-x64_5e20a3cce48d6611b16bdec42b07167f5456586a.msu' -Architecture 'AMD64').Valid | Should -BeTrue
        (Test-PackageIdentity -FileName 'Windows11.0-KB5121794-arm64_77a76caf2d362bb293a4d18058388f2717365abe.msu' -Architecture 'ARM64').Valid | Should -BeTrue
    }

    It 'refuses a cumulative update with a different KB number' {
        $result = Test-PackageIdentity -FileName 'windows11.0-kb5064081-x64_a1096145ded3adfc26f8f23442281533429f0e38.msu' -Architecture 'AMD64'
        $result.Valid | Should -BeFalse
        $result.Reason | Should -Match 'KB5121794'
    }

    It 'refuses a package for the wrong architecture' {
        (Test-PackageIdentity -FileName 'Windows11.0-KB5121794-arm64_77a76caf2d362bb293a4d18058388f2717365abe.msu' -Architecture 'AMD64').Valid | Should -BeFalse
        (Test-PackageIdentity -FileName 'Windows11.0-KB5121794-x64_5e20a3cce48d6611b16bdec42b07167f5456586a.msu' -Architecture 'ARM64').Valid | Should -BeFalse
    }

    It 'refuses a renamed file that carries no KB number' {
        (Test-PackageIdentity -FileName 'my-package.msu' -Architecture 'AMD64').Valid | Should -BeFalse
    }
}

Describe 'Exit-code mapping' {
    It 'maps 0 and 3010 to success titles' {
        (Get-ExitCodeMessage -ExitCode 0).Title | Should -Be 'Installation completed successfully'
        (Get-ExitCodeMessage -ExitCode 3010).Title | Should -Be 'Installation completed successfully'
    }

    It 'maps the documented wusa.exe codes' {
        (Get-ExitCodeMessage -ExitCode 2359302).Title | Should -Be 'Update not applicable'
        (Get-ExitCodeMessage -ExitCode 2359303).Title | Should -Be 'Installation in progress'
        (Get-ExitCodeMessage -ExitCode 2359299).Title | Should -Be 'Update not applicable'
    }

    It 'maps signed and unsigned Win32 error forms' {
        (Get-ExitCodeMessage -ExitCode 2147942405).Title | Should -Match 'Access denied'
        (Get-ExitCodeMessage -ExitCode -2147024891).Title | Should -Match 'Access denied'
        (Get-ExitCodeMessage -ExitCode 2148468771).Title | Should -Match 'Prerequisites'
        (Get-ExitCodeMessage -ExitCode -2146498525).Title | Should -Match 'Prerequisites'
    }

    It 'formats an unknown code in hex' {
        (Get-ExitCodeMessage -ExitCode 12345).Details | Should -Match '0x00003039'
        (Get-ExitCodeMessage -ExitCode -2147024896).Details | Should -Match '0x80070000'
    }
}

Describe 'Package verification' {
    It 'accepts a file exactly at the size floor' {
        $file = Join-Path $TestDrive 'at-floor.msu'
        [IO.File]::WriteAllBytes($file, (New-Object byte[] 100000))
        Test-PackageSize -FilePath $file | Should -Be 100000
    }

    It 'rejects a file one byte below the size floor' {
        $file = Join-Path $TestDrive 'below-floor.msu'
        [IO.File]::WriteAllBytes($file, (New-Object byte[] 99999))
        { Test-PackageSize -FilePath $file } | Should -Throw
    }

    It 'accepts a file whose SHA-1 matches' {
        $file = Join-Path $TestDrive 'hash-ok.bin'
        [IO.File]::WriteAllText($file, 'enablement package fixture')
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA1).Hash.ToLowerInvariant()
        { Test-PackageHash -FilePath $file -ExpectedSha1 $hash } | Should -Not -Throw
    }

    It 'rejects a file whose SHA-1 does not match' {
        $file = Join-Path $TestDrive 'hash-bad.bin'
        [IO.File]::WriteAllText($file, 'tampered fixture')
        { Test-PackageHash -FilePath $file -ExpectedSha1 ('0' * 40) } | Should -Throw
    }
}

Describe 'Get-OSBuildInfo' {
    It 'reads the live registry values, whatever the host version' {
        $info = Get-OSBuildInfo
        $info.CurrentBuild | Should -BeGreaterThan 0
        $info.Architecture | Should -BeIn @('AMD64', 'ARM64')
        $info.PSObject.Properties.Name | Should -Contain 'EditionID'
        $info.PSObject.Properties.Name | Should -Contain 'InstallationType'
    }
}
