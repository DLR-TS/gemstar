# Scenario with SUMO

## Step 1

Enable sumo configuration and set scenario and disable esmini in Simulation/DefaultGEMSTAR.ini

```ini
;[esmini]
;Debug=true
;relative path in plugin
;Path=Resources/simple-left-turn/scenario_scenario1_0.xosc

[sumo]
;Debug=true
Parameters="-c Resources/simple-intersection/simple-intersection.sumocfg"
```

## Step 2

Change input for other modules to sumo.

```ini
[vehicles]
Input=[sumo]
VehicleDataConfiguration="./Config/VehicleDataConfig.json"

[visualizer]
;vehicle source for trace visualisation
TraceInput=[sumo]
```

## Step 3

Adapt VehicleDataConfig.json or create a custom file and change Simulation/DefaultGEMSTAR.ini (see Step 2)

```json
[
    {
		"Name": "ego",
		"VehicleAsset": "BP_Simple_Car",
		"OSI_BB_Center_To_Rear": "(X=0.000000,Y=0.000000,Z=0.000000)",
		"OSI_BB_Center_To_Front": "(X=0.000000,Y=0.000000,Z=0.000000)",
		"OSI_Ground_Clearance": 0.20000000000000001,
		"OSI_Number_Wheels": 4,
		"OSI_Bounding_Box": "(X=5.000000,Y=2.000000,Z=1.500000)"
	}
]
```

SUMO .rou.xml Example
```xml
    <vType id="car" guiShape="passenger"/>    
    <vehicle id="ego" type="car" route="route0" depart="0" departLane="best"/>
```

### Matching priority

1. SUMO vehicle.id = Name
2. SUMO vehicle.id = VehicleAsset
3. SUMO vType.id = Name
4. SUMO vType.id = VehicleAsset
5. Minimal bounding box difference

Use the name matching for special vehicles, like ego in a scenario.\
Use type matching for generic sourrounding traffic.\
Use minimal bounding box difference for more variaty.

## Step 4

If running in the editor, check if GEMSTARRoot Boolean: useSUMO = true
