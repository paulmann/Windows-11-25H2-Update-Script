@echo off
REM ========================================================================
REM Windows 11 25H2 Update Script - Simple BAT version
REM Author: Mikhail Deynekin (mid1977@gmail.com)
REM Website: https://deynekin.com
REM ========================================================================

setlocal enabledelayedexpansion

REM Constants
set TARGET_BUILD=26200
set TARGET_UBR=6718
set MINIMUM_BUILD=26100
set MINIMUM_UBR=5074

REM Download URLs
set URL_X64=https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/fa84cc49-18b2-4c26-b389-90c96e6ae0d2/public/windows11.0-kb5054156-x64_a0c1638cbcf4cf33dbe9a5bef69db374b4786974.msu
set URL_ARM64=https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/78b265e5-83a8-4e0a-9060-efbe0bac5bde/public/windows11.0-kb5054156-arm64_3d5c91aaeb08a87e0717f263ad4a61186746e465.msu

REM File paths
set TEMP_FILE=%TEMP%\kb5054156.msu

echo Windows 11 25H2 Update Script Started
echo ====================================

REM Check administrator privileges
echo Checking administrator privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Administrator privileges required!
    echo Please run Command Prompt as Administrator
    pause
    exit /b 1
)
echo Administrator privileges confirmed

REM Determine architecture
echo Determining system architecture...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set ARCH=AMD64
    set DOWNLOAD_URL=%URL_X64%
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set ARCH=ARM64
    set DOWNLOAD_URL=%URL_ARM64%
) else (
    echo ERROR: Unsupported architecture: %PROCESSOR_ARCHITECTURE%
    pause
    exit /b 1
)
echo Architecture: %ARCH%

REM Get current Windows version
echo Getting system information...
for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| find "CurrentBuild"') do set CURRENT_BUILD=%%i
for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2^>nul ^| find "UBR"') do set CURRENT_UBR=%%i

echo Current OS Build: %CURRENT_BUILD%.%CURRENT_UBR%

REM Check if update needed
if %CURRENT_BUILD% gtr %TARGET_BUILD% (
    echo System already has newer version. Update not required.
    pause
    exit /b 0
)

if %CURRENT_BUILD% equ %TARGET_BUILD% (
    if %CURRENT_UBR% geq %TARGET_UBR% (
        echo System is already on target version. Update not required.
        pause
        exit /b 0
    )
)

REM Check minimum requirements
if %CURRENT_BUILD% lss %MINIMUM_BUILD% (
    echo ERROR: This script requires Windows 11 24H2 or newer
    echo Please update via Windows Update first
    pause
    exit /b 1
)

REM Remove existing temp file
if exist "%TEMP_FILE%" del "%TEMP_FILE%" /f /q

REM Download update
echo Downloading update package...
echo This may take several minutes...

curl --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Using curl for download...
    curl -L -o "%TEMP_FILE%" "%DOWNLOAD_URL%" --progress-bar
    if %errorlevel% neq 0 (
        echo Curl download failed, trying PowerShell...
        powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_FILE%'"
    )
) else (
    echo Using PowerShell for download...
    powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_FILE%'"
)

if not exist "%TEMP_FILE%" (
    echo ERROR: Download failed
    pause
    exit /b 1
)

REM Check file size
for %%F in ("%TEMP_FILE%") do set FILE_SIZE=%%~zF
if %FILE_SIZE% lss 100000 (
    echo ERROR: Downloaded file too small, likely corrupted
    del "%TEMP_FILE%" /f /q
    pause
    exit /b 1
)

echo Download completed. File size: %FILE_SIZE% bytes

REM Install update
echo Installing update...
echo This will take several minutes. Please wait...
wusa.exe "%TEMP_FILE%" /quiet /norestart

set RESULT=%errorlevel%

REM Clean up
if exist "%TEMP_FILE%" del "%TEMP_FILE%" /f /q

REM Handle result
if %RESULT% equ 0 (
    echo Installation completed successfully!
) else if %RESULT% equ 3010 (
    echo Installation completed successfully!
    echo Reboot required to complete installation.
    set /p CHOICE="Reboot now? (Y/N): "
    if /i "!CHOICE!"=="Y" shutdown /r /t 10
) else if %RESULT% equ 2359302 (
    echo Update not applicable - may already be installed
) else (
    echo Installation failed with error code: %RESULT%
)

echo.
echo Script completed.
pause
exit /b %RESULT%
