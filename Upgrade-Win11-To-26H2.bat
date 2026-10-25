@echo off
REM ========================================================================
REM Windows 11 26H2 Update Script - Simple BAT version
REM Enables Windows 11, version 26H2 with the official enablement package
REM KB5121794 on Windows 11 24H2 or 25H2 hosts.
REM Author: Mikhail Deynekin (m@deynekin.com)
REM KB article: https://support.microsoft.com/help/5121794
REM ========================================================================

setlocal enabledelayedexpansion

REM Target and prerequisite builds
set "TARGET_VERSION=26H2"
set "TARGET_BUILD=26300"
set "MINIMUM_BUILD=26100"
set "MINIMUM_UBR_24H2=9546"
set "MINIMUM_UBR_25H2=9550"
set "OTHER_BRANCH_BUILD=28000"

REM Enablement package (Microsoft delivery CDN). A real package is about 174 KB.
set "URL_X64=https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/94520a88-858f-4832-a57d-7211f6d84a4e/public/Windows11.0-KB5121794-x64_5e20a3cce48d6611b16bdec42b07167f5456586a.msu"
set "URL_ARM64=https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/9d8dc3d0-9cbf-4eb1-9411-722e3e6a19b3/public/Windows11.0-KB5121794-arm64_77a76caf2d362bb293a4d18058388f2717365abe.msu"
set "SHA1_X64=5e20a3cce48d6611b16bdec42b07167f5456586a"
set "SHA1_ARM64=77a76caf2d362bb293a4d18058388f2717365abe"

REM Retry and sanity limits
set "RETRY_COUNT=3"
set "RETRY_DELAY_SEC=5"
set "MIN_PACKAGE_BYTES=100000"

set "TARGET_LABEL=Windows 11 %TARGET_VERSION%"
set "PREFLIGHT=0"
if /i "%~1"=="/whatif" set "PREFLIGHT=1"
if /i "%~1"=="-whatif" set "PREFLIGHT=1"

echo Windows 11 %TARGET_VERSION% Update Script Started
echo ==============================================
echo.

REM ---- Administrator privileges ------------------------------------------
echo Checking administrator privileges...
net session >nul 2>&1
if errorlevel 1 goto no_admin
echo Administrator privileges confirmed

REM ---- Architecture ------------------------------------------------------
echo Determining system architecture...
set "ARCH="
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=AMD64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=ARM64"
if not defined ARCH if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH=AMD64"
if not defined ARCH if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=ARM64"
if not defined ARCH goto bad_arch

if /i "%ARCH%"=="AMD64" (
    set "DOWNLOAD_URL=%URL_X64%"
    set "EXPECTED_SHA1=%SHA1_X64%"
) else (
    set "DOWNLOAD_URL=%URL_ARM64%"
    set "EXPECTED_SHA1=%SHA1_ARM64%"
)
set "TEMP_FILE=%TEMP%\kb5121794_%ARCH%.msu"
echo Architecture: %ARCH%

REM ---- Current build and edition ----------------------------------------
echo Getting system information...
set "REG_KEY=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
for /f "tokens=3" %%i in ('reg query "%REG_KEY%" /v CurrentBuild 2^>nul ^| findstr /i "CurrentBuild"') do set "CURRENT_BUILD=%%i"
for /f "tokens=3" %%i in ('reg query "%REG_KEY%" /v UBR 2^>nul ^| findstr /i "UBR"') do set "UBR_HEX=%%i"
for /f "tokens=3" %%i in ('reg query "%REG_KEY%" /v DisplayVersion 2^>nul ^| findstr /i "DisplayVersion"') do set "DISPLAY_VERSION=%%i"
for /f "tokens=3" %%i in ('reg query "%REG_KEY%" /v EditionID 2^>nul ^| findstr /i "EditionID"') do set "EDITION_ID=%%i"
for /f "tokens=3" %%i in ('reg query "%REG_KEY%" /v InstallationType 2^>nul ^| findstr /i "InstallationType"') do set "INSTALL_TYPE=%%i"
if not defined CURRENT_BUILD goto bad_registry
if not defined UBR_HEX set "UBR_HEX=0x0"
set /a BUILD_NUM=%CURRENT_BUILD%
set /a CURRENT_UBR=%UBR_HEX%

echo Current version: %DISPLAY_VERSION% (build %BUILD_NUM%.%CURRENT_UBR%, edition %EDITION_ID%)
echo.

