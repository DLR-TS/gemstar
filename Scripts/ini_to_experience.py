# Copyright (c) 2026 DLR e.V.
#
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# ini_to_experience.py - writes the experience a scenario ini needs, from inside the running editor.
#
# Start it:
#   Tools > Execute Python Script, pick this file, uses the ini of the open map
#   Output Log (Cmd): py ini_to_experience.py [ini] [--name <asset>] [--force] [--dry-run]
#     ini                   scenario ini, relative to the project, default: the open map's ini
#     --name                experience asset name, default: DA_<ini file name>
#     --force               write even when there are problems
#     --dry-run             only log the features and problems, write nothing
#
# Examples:
#   py ini_to_experience.py
#       the open map's ini, e.g. Simulation/DefaultGemstar.ini -> /Game/Experiences/Generated/DA_DefaultGemstar
#   py ini_to_experience.py Simulation/DefaultGemstar.ini --dry-run
#       logs its 8 features with their reasons, writes nothing:
#         ue_sumo_feature              [sumo], [vehicles] input=sumo, [visualizer] traceinput=sumo
#         ...
#         ue_weather_effect_feature    [lidar:sensor1] weatherinput=weather
#         Dry run - nothing written.
#   py ini_to_experience.py Simulation/DefaultGemstar.ini --name DA_Main
#       writes /Game/Experiences/Generated/DA_Main
#   py ini_to_experience.py Plugins/GameFeatures/ue_lidar_feature/Resources/GemstarLidarTest.ini
#       logs "[visualizer] mount=SensorPlatform_1: no section defines SensorPlatform_1" and writes
#       nothing, add --force to write its 5 features anyway
#
#   In an ini, for features no section names:
#     [GameFeatures]
#     Features=[ue_logger_feature, ue_vru_feature]
#
# How: a section [name] or [name:instance] needs ue_<name>_feature, else the one plugin whose name
# contains name or sits inside it. Feature defaults, keys ending in Input, and Mount aliases pull in
# more features, [GameFeatures] Features=[...] adds the ones no section names.
#
# Result: the features with their reasons in the Output Log, and /Game/Experiences/Generated/DA_<ini name>,
# tagged as Scripts/ini-to-experience.py tags its assets. Nothing is written when there are problems
# (unless --force), an asset without those tags is left alone, the map is not changed.

import argparse
import hashlib
import sys
from pathlib import Path

import unreal

PROJECT = Path(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_dir()))
FEATURES = PROJECT / "Plugins" / "GameFeatures"
FOLDER = "/Game/Experiences/Generated"


def feature_plugins():
    return sorted(p.name for p in FEATURES.iterdir() if (p / f"{p.name}.uplugin").is_file())


def read_ini(path, sections):
    section = None
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = sections.setdefault(line[1:-1].lower(), {})
        elif section is not None and "=" in line and not line.startswith(";"):
            key, value = line.split("=", 1)
            section[key.strip().lower()] = value.strip().strip('"')
    return sections


def split_list(value):
    return [item.strip() for item in value.strip().strip("[]").split(",") if item.strip()]


def middle(plugin):
    return plugin.removeprefix("ue_").removesuffix("_feature")


def feature_for(name, plugins):
    # [name] or [name:instance] -> ue_<name>_feature, else the one plugin whose name contains it or sits inside it
    name = name.split(":")[0].strip().lower()
    for candidate in (name, f"ue_{name}_feature"):
        if candidate in plugins:
            return candidate
    hits = [p for p in plugins if name in middle(p) or middle(p) in name]
    return hits[0] if len(hits) == 1 else None


def references(feature, config, plugins, problems):
    # What the feature's sections ask for: producers in keys ending in input, the section behind a mount alias
    found = []
    for section, keys in config.items():
        if feature_for(section, plugins) != feature:
            continue
        for key, value in keys.items():
            if key.endswith("input"):
                found += [(producer, f"[{section}] {key}={producer}") for producer in split_list(value)]
            elif key == "mount":
                providers = [name for name, other in config.items() if value.lower() in other]
                found += [(name, f"[{section}] mount={value}") for name in providers]
                if not providers:
                    problems.append(f"[{section}] mount={value}: no section defines {value}")
    return found


