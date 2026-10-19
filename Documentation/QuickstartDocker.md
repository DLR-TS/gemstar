# Quickstart Docker

⚠️ The docker does currently not offer GPU accelerated raytracing functionality for e.g. lidar.

## Requirements

- Linux system 
- Git **and Git LFS**
- Docker

## Setup

First set up the system to run the Unreal Engine docker container.
Setup up with this [official guide](https://dev.epicgames.com/documentation/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine).

```sh
git clone https://github.com/DLR-TS/gemstar.git
cd gemstar
git submodule update --init
```

## Run the docker development container

Start the Unreal Editor in docker.

```sh
./Scripts/start-editor-in-docker.sh
```

## Or build GEMSTAR executable with docker container

Build the executable of GEMSTAR.

```sh
./Scripts/build-project-in-docker.sh
```

⚠️ Wait for shader compilation to complete before opening extra editor windows, browser panels, or demanding viewports.
This avoids the initial Vulkan GPU-load peak.
If `VK_ERROR_DEVICE_LOST` persists, update or roll back the host GPU driver.
