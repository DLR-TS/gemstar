@echo off
setlocal enabledelayedexpansion

:: === Set script directory here ===
set SCRIPT_DIR=%~dp0

:: === Set Unreal Engine path here ===
set "UE_PATH=C:\Program Files\Epic Games\UE_5.3"

:: === Set dotnet path here (if not globally available) ===
set "DOTNET_PATH=C:\Program Files\dotnet\dotnet.exe"

:: === Save current directory ===
set "PROJECT_DIR=%SCRIPT_DIR%"

echo ============================================
echo GEMSTAR Cleanup Script
echo Project directory: %PROJECT_DIR%
echo Unreal Engine path: %UE_PATH%
echo Dotnet path: %DOTNET_PATH%
echo ============================================

:: === Delete in main directory ===
echo.
echo Deleting Binaries and Intermediate in project root...

if exist "Binaries" (
    echo Deleting: Binaries
    rd /s /q "Binaries"
)

if exist "Intermediate" (
    echo Deleting: Intermediate
    rd /s /q "Intermediate"
)

if exist "Output" (
    echo Deleting: Output
    rd /s /q "Output"
)

:: === Delete in Plugins/* ===
echo.
echo Deleting Binaries and Intermediate in Plugins/*...

for /d %%P in ("Plugins\*") do (
    if exist "%%P\Binaries" (
        echo Deleting: %%P\Binaries
        rd /s /q "%%P\Binaries"
    )
    if exist "%%P\Intermediate" (
        echo Deleting: %%P\Intermediate
        rd /s /q "%%P\Intermediate"
    )
)

:: === Delete in Plugins/GameFeatures/* ===
echo.
echo Deleting Binaries and Intermediate in Plugins/GameFeatures/*...

for /d %%P in ("Plugins\GameFeatures\*") do (
    if exist "%%P\Binaries" (
        echo Deleting: %%P\Binaries
        rd /s /q "%%P\Binaries"
    )
    if exist "%%P\Intermediate" (
        echo Deleting: %%P\Intermediate
        rd /s /q "%%P\Intermediate"
    )
)

:: === Ask if project files should be regenerated ===
echo.
set /p GEN_VS="Regenerate Visual Studio project files? (y/n): "
if /i "!GEN_VS!"=="y" (
    echo.
    echo Regenerating project files using UnrealBuildTool...

    :: Search for .uproject file in current folder
    set "UPROJECT_PATH="
    for %%F in ("%PROJECT_DIR%*.uproject") do (
        set "UPROJECT_PATH=%%F"
    )

    if defined UPROJECT_PATH (
        echo Using .uproject file: !UPROJECT_PATH!
        "%DOTNET_PATH%" "%UE_PATH%\Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll" ^
            -projectfiles -project="!UPROJECT_PATH!" -game -rocket -progress
    ) else (
        echo Error: No .uproject file found in the current directory.
    )
)

echo.
echo Done.
if /i "!GEN_VS!"=="y" (
    echo Next step: Open GEMSTAR.sln with Visual Studio 2022
)
pause
