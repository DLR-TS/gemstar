#!/usr/bin/env bash
# Copyright (c) 2026 DLR e.V.
#
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# ini-to-experience-headless.sh - writes the experience a scenario ini needs, from a terminal.
# Runs Content/Python/ini_to_experience.py in a headless Unreal Editor and prints only its lines.
#
# Usage:
#   Scripts/ini-to-experience-headless.sh <ini> [--name <asset>] [--force] [--dry-run]
#     <ini>      scenario ini, relative to the project, required, a headless editor has no open map
#     --name     asset name, default: DA_<ini file name>
#     --force    write even when there are problems
#     --dry-run  only print the features and problems, write nothing
#
# Examples:
#   Scripts/ini-to-experience-headless.sh Simulation/DefaultGemstar.ini --dry-run
#       ue_sumo_feature              [sumo]; [vehicles] input=sumo; [visualizer] traceinput=sumo
#       ...
#       ue_weather_effect_feature    [lidar:sensor1] weatherinput=weather
#       Dry run - nothing written.
#   Scripts/ini-to-experience-headless.sh Simulation/DefaultGemstar.ini
#       writes /Game/Experiences/Generated/DA_DefaultGemstar
#   Scripts/ini-to-experience-headless.sh Simulation/DefaultGemstar.ini --name DA_Main
#       writes /Game/Experiences/Generated/DA_Main
#   Scripts/ini-to-experience-headless.sh Plugins/GameFeatures/ue_lidar_feature/Resources/GemstarLidarTest.ini
#       ...
#       Error: [visualizer] mount=SensorPlatform_1: no section defines SensorPlatform_1
#       Error: Not written: fix the problems above, or pass --force.
#       exit code 1, add --force to write its 5 features anyway
#   UE_ROOT=<engine folder> Scripts/ini-to-experience-headless.sh Simulation/DefaultGemstar.ini
#       uses that engine instead of searching for one
#   docker exec gemstar-unreal-builder /workspace/Scripts/ini-to-experience-headless.sh Simulation/DefaultGemstar.ini
#       the same on Linux, inside the container that Scripts/build-project-in-docker.sh starts
#
# Runs on macOS and Linux. Needs a built project and a closed Unreal Editor, each run starts the editor
# headless (about a minute). The engine is UE_ROOT, else a folder named UnrealEngine up to four levels
# above the project, else /home/ue4/UnrealEngine, the engine of the repo's Linux containers.
# Exit code: 0 fine, 1 the script logged an error, 2 no ini given.

[ $# -gt 0 ] || { echo "usage: $0 <ini> [--name <asset>] [--force] [--dry-run]" >&2; exit 2; }
root="$(cd "$(dirname "$0")/.." && pwd)"
project="$root/GEMSTAR.uproject"
script="$root/Scripts/ini_to_experience.py"
[ -f "$script" ] || { echo "Not found: $script" >&2; exit 1; }

# The engine: UE_ROOT, else a folder named UnrealEngine up to four levels above the project,
# else the engine of the repo's Linux containers (Scripts/*-in-docker.sh)
engine="${UE_ROOT:-}"
dir="$root"
for _ in 1 2 3 4; do
  [ -n "$engine" ] && sdf
  dir="$(dirname "$dir")"
  [ -d "$dir/UnrealEngine/Engine" ] && engine="$dir/UnrealEngine"
done
[ -z "$engine" ] && [ -d /home/ue4/UnrealEngine/Engine ] && engine=/home/ue4/UnrealEngine
[ "$(uname)" = Darwin ] && platform=Mac || platform=Linux
editor="$engine/Engine/Binaries/$platform/UnrealEditor-Cmd"
[ -x "$editor" ] || editor="$engine/Engine/Binaries/$platform/UnrealEditor"

[ -x "$editor" ] || { echo "Unreal Editor not found: set UE_ROOT to the engine folder" >&2; exit 1; }
pgrep -x UnrealEditor > /dev/null 2>&1 && { echo "Close the Unreal Editor first" >&2; exit 1; }

# Only the script's own lines: those between the commandlet's start and end messages
"$editor" "$project" -run=pythonscript -script="$script $*" \
  -unattended -nosplash -nop4 -FullStdOutLogOutput 2>&1 |
  awk '/Running Python script/ {on = 1; next}
       /LogPythonScriptCommandlet/ {on = 0}
       on && sub(/^.*LogPython: /, "") {print; fflush()}'
exit "${PIPESTATUS[0]}"
