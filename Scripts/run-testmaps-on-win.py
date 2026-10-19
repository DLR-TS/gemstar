#!/usr/bin/env python3
# Copyright (c) 2026 DLR e.V.
#
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Runs GEMSTAR maps one after another in -game and summarises each log
# Usage and options: Documentation/RunTestMaps.md
import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
READY_LINE = "GEMSTAR IS READY FOR SIMULATION"
FATAL_PATTERNS = ("Fatal error", "Assertion failed", "Unhandled Exception")
SKIP_DIRS = {"Developers", "Collections", "__ExternalActors__", "__ExternalObjects__"}

# Counted per log; label -> substring
COUNTERS = {
    "errors": "Error:",
    "features": "Activated Game Feature:",
    "flows": "GEMSTAR registered dataflow:",
    "flows_pending": "dataflow not set up yet",
    "mounts_pending": "can not mount yet",
    "no_target": "data target not configured",
    "unknown_feature": "Unknown Game Feature Plugin",
    "loader_missing": "Failed to load component class",
}


def find_project():
    projects = sorted(REPO_ROOT.glob("*.uproject"))
    if not projects:
        sys.exit(f"No .uproject found in {REPO_ROOT}")
    return projects[0]


def engine_association(project):
    try:
        return json.loads(project.read_text(encoding="utf-8")).get("EngineAssociation", "")
    except (OSError, ValueError):
        return ""


def read_lenient_json(path):
    # UnrealLocation.json is hand-edited and may carry a trailing comma
    text = re.sub(r",\s*([}\]])", r"\1", path.read_text(encoding="utf-8"))
    return json.loads(text)


def editor_binary(engine_root):
    return Path(engine_root) / "Engine" / "Binaries" / "Win64" / "UnrealEditor.exe"


def find_engine(explicit, version):
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("UE_ROOT"):
        candidates.append(Path(os.environ["UE_ROOT"]))
    location_file = REPO_ROOT / "UnrealLocation.json"
    if location_file.is_file():
        try:
            locations = read_lenient_json(location_file)
            for key in (f"ue_{version}", f"UE_{version}", version):
                if key in locations:
                    candidates.append(Path(locations[key]))
        except (OSError, ValueError):
            print(f"Warning: could not read {location_file.name}, ignoring it.")
    parent = REPO_ROOT
    for _ in range(4):
        parent = parent.parent
        candidates += [parent / "UnrealEngine", parent / "unrealengine" / "UnrealEngine"]
    if version:
        for base in (os.environ.get("ProgramFiles", r"C:\Program Files"), r"C:\Program Files"):
            candidates.append(Path(base) / "Epic Games" / f"UE_{version}")
    for root in candidates:
        if editor_binary(root).is_file():
            return root
    tried = "\n  ".join(str(c) for c in candidates)
    sys.exit(f"Unreal Engine not found. Pass --engine or set UE_ROOT. Tried:\n  {tried}")


def package_path(umap, content_root, mount):
    relative = umap.relative_to(content_root).with_suffix("")
    return f"/{mount}/" + "/".join(relative.parts)


def discover_maps():
    maps = []
    project_content = REPO_ROOT / "Content"
    roots = [(project_content, "Game")]
    for uplugin in sorted((REPO_ROOT / "Plugins").rglob("*.uplugin")):
        content = uplugin.parent / "Content"
        if content.is_dir():
            roots.append((content, uplugin.stem))
    for content_root, mount in roots:
        for umap in sorted(content_root.rglob("*.umap")):
            if SKIP_DIRS.intersection(umap.relative_to(content_root).parts):
                continue
            maps.append(package_path(umap, content_root, mount))
    return maps


def log_name(map_path):
    return map_path.strip("/").replace("/", "__") + ".log"


def error_log_name(map_path):
    return log_name(map_path).removesuffix(".log") + ".errors.log"


