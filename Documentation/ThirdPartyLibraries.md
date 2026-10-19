# Third Party Libraries

GEMSTAR uses precompiled libraries and other artefacts.

If submodule artefacts like in `GEMSTAR_Interfaces` the OSI/Protobuf dependencies need to recompiled in your setup, run:

On Linux:
```sh
./Scripts/build-all-dependencies.sh
```
On Windows:
```cmd
./Scripts/build-all-dependencies.bat
```

All submodules contain scripts to compile their third party dependencies.
