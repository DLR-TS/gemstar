:: Copyright (c) 2026 DLR e.V.
::
:: This program and the accompanying materials are made
:: available under the terms of the Eclipse Public License 2.0
:: which is available at https://www.eclipse.org/legal/epl-2.0/
::
:: SPDX-License-Identifier: EPL-2.0"
@echo off
setlocal enabledelayedexpansion

:: === Set script directory here ===
set SCRIPT_DIR=%~dp0

:: === Default Unreal Engine path ===
set "DEFAULT_UE_PATH=C:\Program Files\Epic Games\UE_5.8"

:: === Set local cache file for Unreal Engine path ===
set "LOCATION_FILE=%~dp0UnrealLocation.json"

:: === Set dotnet path here (if not globally available) ===
set "DOTNET_PATH=C:\Program Files\dotnet\dotnet.exe"

:: === Save current directory ===
set "PROJECT_DIR=%SCRIPT_DIR%"

cd /d %PROJECT_DIR%

call :FindUProject UPROJECT_PATH
call :GetEngineVersion "%UPROJECT_PATH%" UE_VERSION
call :GetEnginePath "%UE_VERSION%" UE_PATH

if not defined UE_PATH (
    echo Engine path could not be resolved. Terminating script execution.
    exit /b 1
)

echo ============================================
echo GEMSTAR Cleanup Script
echo Project directory: %PROJECT_DIR%
echo .uproject file: %UPROJECT_PATH%
echo Unreal Engine Version: %UE_VERSION%
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

exit /b 0