def run_map(editor, project, map_path, log_file, args):
    command = [str(editor), str(project), map_path, "-game", "-windowed",
               f"-resx={args.resx}", f"-resy={args.resy}", "-unattended", "-nosplash",
               f"-abslog={log_file}"]
    if args.nullrhi:
        command.append("-nullrhi")
    if log_file.exists():
        log_file.unlink()
    started = time.time()
    process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    status, ready_after = "timeout", None
    while time.time() - started < args.timeout:
        time.sleep(2)
        text = log_file.read_text(encoding="utf-8", errors="replace") if log_file.exists() else ""
        if READY_LINE in text:
            status, ready_after = "ready", time.time() - started
            break
        if any(p in text for p in FATAL_PATTERNS):
            status = "fatal"
            break
        if process.poll() is not None:
            status = "exited"
            break
    if status == "ready":
        deadline = time.time() + args.settle
        while time.time() < deadline and process.poll() is None:
            time.sleep(1)
    stop(process)
    return status, ready_after


def stop(process):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


def count_lines(log_file):
    counts = dict.fromkeys(COUNTERS, 0)
    errors = []
    if log_file.exists():
        for line in log_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if "Error:" in line or any(p in line for p in FATAL_PATTERNS):
                errors.append(line)
            for label, needle in COUNTERS.items():
                if needle in line:
                    counts[label] += 1
    return counts, errors


def write_error_log(out_dir, map_path, errors):
    # Always created; an empty file means the map logged no errors
    path = out_dir / error_log_name(map_path)
    if errors:
        path.write_text("\n".join(errors) + "\n", encoding="utf-8")
    else:
        path.touch()
    return path


def write_summary(out_dir, rows):
    columns = ["map", "status", "ready_s"] + list(COUNTERS)
    with open(out_dir / "summary.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)
    lines = ["| " + " | ".join(columns) + " |", "|" + "---|" * len(columns)]
    for row in rows:
        lines.append("| " + " | ".join(str(row[c]) for c in columns) + " |")
    (out_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Run GEMSTAR maps one after another in -game.")
    parser.add_argument("maps", nargs="*", help="map package paths, e.g. /Game/GEMSTAR (default: all)")
    parser.add_argument("--filter", default="", help="only maps whose path contains this text")
    parser.add_argument("--list", action="store_true", help="print the maps and exit")
    parser.add_argument("--engine", help="engine root (folder that contains Engine/)")
    parser.add_argument("--timeout", type=int, default=180, help="seconds to reach READY (default 180)")
    parser.add_argument("--settle", type=int, default=30, help="seconds to keep running after READY (default 30)")
    parser.add_argument("--out", help="output folder (default: Saved/TestMapRuns/<timestamp>)")
    parser.add_argument("--nullrhi", action="store_true", help="no rendering; camera output will be empty")
    parser.add_argument("--resx", type=int, default=1280)
    parser.add_argument("--resy", type=int, default=720)
    args = parser.parse_args()

    maps = args.maps or discover_maps()
    if args.filter:
        maps = [m for m in maps if args.filter.lower() in m.lower()]
    if args.list:
        print("\n".join(maps))
        return 0
    if not maps:
        sys.exit("No maps to run.")

    project = find_project()
    engine = find_engine(args.engine, engine_association(project))
    editor = editor_binary(engine)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_dir = Path(args.out) if args.out else REPO_ROOT / "Saved" / "TestMapRuns" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"Engine:  {engine}\nProject: {project}\nLogs:    {out_dir}\nMaps:    {len(maps)}\n")

    rows = []
    for index, map_path in enumerate(maps, 1):
        log_file = out_dir / log_name(map_path)
        print(f"[{index}/{len(maps)}] {map_path} ...", end=" ", flush=True)
        status, ready_after = run_map(editor, project, map_path, log_file, args)
        counts, errors = count_lines(log_file)
        errors_file = write_error_log(out_dir, map_path, errors)
        ready_s = f"{ready_after:.0f}" if ready_after is not None else "-"
        print(f"{status} (READY after {ready_s} s, {counts['errors']} error lines)")
        if errors:
            print(f"  errors saved to {errors_file}")
        rows.append({"map": map_path, "status": status, "ready_s": ready_s, **counts})
        # Summary so far, also rewritten to disk so an aborted run keeps it
        print(f"\nSummary after {index} of {len(maps)} maps:\n" + write_summary(out_dir, rows) + "\n")

    failed = [r["map"] for r in rows if r["status"] != "ready"]
    print(f"\n{len(rows) - len(failed)} of {len(rows)} maps reached READY. Summary: {out_dir / 'summary.md'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())