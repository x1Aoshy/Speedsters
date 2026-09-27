"""Register World 3 in src/manifest.json from audit/compose_world3.luau's output.

usage: python audit/register_world3.py

Every script in audit/world3_base/input.rbxl gets a row:
  * shared scripts keep World 2's row (same src/common source), at their World 3 position;
  * the desert map's own scripts get a source under src/worlds/World3/Workspace/, written
    only when missing, since src is canonical once it exists;
  * scripts the build adds (World 2's added shared modules and World 3's own services)
    are carried over, including World 3 rows added later with scratch/manifest_add.py.
"""
import io
import json
import os
import sys

MANIFEST = "src/manifest.json"
SCRIPTS = "audit/world3_base/scripts.json"
INPUT = "audit/world3_base/input.rbxl"
LATEST = "World3NewestStable.rbxl"

# Scripts World 3 adds that no other world has.
WORLD3_ADDED = [
    ("ModuleScript", ["ServerScriptService", "Gameplay", "World3StageTeleportService"],
     "src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau"),
    ("Script", ["ServerScriptService", "Gameplay", "World3ManualStagePads"],
     "src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau"),
    ("Script", ["ServerScriptService", "Progression", "World3TreadmillOverheadLabels"],
     "src/worlds/World3/ServerScriptService/Progression/World3TreadmillOverheadLabels.server.luau"),
    ("ModuleScript", ["ReplicatedStorage", "Shared", "World3HazardMotion"],
     "src/worlds/World3/ReplicatedStorage/Shared/World3HazardMotion.luau"),
    ("ModuleScript", ["ServerScriptService", "Gameplay", "World3HazardLayout"],
     "src/worlds/World3/ServerScriptService/Gameplay/World3HazardLayout.luau"),
    ("Script", ["ServerScriptService", "Gameplay", "World3Hazards"],
     "src/worlds/World3/ServerScriptService/Gameplay/World3Hazards.server.luau"),
    ("LocalScript", ["StarterPlayer", "StarterPlayerScripts", "Gameplay", "World3HazardsClient"],
     "src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3HazardsClient.client.luau"),
    ("Script", ["ServerScriptService", "Gameplay", "World3FlightAbility"],
     "src/worlds/World3/ServerScriptService/Gameplay/World3FlightAbility.server.luau"),
    ("LocalScript", ["StarterPlayer", "StarterPlayerScripts", "Movement", "World3FlightAbility"],
     "src/worlds/World3/StarterPlayer/StarterPlayerScripts/Movement/World3FlightAbility.client.luau"),
    ("LocalScript", ["StarterPlayer", "StarterPlayerScripts", "Gameplay", "World3LeaderboardChampions"],
     "src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3LeaderboardChampions.client.luau"),
]

SUFFIX = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}

manifest = json.load(io.open(MANIFEST, encoding="utf-8"))
composed = json.load(io.open(SCRIPTS, encoding="utf-8"))
world2 = manifest["worlds"]["World2"]
if composed["world2InputSha256"] != world2["inputSha256"]:
    sys.exit("World 2's input changed since composing; run audit/compose_world3.luau again")

world2_rows = {row["id"]: row for row in world2["scripts"] if not row.get("added")}
legacy_counts = {}
for entry in composed["scripts"]:
    path = "/".join(entry["segments"])
    legacy_counts[path] = legacy_counts.get(path, 0) + 1

# A map script that shares its path with others is named by its id, and ids move when the
# composed place changes. Its source moves with it: the n-th script at a path takes over
# the n-th one's file from the last registration, so edits made in src are kept.
previous = manifest["worlds"].get("World3", {}).get("scripts", [])
previous_duplicates = {}
for row in sorted((row for row in previous if row.get("duplicate") and not row.get("added")), key=lambda row: row["id"]):
    previous_duplicates.setdefault(row["legacyPath"], []).append(row["source"])
seen_duplicates = {}

rows = []
written = []
moved = []
for entry in composed["scripts"]:
    segments = entry["segments"]
    legacy = "/".join(segments)
    duplicate = legacy_counts[legacy] > 1
    if "world2Id" in entry:
        row = dict(world2_rows[entry["world2Id"]])
        if row["segments"] != segments or row["class"] != entry["class"]:
            sys.exit("World 2 row moved: " + row["path"])
        if bool(row.get("duplicate")) != duplicate:
            sys.exit("Duplicate status changed for " + row["path"])
        row["id"] = entry["id"]
    else:
        stem = "src/worlds/World3/" + legacy
        if duplicate:
            stem += "__instance_" + str(entry["id"])
        source = stem + SUFFIX[entry["class"]]
        if duplicate:
            ordinal = seen_duplicates.get(legacy, 0)
            seen_duplicates[legacy] = ordinal + 1
            earlier = previous_duplicates.get(legacy, [])
            if not os.path.isfile(source) and ordinal < len(earlier) and os.path.isfile(earlier[ordinal]):
                os.replace(earlier[ordinal], source)
                moved.append((earlier[ordinal], source))
        if not os.path.isfile(source):
            os.makedirs(os.path.dirname(source), exist_ok=True)
            io.open(source, "w", encoding="utf-8", newline="").write(entry["desertSource"])
            written.append(source)
        row = {
            "class": entry["class"],
            "duplicate": duplicate,
            "id": entry["id"],
            "legacyPath": legacy,
            "path": ".".join(segments),
            "segments": segments,
            "source": source,
        }
    rows.append(row)

added = [dict(row) for row in world2["scripts"] if row.get("added")]
for row in added:
    if not row["source"].startswith("src/common/"):
        sys.exit("World 2 adds a world-specific script; decide whether World 3 needs it: " + row["path"])

wanted = [(cls, segments, source) for cls, segments, source in WORLD3_ADDED]
wanted += [(row["class"], row["segments"], row["source"]) for row in previous
           if row.get("added") and not row["source"].startswith("src/common/")]
known = {tuple(row["segments"]) for row in added}
next_id = max([row.get("id", 0) for row in rows + added] + [row.get("id", 0) for row in previous]) + 1
for cls, segments, source in wanted:
    if tuple(segments) in known:
        continue
    if not os.path.isfile(source):
        sys.exit("Missing source for World 3 script: " + source)
    old = next((row for row in previous if row.get("added") and row["segments"] == segments), None)
    added.append({
        "added": True,
        "class": cls,
        "duplicate": False,
        "id": old["id"] if old and "id" in old else next_id,
        "legacyPath": "/".join(segments),
        "path": ".".join(segments),
        "segments": segments,
        "source": source,
    })
    if not (old and "id" in old):
        next_id += 1
    known.add(tuple(segments))

manifest["worlds"]["World3"] = {
    "input": INPUT,
    "inputSha256": composed["inputSha256"],
    "latestInput": LATEST,
    "scripts": rows + added,
}
io.open(MANIFEST, "w", encoding="utf-8", newline="").write(
    json.dumps(manifest, sort_keys=True, separators=(",", ":")))
print("World3: %d scripts from the place (%d map sources written), %d added by the build"
      % (len(rows), len(written), len(added)))
for source in written:
    print("  wrote " + source)
for earlier, source in moved:
    print("  moved " + earlier + " -> " + source)