REM ---- 26H1 is a separate branch, not an upgrade path --------------------
if %BUILD_NUM% geq %OTHER_BRANCH_BUILD% goto other_branch

REM ---- Already on target? Any build 26300.x is 26H2 ----------------------
if %BUILD_NUM% geq %TARGET_BUILD% goto already_target

REM ---- Edition gate ------------------------------------------------------
if /i "%INSTALL_TYPE%"=="Server" goto bad_edition
if /i "%EDITION_ID%"=="EnterpriseS" goto bad_edition
if /i "%EDITION_ID%"=="IoTEnterpriseS" goto bad_edition
if /i "%EDITION_ID%"=="EnterpriseSN" goto bad_edition
if /i "%EDITION_ID%"=="IoTEnterpriseSN" goto bad_edition

REM ---- Prerequisite (KB5124010 or later) ---------------------------------
if %BUILD_NUM% lss %MINIMUM_BUILD% goto too_old
set "MIN_UBR=%MINIMUM_UBR_24H2%"
if %BUILD_NUM% equ 26200 set "MIN_UBR=%MINIMUM_UBR_25H2%"
if %CURRENT_UBR% lss %MIN_UBR% goto too_old

REM ---- Plan --------------------------------------------------------------
echo Plan: install KB5121794 (%ARCH%) and restart once.
echo Source: %DOWNLOAD_URL%
echo Target: %TARGET_LABEL%, build %TARGET_BUILD%.x
echo.

if "%PREFLIGHT%"=="1" goto preflight_only

REM ---- Download with retries (curl, then PowerShell, per attempt) --------
set /a ATTEMPT=0
set "PS_EXE=powershell"
where pwsh.exe >nul 2>&1
if not errorlevel 1 set "PS_EXE=pwsh"

:download
set /a ATTEMPT+=1
echo Download attempt !ATTEMPT! of %RETRY_COUNT%...
if exist "%TEMP_FILE%" del /f /q "%TEMP_FILE%" >nul 2>&1
set "DL_OK=0"

where curl.exe >nul 2>&1
if errorlevel 1 goto dl_powershell
echo Using curl for download...
curl.exe -L --fail --max-time 300 -o "%TEMP_FILE%" "%DOWNLOAD_URL%" --progress-bar
call :check_download
if "%DL_OK%"=="1" goto downloaded
echo curl failed, trying %PS_EXE%...

:dl_powershell
echo Using %PS_EXE% for download...
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_FILE%' -UseBasicParsing"
call :check_download
if "%DL_OK%"=="1" goto downloaded

:download_failed
echo Download attempt !ATTEMPT! failed.
if exist "%TEMP_FILE%" del /f /q "%TEMP_FILE%" >nul 2>&1
if !ATTEMPT! geq %RETRY_COUNT% goto download_gave_up
echo Retrying in %RETRY_DELAY_SEC% seconds...
call :wait_retry
goto download

:downloaded
echo Download completed and verified. File size: !FILE_SIZE! bytes

REM ---- Install -----------------------------------------------------------
echo.
echo Installing update...
echo This will take a few minutes. Please wait...
wusa.exe "%TEMP_FILE%" /quiet /norestart
set "RESULT=%errorlevel%"
if exist "%TEMP_FILE%" del /f /q "%TEMP_FILE%" >nul 2>&1

if %RESULT% equ 0 goto install_ok
if %RESULT% equ 3010 goto install_ok
if %RESULT% equ 2359302 goto not_applicable
if %RESULT% equ 2359303 goto another_install
goto install_failed

REM ---- Subroutines -------------------------------------------------------
:check_download
set "DL_OK=0"
if not exist "%TEMP_FILE%" exit /b 0
for %%F in ("%TEMP_FILE%") do set "FILE_SIZE=%%~zF"
if not defined FILE_SIZE exit /b 0
if !FILE_SIZE! lss %MIN_PACKAGE_BYTES% (
    echo Downloaded file is only !FILE_SIZE! bytes, likely an error page or a cut download.
    exit /b 0
)
call :verify_sha1
if errorlevel 1 exit /b 0
set "DL_OK=1"
exit /b 0

