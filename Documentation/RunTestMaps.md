# Running GEMSTAR Test Maps

This tool runs your project's maps one after another in `-game` mode,
watches each map's log for the readiness marker, and produces a summary
report (CSV + Markdown) with per-map error and warning counts.

## Requirements

- Windows
- Python 3
- Unreal Engine installed and matching the `EngineAssociation` in the
  `.uproject` file (or reachable via `UE_ROOT` / `--engine`)
- Unreal Editor commandlet support (a normal editor install is fine)

## Quick start

From anywhere in the repo, run:

```bash
python Scripts/run-testmaps-on-win.py
```

That discovers every `.umap` in `Content/` and plugin `Content/` folders
(skipping `Developers`, `Collections`, `__ExternalActors__`,
`__ExternalObjects__`), runs each one, and writes reports to
`Saved/TestMapRuns/<timestamp>/`.

To run just one map:

```bash
python Scripts/run-testmaps-on-win.py /Game/GEMSTAR
```

To see what it would run without running anything:

```bash
python Scripts/run-testmaps-on-win.py --list
```

## Options

| Option | Default | Description |
|---|---|---|
| `maps` (positional) | all discovered | Map package paths to run, e.g. `/Game/GEMSTAR` |
| `--filter TEXT` | – | Only run maps whose path contains `TEXT` (case-insensitive) |
| `--list` | – | Print discovered maps and exit |
| `--engine PATH` | auto-detect | Engine root — the folder containing `Engine/` |
| `--timeout N` | `180` | Seconds to wait for the map to reach READY |
| `--settle N` | `30` | Seconds to keep the map running after READY so late errors are logged |
| `--out DIR` | `Saved/TestMapRuns/<timestamp>` | Output folder for logs and summaries |
| `--nullrhi` | off | Disable rendering (faster, but camera output is empty) |
| `--resx N` | `1280` | Window width |
| `--resy N` | `720` | Window height |

## How a map is judged

Each map runs like this:

```
UnrealEditor.exe <project> <map> -game -windowed -unattended -nosplash -abslog=<log>
```

The script polls the log every 2 seconds and assigns one of four statuses:

| Status | Meaning |
|---|---|
| `ready` | Log contains `GEMSTAR IS READY FOR SIMULATION` |
| `fatal` | Log contains `Fatal error`, `Assertion failed`, or `Unhandled Exception` |
| `exited` | The editor process exited before reaching READY |
| `timeout` | READY marker never appeared within `--timeout` seconds |

After `ready`, the map keeps running for `--settle` seconds so any
late-appearing errors are captured, then the process is terminated.

## Output

For each run, in the output folder:

- **`<MAP>__PATH.log`** — the full Unreal log for each map (one per map,
  named after the map path with `/` replaced by `__`)
- **`<MAP>__PATH.errors.log`** — just the `Error:` / fatal-pattern lines for that
  map; an empty file means no errors were logged
- **`summary.csv`** — one row per map: status, seconds to READY, and
  counts of diagnostic log lines
- **`summary.md`** — the same table in Markdown, also printed to the
  console after every map

The summary is rewritten after **each** map, so an interrupted run still
leaves a valid partial report.

Counters per map:

| Column | Counts lines containing |
|---|---|
| `errors` | `Error:` |
| `features` | `Activated Game Feature:` |
| `flows` | `GEMSTAR registered dataflow:` |
| `flows_pending` | `dataflow not set up yet` |
| `mounts_pending` | `can not mount yet` |
| `no_target` | `data target not configured` |
| `unknown_feature` | `Unknown Game Feature Plugin` |
| `loader_missing` | `Failed to load component class` |

### Exit code

- `0` — all maps reached READY
- `1` — one or more maps did not

Safe to use as a CI gate: `python Scripts/run-testmaps-on-win.py && ...`.

## Examples

```bash
# Everything
python Scripts/run-testmaps-on-win.py

# Only maps with "GEMSTAR" in the path
python Scripts/run-testmaps-on-win.py --filter GEMSTAR

# Two specific maps, no rendering, 5-minute timeout
python Scripts/run-testmaps-on-win.py /Game/GEMSTAR /Plugins/Foo/Content/Maps/Bar \
    --nullrhi --timeout 300

# Engine in a non-standard location
python Scripts/run-testmaps-on-win.py --engine D:\Engines\UE_5.3

# Reuse a fixed output folder
python Scripts/run-testmaps-on-win.py --out Saved/TestMapRuns/latest
```

## Engine lookup order

The script finds the engine in this order and uses the first candidate
whose `Engine/Binaries/Win64/UnrealEditor.exe` exists:

1. `--engine` argument
2. `UE_ROOT` environment variable
3. `UnrealLocation.json` at the repo root (keys tried: `ue_<version>`,
   `UE_<version>`, `<version>`; trailing commas are tolerated)
4. `UnrealEngine` / `unrealengine/UnrealEngine` folders in up to four
   parent directories of the repo
5. `C:\Program Files\Epic Games\UE_<version>`

If none match, the script exits listing every path it tried — just pass
one of them via `--engine` or export it as `UE_ROOT`.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `Unreal Engine not found` | Pass `--engine` or set `UE_ROOT`; the exit message lists what was tried |
| Every map is `timeout` | Game startup is slower than `--timeout`; raise it (e.g. `--timeout 600`) |
| `exited` immediately | Check the per-map log — usually a missing dependency or failed plugin load; `loader_missing` column is a hint |
| High `flows_pending` / `mounts_pending` | Game features still initialising when the map was killed — increase `--settle` |
| Empty camera output | You passed `--nullrhi` (expected, see option description) |

| Column | Counts log lines containing | Hint |
| --- | --- | --- |
| `status` | — | `ready`, `timeout`, `fatal` (crash or assert), `exited` (quit before READY) |
| `ready_s` | — | seconds until READY |
| `errors` | `Error:` | all error lines |
| `features` | `Activated Game Feature:` | should equal the number of features in the map's experience |
| `flows` | `GEMSTAR registered dataflow:` | wired producer → consumer flows |
| `flows_pending` | `dataflow not set up yet` | a requested producer never answered |
| `mounts_pending` | `can not mount yet` | no vehicle with that alias spawned |
| `no_target` | `data target not configured` | a sensor has nobody to send to; high counts come from sensors placed in a map by hand |
| `unknown_feature` | `Unknown Game Feature Plugin` | a typo in an experience's feature list |
| `loader_missing` | `Failed to load component class` | a feature has no runtime module on this platform |