def needed_features(ini, plugins):
    config = {}
    for plugin in plugins:
        defaults = FEATURES / plugin / "Config" / "FeatureDefaults.ini"
        if defaults.is_file():
            read_ini(defaults, config)
    scenario = read_ini(ini, {})
    for name, keys in scenario.items():
        config.setdefault(name, {}).update(keys)
    explicit = split_list(scenario.pop("gamefeatures", {}).get("features", ""))
    queue = [(name, "[GameFeatures]") for name in explicit] + [(name, f"[{name}]") for name in scenario]
    features, problems = {}, []
    while queue:
        name, why = queue.pop(0)
        feature = feature_for(name, plugins)
        if feature is None or (":" in name and name.lower() not in config):
            problems.append(f"{why}: nothing provides {name}")
        elif feature in features:
            features[feature].append(why)
        else:
            features[feature] = [why]
            queue += references(feature, config, plugins, problems)
    return features, problems


def write_asset(name, features, ini):
    library, path = unreal.EditorAssetLibrary, f"{FOLDER}/{name}"
    if library.does_asset_exist(path):
        asset = library.load_asset(path)
        if not library.get_metadata_tag(asset, "GemstarGeneratedFrom"):
            unreal.log_error(f"{path} was made by hand - left alone.")
            return
    else:
        factory = unreal.DataAssetFactory()
        factory.set_editor_property("data_asset_class", unreal.GemstarExperienceDefinition)
        asset = unreal.AssetToolsHelpers.get_asset_tools().create_asset(
            name, FOLDER, unreal.GemstarExperienceDefinition, factory)
    asset.set_editor_property("game_features_to_enable", features)
    library.set_metadata_tag(asset, "GemstarGeneratedFrom", ini.relative_to(PROJECT).as_posix())
    library.set_metadata_tag(asset, "GemstarIniSha256", hashlib.sha256(ini.read_bytes()).hexdigest())
    library.save_asset(path, only_if_is_dirty=False)
    if "-run=" not in unreal.SystemLibrary.get_command_line():  # a headless run has no Content Browser
        library.sync_browser_to_objects([path])
    unreal.log(f"Wrote {path} - use it in World Settings > GEMSTAR > Default Experience")


def open_map_ini():
    settings = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world().get_world_settings()
    path = settings.get_editor_property("gemstar_configuration") \
        if isinstance(settings, unreal.GemstarWorldSettings) else ""
    return PROJECT / (path or "Simulation/DefaultGemstar.ini")


def arguments():
    parser = argparse.ArgumentParser(description="Writes the experience an ini needs.")
    parser.add_argument("ini", nargs="?", help="scenario ini, relative to the project, default: the open map's ini")
    parser.add_argument("--name", help="experience asset name, default: DA_<ini file name>")
    parser.add_argument("--force", action="store_true", help="write even when there are problems")
    parser.add_argument("--dry-run", action="store_true", help="only log the features and problems")
    return parser.parse_args(sys.argv[1:])


def main():
    args = arguments()
    ini = PROJECT / args.ini if args.ini else open_map_ini()
    if not ini.is_file():
        unreal.log_error(f"ini not found: {ini}")
        return
    features, problems = needed_features(ini, feature_plugins())
    for feature, reasons in features.items():
        unreal.log(f"{feature:28} {'; '.join(reasons)}")
    for problem in problems:
        unreal.log_error(problem)
    if args.dry_run:
        unreal.log("Dry run - nothing written.")
    elif problems and not args.force:
        unreal.log_error("Not written: fix the problems above, or pass --force.")
    else:
        write_asset(args.name or f"DA_{ini.stem}", list(features), ini)


if __name__ == "__main__":
    main()
