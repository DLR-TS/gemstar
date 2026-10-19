<#
.LICENSE
Copyright (c) 2026 DLR e.V.

This program and the accompanying materials are made
available under the terms of the Eclipse Public License 2.0
which is available at https://www.eclipse.org/legal/epl-2.0/

SPDX-License-Identifier: EPL-2.0

.SYNOPSIS
Writes the experience a scenario ini needs, from a terminal.

.DESCRIPTION
Runs Content/Python/ini_to_experience.py in a headless Unreal Editor and prints only its lines.

  Scripts\ini-to-experience-headless.ps1 <ini> [--name <asset>] [--force] [--dry-run]
    <ini>      scenario ini, relative to the project, required, a headless editor has no open map
    --name     asset name, default: DA_<ini file name>
    --force    write even when there are problems
    --dry-run  only print the features and problems, write nothing

Needs a built project and a closed Unreal Editor, each run starts the editor headless (about a minute).
The engine is UE_ROOT, else a folder named UnrealEngine up to four levels above the project, else the
Epic Games Launcher install of the project's engine version.
Exit code: 0 fine, 1 the script logged an error, 2 no ini given.

.EXAMPLE
$env:UE_ROOT="<absolute_path>\\unreal\\engines\\ue_5.8"
Scripts\ini-to-experience-headless.ps1 Simulation/DefaultGemstar.ini --dry-run

Prints the 8 features with their reasons, then "Dry run - nothing written":
  ue_sumo_feature              [sumo]; [vehicles] input=sumo; [visualizer] traceinput=sumo
  ...
  ue_weather_effect_feature    [lidar:sensor1] weatherinput=weather
  Dry run - nothing written.

.EXAMPLE
Scripts\ini-to-experience-headless.ps1 Simulation/DefaultGemstar.ini

Writes /Game/Experiences/Generated/DA_DefaultGemstar.

.EXAMPLE
Scripts\ini-to-experience-headless.ps1 Simulation/DefaultGemstar.ini --name DA_Main

Writes /Game/Experiences/Generated/DA_Main.

.EXAMPLE
Scripts\ini-to-experience-headless.ps1 Plugins/GameFeatures/ue_lidar_feature/Resources/GemstarLidarTest.ini

Prints its features and two mount problems, then "Error: Not written: fix the problems above, or pass
--force." with exit code 1. Add --force to write its 5 features anyway.

.EXAMPLE
$env:UE_ROOT = "<engine folder>"; Scripts\ini-to-experience-headless.ps1 Simulation/DefaultGemstar.ini

Uses that engine instead of searching for one.
#>
$ErrorActionPreference = "Stop"
function Fail([string]$Message, [int]$Code) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

if ($args.Count -eq 0) {
    Fail "usage: ini-to-experience-headless.ps1 <ini> [--name <asset>] [--force] [--dry-run]" 2
}
$root = (Resolve-Path "$PSScriptRoot/..").Path
$project = Join-Path $root "GEMSTAR.uproject"
$pythonScript = Join-Path $root "Scripts/ini_to_experience.py"
if (-not (Test-Path $pythonScript)) { Fail "Not found: $pythonScript" 1 }

# The engine: UE_ROOT, else a folder named UnrealEngine up to four levels above the project,
# else the Epic Games Launcher install of the project's engine version
$engine = $env:UE_ROOT
$dir = $root
for ($i = 0; $i -lt 4 -and -not $engine; $i++) {
    $dir = Split-Path $dir
    if (-not $dir) { break }
    if (Test-Path (Join-Path $dir "UnrealEngine/Engine")) { $engine = Join-Path $dir "UnrealEngine" }
}
if (-not $engine -and $env:ProgramFiles) {
    $version = (Get-Content $project -Raw | ConvertFrom-Json).EngineAssociation
    $engine = Join-Path $env:ProgramFiles "Epic Games/UE_$version"
}
if (-not $engine) { Fail "Unreal Engine not found: set UE_ROOT to the engine folder" 1 }
$platform = if ($IsMacOS) { "Mac" } elseif ($IsLinux) { "Linux" } else { "Win64" }
$editor = Join-Path $engine "Engine/Binaries/$platform/UnrealEditor-Cmd"
if ($platform -eq "Win64") { $editor += ".exe" }
if (-not (Test-Path $editor)) { Fail "Not found: $editor - set UE_ROOT to the engine folder" 1 }
if (Get-Process -Name UnrealEditor -ErrorAction SilentlyContinue) { Fail "Close the Unreal Editor first" 1 }

# One raw argument string, so that -script="..." reaches the editor with its quotes. The script's lines
# come from the log file: on Windows the editor writes its console with WriteConsole, never to a pipe
$log = Join-Path ([IO.Path]::GetTempPath()) "ini-to-experience-$PID.log"
$start = New-Object System.Diagnostics.ProcessStartInfo $editor
$start.Arguments = "`"$project`" -run=pythonscript -script=`"$pythonScript $args`" " +
                   "-unattended -nosplash -nop4 -abslog=`"$log`""
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
Write-Host "Running the editor headless, about a minute..."
$process = [System.Diagnostics.Process]::Start($start)
$null = $process.StandardOutput.ReadToEnd()
$process.WaitForExit()
if (-not (Test-Path $log)) { Fail "The editor wrote no log, exit code $($process.ExitCode)" 1 }

# Only the script's own lines: those between the commandlet's start and end messages
$on = $false
foreach ($line in Get-Content $log) {
    if ($line -match "Running Python script") { $on = $true }
    elseif ($line -match "LogPythonScriptCommandlet") { $on = $false }
    elseif ($on -and $line -match "LogPython: (.*)$") { $Matches[1] }
}
Remove-Item $log -ErrorAction SilentlyContinue
exit $process.ExitCode
