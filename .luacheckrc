-- .luacheckrc — CTLD_Next project
-- Target runtime: DCS World (Lua 5.1 strict)
-- Run: luacheck src/ tests/ CTLD_Next.lua

std = "lua51"

-- Lua 5.2+ constructs are not available in DCS (Lua 5.1)
-- luacheck will warn on goto, <const>, <close>, table.move, math.type, utf8.*
-- Note: goto itself is a Lua 5.2+ keyword — luacheck's lua51 std already rejects it.

max_line_length = 200
unused_args     = false   -- many DCS callbacks receive args not always used
self            = false   -- OOP methods use self implicitly

-- Files / directories to ignore
exclude_files = {
    "source/**",          -- legacy source, never modified
    "tools/**",
}

-- DCS World API globals (all read-only from script perspective)
read_globals = {
    -- DCS singleton namespaces
    "env", "world", "coalition", "country", "timer", "trigger",
    "land", "atmosphere", "coord", "radio", "spot", "missionCommands",
    -- DCS object constructors / class tables
    "Unit", "Group", "StaticObject", "Airbase", "Object", "Controller",
    "Weapon", "Runway", "Warehouse",
    -- DCS utility globals
    "dcsCommon", "mist",
    -- Lua 5.1 stdlib present in DCS but not in luacheck min std
    "require", "dofile", "loadfile", "loadstring",
    -- io / os present in DCS sandboxed environment
    "io", "os",
}

-- CTLD globals defined across src/ files (writable — they are defined here)
globals = {
    -- Core namespace
    "ctld",
    -- Config
    "CTLDConfig",
    -- i18n
    "CTLDi18n",
    -- Utils / infrastructure
    "EventDispatcher",
    "CTLDObjectRegistry",
    "CTLDParachuteEffect",
    "CTLDNullParachuteEffect",
    "CTLDModValidator",
    -- Domain classes
    "CTLDCrate",
    "CTLDCrateManager",
    "CTLDCrateAssemblyManager",
    "CTLDTroopGroup",
    "CTLDTroopManager",
    "CTLDVehicle",
    "CTLDVehicleSpawner",
    "CTLDFOB",
    "CTLDFOBManager",
    "CTLDBeacon",
    "CTLDBeaconManager",
    "CTLDReconRenderer",
    "CTLDReconManager",
    "CTLDZoneManager",
    "CTLDLogisticZone",
    "CTLDTroopZone",
    "CTLDSceneManager",
    "CtldScene",
    "CTLDPlayer",
    "CTLDPlayerTracker",
    "CTLDPlayerManager",
    "CTLDJTAC",
    "CTLDJTACDetector",
    "CTLDJTACMessage",
    "CTLDJTACManager",
    "CTLDSmokeManager",
    "CTLDStaticWatcher",
    "CTLDDCSEventBridge",
    "CTLDCoreManager",
}

-- Per-file overrides
files["tests/"] = {
    -- Test helpers may use additional globals
    globals = { "describe", "it", "before_each", "after_each",
                "assert", "spy", "mock", "stub",
                "ctld_test" },
}
