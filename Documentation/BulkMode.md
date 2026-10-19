# Bulk Mode

Gemstar supports a bulk mode to replay multiple scenarios in a sequence. For each scenario it loads a matching level to view the sensors in the expected environment.

# Usage
Add the follow block to your DefaultGemstar.ini to activate the feature.

```ini
[Gemstar]
BulkPath="Simulation/OpenSCENARIO"
```

When this section of the DefaultGemstar.ini file contains a BulkPath entry, Gemstar will search recursive for xosc and sumocfg files and replay them one by one. When a xosc file does not have a RoadNetwork/LogicFile/filepath this file is skipped to prevent to load a catalog file as a scenario.

For each scenario Gemstar looks for the basename of the logical network description and looks for an Unreal level with the same name, loading it and than activate every plugin that stands in the DefaultGemstar.ini file. Is no level present with a matching name the default map is selected. After the matching scenario player announce that the scenario ends the next scenario is loaded.

After the last scenario is ended, Gemstar will be closed or return to the editor mode of Unreal.
