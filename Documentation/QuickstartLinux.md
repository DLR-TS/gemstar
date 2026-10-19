# Quickstart Linux

This guide uses the precompiled Linux Unreal Engine package (prebuilt/installed build). The commands below target Ubuntu/Debian on x86-64.

## Requirements

- Linux with a Vulkan-capable GPU and a suitable GPU driver.
- Unreal Engine **5.8**, matching `EngineAssociation` in `GEMSTAR.uproject`.
- Git **and Git LFS**
- Visual Studio Code for editing and building C++ code.
- Enough free disk space for the extracted engine, project assets and build files.

## 1. Install Git and Git LFS

Install and initialize LFS **before cloning**. See the [Git LFS documentation](https://git-lfs.com/).

```bash
sudo apt update
sudo apt install git git-lfs unzip
git lfs install
```
Check with:
```bash
git --version
git lfs version
```

## 2. Install Unreal Engine (precompiled Linux package)

Sign in with an Epic Games account on the [Unreal Engine download page](https://www.unrealengine.com/linux), select ***Linux_Unreal_Engine_5.8.3.zip*** and obtain the precompiled ZIP package. Extract it into a directory you can write to, for example:

```bash
mkdir -p "$HOME/unreal/engines/ue5_8"
# Replace the ZIP path with the package you downloaded.
unzip "$HOME/Downloads/Linux_Unreal_Engine_5.8.3.zip" -d "$HOME/unreal/engines/ue5_8"
export UE_ROOT="$HOME/unreal/engines/ue5_8"
test -x "$UE_ROOT/Engine/Binaries/Linux/UnrealEditor"
```

`UE_ROOT` must point to the directory containing `Engine`. Adjust it if the ZIP has an additional top-level directory. Set this variable again in each new terminal, or add the export to your `~/.bashrc`.

Epic's [Linux development quickstart](https://dev.epicgames.com/documentation/unreal-engine/linux-development-quickstart-for-unreal-engine) provides further installation details, but its `SetupToolchain.sh` step does not apply to this package.

The prebuilt package used here includes the compiler/toolchain and Unreal's bundled .NET runtime. **`SetupToolchain.sh` no longer exists in this package and must not be run.** Older instructions that require this script do not apply to this installed build. You do not need to compile the engine from source; GEMSTAR's C++ modules are built separately below. 

## 3. Install Visual Studio Code

Download the **Linux x64 `.deb`** package from [Visual Studio Code](https://code.visualstudio.com/download). Install the downloaded file using its actual filename:

```bash
# Replace the filename with the downloaded .deb file.
sudo apt install "$HOME/Downloads/code_<version>_amd64.deb"
code --version
code --install-extension ms-vscode.cpptools
code --install-extension ms-dotnettools.csharp
```

This installs **Visual Studio Code**. For other distributions, follow Microsoft's [Linux installation instructions](https://code.visualstudio.com/docs/setup/linux).

## 4. Clone GEMSTAR, submodules and LFS assets

Clone the DLR-TS GEMSTAR Github repository.

```bash
mkdir -p "$HOME/unreal/projects"
cd "$HOME/unreal/projects"
git clone --recurse-submodules https://github.com/DLR-TS/gemstar.git
cd gemstar
git submodule update --init --recursive
git lfs pull
git submodule foreach --recursive 'git lfs pull'
export GEMSTAR_ROOT="$PWD"
```

The feature plugins use precompiled third-party libraries. If these need rebuilding for your setup, follow [Third Party Libraries](ThirdPartyLibraries.md).

## 5. Generate the VS Code workspace and build

Run from the cloned project directory, with `UE_ROOT` set as above:

```bash
bash "$UE_ROOT/Engine/Build/BatchFiles/Linux/GenerateProjectFiles.sh" \
    -project="$GEMSTAR_ROOT/GEMSTAR.uproject" -game -engine -vscode
code "$GEMSTAR_ROOT/GEMSTAR.code-workspace"
```

Regenerate the workspace for your own installation so its engine paths match your machine. Build the editor target before launching the GUI:

```bash
bash "$UE_ROOT/Engine/Build/BatchFiles/Linux/Build.sh" \
    GEMSTAREditor Linux Development \
    -Project="$GEMSTAR_ROOT/GEMSTAR.uproject" \
    -Progress -NoEngineChanges -NoHotReloadFromIDE
```

## 6. Start the project and run the demo

```bash
"$UE_ROOT/Engine/Binaries/Linux/UnrealEditor" "$GEMSTAR_ROOT/GEMSTAR.uproject"
```

Allow the initial shader compilation to finish.
The `/ue_driving_practise_area_brunswick_map_feature/DrivingPractiseAreaBrunswickMap.umap` (should already be opened) in the editor. Click **Play** to run the demo simulation.
Its scenario is configured in `Simulation/DefaultGemstar.ini`; OSI logs are written to `Output`.

## 7. Use the simulation output

After stopping the simulation, the generated OSI trace files in the project's `Output` directory are ready for further processing and analysis. Typical filenames look like:

```text
Output/20261008T112625Z_gt_380_X_2734_GEMSTAR.osi
Output/20261008T112625Z_sv_380_X_2734_GEMSTAR.osi
```

The filename contains a UTC timestamp, the message type (`gt` = GroundTruth, `sv` = SensorView, `sd` = SensorData), the OSI version (`380` = 3.8.0), the Protobuf version field (`X` = unspecified), the number of recorded messages and the configured log name (`GEMSTAR`).
The actual names and available files depend on the simulation run and enabled logging streams in `Simulation/DefaultGemstar.ini`.

These binary `.osi` files can be loaded by tools that support OSI traces or processed using the matching OSI/Protobuf message definitions for subsequent evaluation, visualization or sensor-data analysis.