:: ==============================================================================
:: FUNCTION: FindUProject
:: ==============================================================================
:FindUProject <out-var>
echo(
echo [DEBUG] FindUProject
set "%~1="
for %%F in ("%PROJECT_DIR%*.uproject") do set "%~1=%%F"
goto :eof

:: ==============================================================================
:: FUNCTION: GetEngineVersion
:: ==============================================================================
:GetEngineVersion <uproject-file> <out-var>
setlocal enabledelayedexpansion
echo(
echo [DEBUG] GetEngineVersion: file="%~1"
set "ASSOC="
for /f "tokens=2 delims=:" %%A in ('findstr /i "EngineAssociation" "%~1"') do set "ASSOC=%%A"

set ASSOC=!ASSOC:"=! 
set "ASSOC=!ASSOC:,=!"  

for /f "tokens=* delims= " %%A in ("!ASSOC!") do set "ASSOC=%%A"
:strip_trailing_1
if "!ASSOC:~-1!"==" " (
   set "ASSOC=!ASSOC:~0,-1!"
   goto :strip_trailing_1
)

echo [DEBUG] EngineAssociation=[!ASSOC!]
echo(

endlocal & set "%~2=%ASSOC%"
goto :eof

:: ==============================================================================
:: FUNCTION: GetEnginePath
:: ==============================================================================
:GetEnginePath
setlocal enabledelayedexpansion

echo(
echo [STEP 1] ENTERING ENGINE PATH HANDLING
echo(

echo [DEBUG] GetEnginePath: VERSION="%~1"

set "VERSION=%~1"
set "VERSION=!VERSION: =!"
set "SEARCH=ue_!VERSION!"

set "RESULT="
set "UE_PATH="

echo(
echo [DEBUG] VERSION=[!VERSION!]
echo [DEBUG] SEARCH =[!SEARCH!]
echo [DEBUG] LOCATION_FILE=[%LOCATION_FILE%]
echo(



echo(
echo [STEP 2] CHECK CACHE FILE
echo(

echo [DEBUG] LOCATION_FILE=[%LOCATION_FILE%]
if defined LOCATION_FILE (
    if exist "%LOCATION_FILE%" (
        echo [DEBUG] Cache file exists.
    ) else (
        echo [DEBUG] Cache file does not exist.
    )
) else (
    echo [ERROR] LOCATION_FILE variable is not defined.
)
echo [DEBUG] DEFAULT_UE_PATH=[%DEFAULT_UE_PATH%]
if defined DEFAULT_UE_PATH (
        echo [DEBUG] DEFAULT_UE_PATH is defined
        if exist "!DEFAULT_UE_PATH!\Engine" (
            echo [DEBUG] DEFAULT_UE_PATH Engine exists
            set "UE_PATH=!DEFAULT_UE_PATH!"
            goto :Found
        ) else (
            echo [DEBUG] DEFAULT_UE_PATH Engine does NOT exist
        )
    ) else (
        echo [DEBUG] DEFAULT_UE_PATH is NOT defined
    )
)
echo [DEBUG] Passed cache/default path section

if exist "%LOCATION_FILE%" (
    echo [DEBUG] Cache file exists.
    for /f "tokens=1,* delims=: " %%I in ('type "%LOCATION_FILE%" 2^>nul') do (
        set "KEY=%%~I"
        set "VAL=%%~J"
        set "KEY=!KEY:"=!"        
        if "!KEY!"=="!SEARCH!" (
            echo [DEBUG] Cache file exists.
            set "ORIG_VAL=!VAL!"
            ::set "VAL=!VAL: =!"
            set "VAL=!VAL:"=!"
            set "VAL=!VAL:,=!"
            set "VAL=!VAL:\\=\!"
            set "UE_PATH=!VAL!"

            for /f "tokens=* delims= " %%A in ("!UE_PATH!") do set "UE_PATH=%%A"
            :strip_trailing_2
            if "!UE_PATH:~-1!"==" " (
                set "UE_PATH=!UE_PATH:~0,-1!"
                goto :strip_trailing_2
            )

            echo(
            echo ===== LOCAL CACHE FILE MATCH ===============
            echo Cache key  : [!KEY!]
            echo Cache value: [!ORIG_VAL!]
            echo Cache path : [!UE_PATH!]
            echo ============================================
            echo(

            echo Cache path : [!UE_PATH!]
            if exist "!UE_PATH!\Engine" ( 
                echo [DEBUG] Cached path is valid. 
                goto :EndFunction
            ) else ( 
                echo [DEBUG] Cached path is INVALID.
                goto :SearchInRegistry
            )
        )
    )
) else (
    echo [DEBUG] Cache file does not exist.

    if exist "!DEFAULT_UE_PATH!\Engine" (
        echo [DEBUG] Using DEFAULT_UE_PATH.
        set "UE_PATH=!DEFAULT_UE_PATH!"
        goto :Found
    )
)

:SearchInRegistry
echo(
echo Engine folder is not cached. Starting Windows Registry search for !SEARCH!...
echo Please wait while the Windows Registry is scanned. This may take a few minutes. Please do not close the application.
echo(

echo(
echo [STEP 3] SEARCH IN WINDOWS REGISTRY
echo(

for %%R in (HKEY_CLASSES_ROOT HKEY_CURRENT_USER HKEY_LOCAL_MACHINE) do (
    echo [DEBUG] Searching in: %%R
	for /f "tokens=1,2,*" %%A in ('reg query %%R /f "!SEARCH!" /s 2^>nul ^| findstr /i "REG_SZ"') do (
		if not defined RESULT (
			set "VAR_A=%%A"
            set "VAR_C=%%C"
            echo [DEBUG] VAR_A=[!VAR_A!]
            echo [DEBUG] VAR_C=[!VAR_C!]
			set "MATCH="
			echo !VAR_A! | findstr /i "!SEARCH!" >nul && set "MATCH=1"
			echo !VAR_C! | findstr /i "!SEARCH!" >nul && set "MATCH=3"

			if defined MATCH (
                if "!MATCH!"=="1" set "RESULT=%%A"
                if "!MATCH!"=="3" set "RESULT=%%C"

                echo(
                echo ===== REGISTRY MATCH ===============
                echo MATCH=!MATCH!
                echo VAR_A=[!VAR_A!]
                echo VAR_C=[!VAR_C!]
                echo RESULT=[!RESULT!]
                echo ====================================
                echo(
                echo Engine path registry entry: !RESULT!
			    goto :Found
			)
		)
	)
)
echo(
echo [STEP 4] REGISTRY FAILED
echo(
echo Unreal Engine !VERSION! was not found in Windows Registry or is invalid.
set /p "CHOICE=No valid path found. Would you like to search local drives? (Y/N): "
echo [DEBUG] CHOICE=[!CHOICE!]
if /i "!CHOICE!"=="Y" goto :SearchDrives
if /i "!CHOICE!"=="J" goto :SearchDrives
echo Search canceled. Exiting script.
goto :StopScript

:SearchDrives
echo(
echo [STEP 5] SEARCH IN LOCAL DRIVES
echo(

echo Searching local drives for an Unreal Engine !VERSION! folder matching !SEARCH!...

for /f "tokens=1" %%D in ('wmic logicaldisk get deviceid ^| findstr ":"') do (
    echo [DEBUG] DRIVE=[%%D]
    if exist "%%D\" (
        for /f "delims=" %%P in ('dir "%%D\*!SEARCH!*" /s /b /ad 2^>nul') do (
            if exist "%%P\Engine" (
                set "UE_PATH=%%P"
                echo [DEBUG] VALID ENGINE FOUND
                echo Unreal Engine !VERSION! folder: !UE_PATH!
                goto :Found
            )
        )
    )
)

if not defined UE_PATH (
    echo [ERROR] No engine path found.
    echo Engine path "%UE_PATH%" is invalid or empty.
    goto :StopScript
)
goto :EndFunction

:Found
echo(
echo [STEP 6]  RESOLVE PATH
echo(
echo RESULT      = [!RESULT!]
echo UE_PATH     = [!UE_PATH!]
if not defined UE_PATH (
    echo [DEBUG] UE_PATH="!UE_PATH!" not yet defined. 
    echo [DEBUG] RESULT=[!RESULT!]
    set "TMP_RESULT=!RESULT:\Engine\=|!"
    echo [DEBUG] TMP_RESULT=[!TMP_RESULT!]
    for /f "delims=|" %%A in ("!TMP_RESULT!") do (
        set "UE_PATH=%%A"
    )

) else (
    echo [DEBUG] UE_PATH="!UE_PATH!" is set.
    set "TMP_RESULT=!RESULT:\Engine\=|!"

    call set "prefix=%%TMP_RESULT:*!VERSION!=%%"
    call set "TMP_RESULT=%%TMP_RESULT:!prefix!=%%"

    echo [DEBUG] TMP_RESULT=[!TMP_RESULT!]
    if exist "!TMP_RESULT!" (
        echo [DEBUG] UE_PATH="!UE_PATH!" is INVALID. 
        set "UE_PATH=!TMP_RESULT!" 
        for /f "tokens=* delims= " %%A in ("!UE_PATH!") do set "UE_PATH=%%A"
        :strip_trailing_3
        if "!UE_PATH:~-1!"==" " (
            set "UE_PATH=!UE_PATH:~0,-1!"
            goto :strip_trailing_3
        )
        echo [DEBUG] UE_PATH="!UE_PATH!" is overwritten.
    ) else (
        echo [DEBUG] RESULT="!RESULT!" is INVALID. 
    )
)

echo(
echo ===== DEBUG ========================
echo SEARCH      = [!SEARCH!]
echo VERSION     = [!VERSION!]
echo RESULT      = [!RESULT!]
echo UE_PATH     = [!UE_PATH!]
echo ENGINE_PATH = [!UE_PATH!\Engine]
echo LOCATION    = [%LOCATION_FILE%]
echo ====================================
echo(

echo Selected engine path: !UE_PATH!
set "ENGINE_PATH=!UE_PATH!\Engine"
echo [DEBUG] ENGINE_PATH=[!ENGINE_PATH!]

echo(
echo [STEP 7] TEST IF ENGINE PATH EXIST
echo(
echo ===== CHECK PATH ===================
echo Checking: "!ENGINE_PATH!"
echo(
if not exist "!ENGINE_PATH!" (
    echo Engine path "%ENGINE_PATH%" does not exist.
    goto :StopScript
) else (
    echo Path "%ENGINE_PATH%" exists
)
echo ====================================
echo(

echo(
echo [STEP 8] WRITE CACHE FILE
echo(
set "CLEAN_UE_PATH=!UE_PATH:\=\\!"
echo [DEBUG] CLEAN_UE_PATH=[!CLEAN_UE_PATH!]
echo [DEBUG] {
echo [DEBUG]   "!SEARCH!":  "!CLEAN_UE_PATH!",
echo [DEBUG] }
echo { > "%LOCATION_FILE%"
echo   "!SEARCH!":  "!CLEAN_UE_PATH!",  >> "%LOCATION_FILE%"
echo } >> "%LOCATION_FILE%"
if exist "%LOCATION_FILE%" ( 
    echo [DEBUG] cache file is written. 
) else ( 
    echo [ERROR] cache file could not be written.
)

:EndFunction
echo(
echo [STEP 9] END WITH SUCCESS
echo(
endlocal & set "%~2=%UE_PATH%"
goto :eof

:StopScript
echo(
echo [STEP 10] END WITH FAILURE
echo(
echo [DEBUG] UE_PATH=[!UE_PATH!]
echo [DEBUG] RESULT=[!RESULT!]
set "UE_PATH="
endlocal
goto :eof