:verify_sha1
set "ACTUAL_SHA1="
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%TEMP_FILE%" SHA1 2^>nul') do if not defined ACTUAL_SHA1 set "ACTUAL_SHA1=%%h"
if not defined ACTUAL_SHA1 (
    echo ERROR: certutil did not return a SHA-1 hash.
    exit /b 1
)
set "ACTUAL_SHA1=!ACTUAL_SHA1: =!"
if /i not "!ACTUAL_SHA1!"=="%EXPECTED_SHA1%" (
    echo ERROR: SHA-1 mismatch.
    echo   expected: %EXPECTED_SHA1%
    echo   actual:   !ACTUAL_SHA1!
    echo The download is incomplete or was altered. Do not install it.
    exit /b 1
)
echo SHA-1 verified: !ACTUAL_SHA1!
exit /b 0

:wait_retry
REM "timeout" fails when stdin is redirected; ping is the portable pause.
timeout /t %RETRY_DELAY_SEC% /nobreak >nul 2>&1
if errorlevel 1 ping -n %RETRY_DELAY_SEC% 127.0.0.1 >nul 2>&1
exit /b 0

REM ---- Outcomes ----------------------------------------------------------
:install_ok
echo.
echo Installation completed successfully.
echo A restart is required to activate %TARGET_LABEL%.
echo After the restart CurrentBuild must be %TARGET_BUILD%; exit code 0 means "staged", not "verified".
set /p "CHOICE=Reboot now? (Y/N): "
if /i "!CHOICE!"=="Y" (
    echo Rebooting in 10 seconds. Save your work now.
    shutdown /r /t 10
) else (
    echo Reboot deferred. Restart the device manually to finish the upgrade.
)
echo.
echo Script completed.
pause
exit /b 0

:not_applicable
echo.
echo Update not applicable: wusa.exe returned 2359302.
echo The package is already installed, the host is newer than 26H2, or KB5124010 is missing.
echo Run winver and check Windows Update history for KB5121794.
echo.
pause
exit /b 1

:another_install
echo.
echo Another installation is already in progress (wusa.exe returned 2359303).
echo Wait for it to finish, then run this script again.
echo.
pause
exit /b 1

:install_failed
echo.
echo ERROR: Installation failed with exit code %RESULT%.
if "%RESULT:~0,1%"=="-" (
    echo This is a Win32 error reported as a negative decimal, for example 0x800F0823
    echo ^(prerequisites not satisfied^) or 0x80070005 ^(access denied^).
    echo Convert it with: [Convert]::ToString(%RESULT%, 16)
)
echo Common causes: KB5124010 missing, servicing stack too old, another installation running.
echo Look up the code at https://support.microsoft.com/help/5121794
echo.
pause
exit /b 1

:already_target
echo.
echo System is already on %TARGET_LABEL% or newer (build %BUILD_NUM%.%CURRENT_UBR%). Update not required.
exit /b 0

:other_branch
echo.
echo ERROR: this host runs build %BUILD_NUM% (%DISPLAY_VERSION%), which is the 26H1 branch.
echo 26H1 is a separate servicing branch for new devices and is not upgraded to 26H2 in place.
echo No action is required.
pause
exit /b 1

:bad_edition
echo.
echo ERROR: unsupported edition: %EDITION_ID% (installation type: %INSTALL_TYPE%).
echo KB5121794 does not support LTSC editions or Windows Server; only Home, Pro, Enterprise,
echo Education, Enterprise multi-session and IoT Enterprise on 24H2/25H2 are covered.
echo Do not force the package on this host.
pause
exit /b 1

:too_old
echo.
echo ERROR: the enablement package requires Windows 11 24H2 or 25H2 at build %MINIMUM_BUILD%.%MIN_UBR% or newer.
echo Install KB5124010 or a later cumulative update, restart, then run this script again.
pause
exit /b 1

:no_admin
echo ERROR: Administrator privileges required.
echo Right-click Command Prompt and select "Run as administrator".
pause
exit /b 1

:bad_arch
echo ERROR: unsupported architecture: %PROCESSOR_ARCHITECTURE%
echo Only AMD64 and ARM64 are supported.
pause
exit /b 1

:bad_registry
echo ERROR: could not read the current build from the registry.
echo Check: reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild
pause
exit /b 1

:preflight_only
echo Preflight only (/whatif): nothing was downloaded or installed.
exit /b 0

:download_gave_up
echo ERROR: failed to download the enablement package after %RETRY_COUNT% attempts.
echo Check access to catalog.sf.dl.delivery.mp.microsoft.com (port 443).
pause
exit /b 1
