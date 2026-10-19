# Quickstart Windows

## Requirements

- Windows 11
  - Git
  - Unreal Engine 5.8
  - Visual Studio 2022
    - 2026 may work

Check the Unreal Engine Guide: [Setting Up Visual Studio](https://dev.epicgames.com/documentation/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine)

## Setup source code
```cmd
git clone https://github.com/DLR-TS/gemstar.git
cd gemstar
git submodule update --init
```

## Run editor

Open GEMSTAR.uproject\
This takes some minutes.

## Or run editor from Visual Studio

Run `PostGitPull_ReGenVSFiles.bat` and press y to generate Visual Studio project files.\
⚠️ It does not run if you don't use the default UE and .NET path.
The script searches the registry and saves the findings in a file UnrealLocation.json.

Open GEMSTAR.sln\
Run in "DebugGame Editor" configuration

## Package

Package GEMSTAR for your target system.

## Run

Run the GEMSTAR simulation software.
