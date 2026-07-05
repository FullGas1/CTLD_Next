-- ============================================================
-- CTLD_userConfig.lua
-- User configuration — load AFTER CTLD_Next.lua in the mission.
--
-- HOW TO USE
--   In the Mission Editor, add a trigger "MISSION START → DO SCRIPT FILE"
--   and select this file.  It must run AFTER CTLD_Next.lua.
--
-- All values below are the factory defaults.
-- Uncomment and edit only the lines you want to change.
-- ============================================================

if ctld == nil then ctld = {} end

-- ============================================================
-- SECTION 1 — SCALAR PARAMETERS (bool / number / string)
-- Comment / uncomment individual lines to override defaults.
-- ============================================================
ctld.yamlConfigDatas = [[

# ============================================================
# General
# ============================================================

# Enable verbose debug logging to CTLD.log.
# Requires a non-sanitized DCS installation (io + lfs must be available).
# Leave false in production missions.
# ctld.debug: false

# Override the log file path (CTLD.log location).
# Leave empty to use the default DCS Saved Games folder.
# ctld.ctldLogPath:

# Show coordinates as Degrees-Minutes-Seconds (DMS) instead of Degrees-Decimal-Minutes.
# ctld.location_DMS: false

# Suppress all smoke at pickup / drop-off zones, regardless of per-zone settings.
# ctld.disableAllSmoke: false


# ============================================================
# Logistics
# ============================================================

# Maximum distance (m) between the transport and a logistic zone to allow crate
# spawning or loading operations.
# ctld.maximumDistanceLogistic: 200

# Radius (m) of the logistic zone created around each LGZ_ trigger zone (dynamic logistic zones).
# ctld.dynamicZoneRadius: 200

# Interval (s) between successive smoke signal refreshes at logistic / troop zones.
# ctld.smokeRefreshInterval: 300


# ============================================================
# Crates
# ============================================================

# Master switch — set to false to disable the entire crate system.
# ctld.enableCrates: true

# Show "All crates" shortcut entries in the F10 menu (spawns every component of a
# multi-crate system at once).
# ctld.enableAllCrates: true

# Enable hover-based slingload pickup (pilot must hover above a crate at the correct
# altitude).  Set to false to allow loading via the F10 menu only.
# ctld.enableHoverSlingload: true

# Allow crate loading via the F10 menu in addition to hover.  Useful when flying
# fixed-wing aircraft that cannot hover.
# ctld.loadCrateFromMenu: true

# Enable the "Drop Smoke" F10 menu entry.
# ctld.enableSmokeDrop: true

# Enable DCS native slingload weight simulation.
# WARNING: some DCS versions crash with slingload enabled — if crashes occur set this
# to false and rely on the virtual hover system instead.
# ctld.slingLoad: false

# Maximum horizontal speed (m/s) allowed while carrying a virtual slingloaded crate.
# Exceeding this speed causes the crate to detach and fall.
# ctld.maxSlingloadSpeed: 50

# Spacing (m) between consecutive crate spawn positions along the spawn axis.
# ctld.crateSpacing: 5

# Extra radius (m) added to the transport's safe-radius when placing troops/crates in a circle.
# ctld.spawnDistanceInCircle: 10



# ============================================================
# Hover parameters (virtual slingload pickup)
# ============================================================

# Minimum AGL height (m) required to initiate a hover pickup.
# ctld.minimumHoverHeight: 7.5

# Maximum AGL height (m) at which a hover pickup is still valid.
# ctld.maximumHoverHeight: 12.0

# Maximum horizontal distance (m) between the transport and the crate centre
# for a hover pickup to count.
# ctld.maxDistanceFromCrate: 5.5

# Time (s) the pilot must maintain a valid hover before the crate is loaded.
# ctld.hoverTime: 10


# ============================================================
# Troops
# ============================================================

# Default number of troops loaded per transport (also acts as maximum group size
# unless overridden per aircraft type in capabilitiesByType[type].maxTroopsOnboard).
# ctld.numberOfTroops: 10

# Maximum total troop weight (kg) a transport can carry.
# 0 = no weight limit (default).  When > 0, groups whose total weight would exceed
# the limit cannot be loaded.
# ctld.maxTransportWeight: 0

# Maximum distance (m) from the transport to a troop group to allow extraction.
# ctld.maxExtractDistance: 125

# Maximum distance (m) deployed troops will search for an enemy unit.
# ctld.maximumSearchDistance: 3000


# Allow pilots to insert troops via fast-rope.
# ctld.enableFastRopeInsertion: true

# Maximum safe AGL height (m) for fast-rope (not rappel) insertion — 60 ft default.
# ctld.fastRopeMaximumHeight: 18.28

# Allow AI transports to randomly pick up infantry teams at pickup zones.
# ctld.allowRandomAiTeamPickups: false


# ============================================================
# Infantry weight simulation
# Each soldier's weight is randomised between 90 % and 120 % of SOLDIER_WEIGHT,
# then the kit and role-specific equipment weights are added on top.
# These values affect whether a group fits inside a transport (maxTroopsOnboard).
# ============================================================

# Base body weight per soldier (kg) before randomisation.
# ctld.SOLDIER_WEIGHT: 80

# Helmet + backpack weight per soldier (kg).
# ctld.KIT_WEIGHT: 20

# Standard infantry rifle kit weight (kg).
# ctld.RIFLE_WEIGHT: 5

# AA soldier MANPAD tube weight (kg).
# ctld.MANPAD_WEIGHT: 18

# AT soldier RPG launcher + rocket weight (kg).
# ctld.RPG_WEIGHT: 7.6

# Machine-gunner weapon + 200-round belt weight (kg).
# ctld.MG_WEIGHT: 10

# Mortar servant tube + shells weight (kg).
# ctld.MORTAR_WEIGHT: 26

# JTAC laser designator + radio + binoculars weight (kg).
# ctld.JTAC_WEIGHT: 15

# Civilian role personal items weight (kg).
# ctld.CIV_WEIGHT: 2


# ============================================================
# FOB (Forward Operating Base)
# ============================================================

# Enable FOB building from crates.
# ctld.enabledFOBBuilding: true

# Allow troops to be picked up at a deployed FOB.
# ctld.troopPickupAtFOB: true

# Minimum distance (m) from any existing logistic zone at which a FOB may be deployed.
# ctld.fobMinDistanceFromZones: 500

# Radius (m) of the logistic zone created around a deployed FOB.
# ctld.fobLogisticZoneRadius: 150

# Fraction of scene objects that must be destroyed before the FOB is considered lost.
# 0.0 = lost if anything is destroyed ; 1.0 = lost only when everything is destroyed.
# ctld.fobDestructionThreshold: 0.5

# Radius (m) within which troops can board a transport at a FOB.
# ctld.fobTroopPickupRadius: 150

# Allow players to pack a deployed FARP back into crates for redeployment elsewhere.
# ctld.enableFARPRepack: true


# ============================================================
# Parachute — virtual parachute drop (Feature A)
# ============================================================

# Minimum AGL altitude (m) required to initiate a parachute drop for crates.
# ctld.parachuteMinAltitudeCrates: 30

# Minimum AGL altitude (m) required to initiate a parachute drop for troops.
# ctld.parachuteMinAltitudeTroops: 50

# Minimum AGL altitude (m) required to initiate a parachute drop for vehicles.
# ctld.parachuteMinAltitudeVehicles: 30

# Vertical descent speed (m/s) for parachuted crates (slower = more accurate landing).
# ctld.parachuteDescentRateCrates: 5

# Vertical descent speed (m/s) for parachuted troops.
# ctld.parachuteDescentRateTroops: 5

# Vertical descent speed (m/s) for parachuted vehicles (heavier loads fall faster).
# ctld.parachuteDescentRateVehicles: 8

# Forward drift factor : fraction of the transport's current speed applied as
# forward inertia to each dropped unit (0.0 = no drift ; 1.0 = full speed drift).
# ctld.parachuteInertiaFactor: 0.3

# Minimum random lateral drift (m) applied per unit during a parachute drop.
# ctld.parachuteLateralDriftMin: 10

# Maximum random lateral drift (m) applied per unit during a parachute drop.
# ctld.parachuteLateralDriftMax: 80

# Search radius (m) used when auto-unpacking parachuted crates after landing.
# Larger than the normal unpack radius to account for dispersion during descent.
# ctld.autoUnpackRadiusParachute: 1000


# ============================================================
# Beacons
# ============================================================

# Allow pilots to deploy radio beacons.
# ctld.enabledRadioBeaconDrop: true

# Battery life (minutes) of a deployed beacon before it stops transmitting.
# ctld.deployedBeaconBattery: 30

# Sound file used for FOB / beacon audio.  Must be added to the mission (.miz) file.
# ctld.radioSound: beacon.ogg

# Silent sound file used for FC3 aircraft so they do not hear all coalition beacons.
# ctld.radioSoundFC3: beaconsilent.ogg


# ============================================================
# AA systems (multi-crate assembly)
# ============================================================

# Default number of launchers added to an AA system when no amount is specified
# in its assembly template.
# ctld.aaLaunchers: 3

# Maximum number of fully functional AA systems that RED / BLUE can have deployed
# simultaneously.  Players can still receive crates beyond the limit, but cannot
# unpack them until an existing system is destroyed.
# ctld.AASystemLimitRED: 20
# ctld.AASystemLimitBLUE: 20

# Enable crate stacking : bringing N times the required crates spawns N times the
# launchers.  Example : 2 × Patriot launcher crates → 2 launchers in the group.
# ctld.AASystemCrateStacking: false


# ============================================================
# JTAC
# ============================================================

# Maximum number of JTAC units that each side may have active at the same time.
# ctld.JTAC_LIMIT_RED: 10
# ctld.JTAC_LIMIT_BLUE: 10

# Allow pilots to spawn JTAC units from the F10 crate menu.
# ctld.JTAC_dropEnabled: true

# Maximum lasing distance (m) — targets beyond this range are ignored.
# ctld.JTAC_maxDistance: 10000

# Which ground unit types the JTAC will track and lase.
# "vehicle" — armoured vehicles only
# "troop"   — infantry only
# "all"     — any ground unit
# ctld.JTAC_lock: all

# Show the JTAC status entry in the F10 menu.
# ctld.JTAC_jtacStatusF10: true

# Include the target's coordinates in JTAC messages.
# ctld.JTAC_location: true

# Allow pilots to toggle a JTAC's lasing on and off (standby mode).
# ctld.JTAC_allowStandbyMode: true

# Enable laser-spot lead correction : the JTAC attempts to lead moving targets,
# accounting for wind and target speed.  Most useful against moving heavy armour.
# ctld.JTAC_laseSpotCorrections: true

# Allow pilots to request a smoke marker on the JTAC's current target.
# ctld.JTAC_allowSmokeRequest: true

# Allow pilots to request a 9-Line from a JTAC.
# ctld.JTAC_allow9Line: true

# Enable target smoke for RED JTACs.
# ctld.JTAC_smokeOn_RED: false

# Enable target smoke for BLUE JTACs.
# ctld.JTAC_smokeOn_BLUE: false

# Smoke colour used by RED JTACs.
# 0=Green  1=Red  2=White  3=Orange  4=Blue
# ctld.JTAC_smokeColour_RED: 4

# Smoke colour used by BLUE JTACs.
# 0=Green  1=Red  2=White  3=Orange  4=Blue
# ctld.JTAC_smokeColour_BLUE: 1

# Maximum allowed error radius (m) when placing smoke on a target.
# ctld.JTAC_smokeMarginOfError: 50

# Smoke position offsets from the exact target point (metres).
# _x = East offset ; _y = vertical offset (Up) ; _z = North offset.
# ctld.JTAC_smokeOffset_x: 0.0
# ctld.JTAC_smokeOffset_y: 2.0
# ctld.JTAC_smokeOffset_z: 0.0

# Reschedule delay (s) for the auto-lase loop when actively lasing a target.
# ctld.JTAC_laseIntervalSeconds: 15

# Reschedule delay (s) for the auto-lase loop when searching for a target.
# ctld.JTAC_searchIntervalSeconds: 10

# Orbit radius (m) used by drone JTAC units around their target.
# ctld.JTAC_droneRadius: 1000

# Orbit altitude (m) for drone JTAC units.
# ctld.JTAC_droneAltitude: 7000


# ============================================================
# Recon
# ============================================================

# Enable the RECON submenu in the F10 CTLD menu.
# ctld.reconF10Menu: true

# Master switch — set to true to activate RECON functionality.
# When false, the Scan Area command does nothing even if the menu is visible.
# ctld.reconEnabled: false

# LOS detection radius (m) around the scanning unit.
# All enemy units within this radius are tested for line-of-sight.
# ctld.reconSearchRadius: 5000

# Minimum AGL altitude (m) required to perform a scan.
# The pilot must be at or above this height, otherwise the scan is rejected.
# ctld.reconMinAltitude: 50

# Auto-refresh interval (s) between successive target position updates.
# Decrease to track fast-moving targets more accurately (increases CPU load).
# ctld.reconRefreshInterval: 10

# Icon size multiplier applied to all RECON icons on the F10 map.
# 1.0 = default sizes (infantry=30m, vehicle=40m, aa=35m, aircraft=40m,
#        helicopter=25m, ship=50×20m).  Use 2.0 to double all icon sizes.
# ctld.reconIconScale: 1.0


# ============================================================
# Minefield
# ============================================================

# Draw a bounding quad on the F10 map when a minefield is deployed.
# ctld.showMinefieldOnF10Map: true


# ============================================================
# Vehicles / pack
# ============================================================

# Allow pilots to pack nearby vehicles into crates using the F10 menu.
# ctld.enablePackingVehicles: true

# Maximum distance (m) from the transport in which packable vehicles are searched.
# ctld.maximumDistancePackableUnitsSearch: 200

]]

-- ============================================================
-- SECTION 2 — COMPLEX TABLES
-- These cannot be expressed as YAML key:value pairs.
-- They are applied directly on the CTLDConfig instance.
-- Each table REPLACES the default entirely when uncommented.
-- ============================================================

---@diagnostic disable-next-line: unused-local
local _cfg = CTLDConfig.get()

-- Debug mode — active for recette (branch feature_modularisation_and_Config).
-- Set to false (or remove this line) for production missions.
_cfg.settings["debug"] = true

-- ============================================================
-- Per-aircraft capabilities — the unified type registry (replaces
-- aircraftTypeTable, unitActions, and all legacy parallel type-indexed tables).
--
-- Only aircraft listed here get CTLD F10 menus.
-- Each entry REPLACES the matching default when the table is uncommented.
--
-- Fields:
--   cratesEnabled            : can spawn, load and unpack crates
--   troopsEnabled            : can load, deploy and extract infantry groups
--   canParachuteDrop         : enables "Parachute" F10 entries (Feature A)
--   canSlingload             : enables hover-pickup and "Slingload" menus
--   canTransportWholeVehicle : can load/unload whole vehicles (Feature Q)
--   useNativeDcsCargoSystem  : uses the native DCS cargo system for crate spawning
--   maxTroopsOnboard         : max soldiers this aircraft can carry (overrides ctld.numberOfTroops)
--   maxCratesOnboard         : max crates this aircraft can carry at once
--   maxWholeVehiclesOnboard  : max whole vehicles carried simultaneously
--   loadableVehiclesRED      : DCS type names of RED vehicles loadable onto this aircraft
--   loadableVehiclesBLUE     : DCS type names of BLUE vehicles loadable onto this aircraft
-- ============================================================
-- _cfg.settings["capabilitiesByType"] = {
--     -- ── Helicopters ────────────────────────────────────────────────────────────
--     ["Mi-8MT"]    = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=true,
--                       canTransportWholeVehicle=true,  useNativeDcsCargoSystem=true,
--                       maxTroopsOnboard=16, maxCratesOnboard=2, maxWholeVehiclesOnboard=1,
--                       loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
--                       loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
--     ["Mi-24P"]    = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
--                       canTransportWholeVehicle=false, useNativeDcsCargoSystem=true,
--                       maxTroopsOnboard=10, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
--     ["UH-1H"]     = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=true,  canSlingload=true,
--                       canTransportWholeVehicle=true,  useNativeDcsCargoSystem=true,
--                       maxTroopsOnboard=8,  maxCratesOnboard=1, maxWholeVehiclesOnboard=1,
--                       loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
--                       loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
--     ["CH-47Fbl1"] = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=true,
--                       canTransportWholeVehicle=false, useNativeDcsCargoSystem=true,
--                       maxTroopsOnboard=33, maxCratesOnboard=8, maxWholeVehiclesOnboard=1,
--                       loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
--                       loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
--     -- ["Ka-50"]    = { cratesEnabled=true, troopsEnabled=false, canParachuteDrop=false, canSlingload=true,
--     --                  canTransportWholeVehicle=false, useNativeDcsCargoSystem=false,
--     --                  maxTroopsOnboard=0, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
--     -- ["SA342L"]   = { cratesEnabled=false, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
--     --                  canTransportWholeVehicle=false, useNativeDcsCargoSystem=false,
--     --                  maxTroopsOnboard=4, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
--
--     -- ── Fixed-wing ─────────────────────────────────────────────────────────────
--     ["C-130J-30"] = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
--                       canTransportWholeVehicle=true,  useNativeDcsCargoSystem=true,
--                       maxTroopsOnboard=80, maxCratesOnboard=20, maxWholeVehiclesOnboard=2,
--                       loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
--                       loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
--
--     -- ── Mods ───────────────────────────────────────────────────────────────────
--     -- ["Hercules"]    = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
--     --                     canTransportWholeVehicle=true,  useNativeDcsCargoSystem=false,
--     --                     maxTroopsOnboard=30, maxCratesOnboard=1, maxWholeVehiclesOnboard=2,
--     --                     loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
--     --                     loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
--     -- ["UH-60L"]      = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=true,
--     --                     canTransportWholeVehicle=false, useNativeDcsCargoSystem=false,
--     --                     maxTroopsOnboard=12, maxCratesOnboard=2, maxWholeVehiclesOnboard=0 },
--     -- ["76MD"]        = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
--     --                     canTransportWholeVehicle=true,  useNativeDcsCargoSystem=false,
--     --                     maxTroopsOnboard=80, maxCratesOnboard=20, maxWholeVehiclesOnboard=2,
--     --                     loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
--     --                     loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
--     -- ["SK-60"]       = { cratesEnabled=true, troopsEnabled=false, canParachuteDrop=false, canSlingload=false,
--     --                     canTransportWholeVehicle=false, useNativeDcsCargoSystem=false,
--     --                     maxTroopsOnboard=4, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
-- }

-- ============================================================
-- Access control — addPlayerAircraftByType
-- ============================================================
-- true  (default) : any player whose aircraft type is listed in capabilitiesByType
--                   automatically receives CTLD F10 menus.
-- false           : only unit names explicitly listed in transportPilotNames below
--                   receive CTLD menus. Use this to restrict CTLD access to a
--                   fixed set of named slots (e.g. dedicated transport squadron).
--                   AI transports always use transportPilotNames regardless.
-- ============================================================
-- _cfg.settings["addPlayerAircraftByType"] = false

-- ============================================================
-- Transport pilot / unit names authorised to carry CTLD
-- Used when addPlayerAircraftByType = false, or for AI transports.
-- Add any DCS unit name from the Mission Editor here.
-- ============================================================
-- _cfg.settings["transportPilotNames"] = {
--     -- ── Player helicopter slots ────────────────────────────
--     "helicargo1",  "helicargo2",  "helicargo3",  "helicargo4",  "helicargo5",
--     "helicargo6",  "helicargo7",  "helicargo8",  "helicargo9",  "helicargo10",
--     "helicargo11", "helicargo12", "helicargo13", "helicargo14", "helicargo15",
--     "helicargo16", "helicargo17", "helicargo18", "helicargo19", "helicargo20",
--     "helicargo21", "helicargo22", "helicargo23", "helicargo24", "helicargo25",
--
--     -- ── MEDEVAC — BLUE ────────────────────────────────────
--     "MEDEVAC BLUE #1",  "MEDEVAC BLUE #2",  "MEDEVAC BLUE #3",
--     "MEDEVAC BLUE #4",  "MEDEVAC BLUE #5",  "MEDEVAC BLUE #6",
--     "MEDEVAC BLUE #7",  "MEDEVAC BLUE #8",  "MEDEVAC BLUE #9",
--     "MEDEVAC BLUE #10", "MEDEVAC BLUE #11", "MEDEVAC BLUE #12",
--
--     -- ── MEDEVAC — RED ─────────────────────────────────────
--     "MEDEVAC RED #1",  "MEDEVAC RED #2",  "MEDEVAC RED #3",
--     "MEDEVAC RED #4",  "MEDEVAC RED #5",  "MEDEVAC RED #6",
--
--     -- ── MEDEVAC — both sides ──────────────────────────────
--     "MEDEVAC #1", "MEDEVAC #2", "MEDEVAC #3",
--
--     -- ── AI transport slots ────────────────────────────────
--     "transport1",  "transport2",  "transport3",  "transport4",  "transport5",
--     "transport6",  "transport7",  "transport8",  "transport9",  "transport10",
--     "transport11", "transport12", "transport13", "transport14", "transport15",
-- }

-- ============================================================
-- Troop pickup zones (players only — AI transports use AIZones)
-- Each entry: { "zone_or_ship_name", "smoke_color", limit, "active", side [, flag] }
--
--   "zone_or_ship_name" : ME trigger zone name, or DCS unit name of a ship
--   "smoke_color"       : "green"|"red"|"white"|"orange"|"blue"|"none"
--   limit               : -1 = unlimited ; N = max groups that can be loaded
--                         (dropping a group back adds one to the count)
--   "active"            : "yes" = available at mission start
--                         "no"  = deactivated — use ctld.activatePickupZone() to enable
--   side                : 0 = both coalitions ; 1 = RED only ; 2 = BLUE only
--   flag (optional)     : DCS flag number where remaining group count is stored
-- ============================================================
-- _cfg.settings["troopZones"] = {
--     { "pickzone1",   "blue",   -1, "yes", 0 },
--     { "pickzone2",   "red",    -1, "yes", 0 },
--     { "pickzone3",   "none",   -1, "yes", 0 },
--     { "pickzone4",   "none",   -1, "yes", 0 },
--     { "pickzone5",   "none",   -1, "yes", 0 },
--     { "pickzone6",   "none",   -1, "yes", 0 },
--     { "pickzone7",   "none",   -1, "yes", 0 },
--     { "pickzone8",   "none",   -1, "yes", 0 },
--     { "pickzone9",   "none",    5, "yes", 1 }, -- 5 groups max, RED only
--     { "pickzone10",  "none",   10, "yes", 2 }, -- 10 groups max, BLUE only
--     { "pickzone11",  "blue",   20, "no",  2 }, -- starts inactive, BLUE only
--     { "pickzone12",  "red",    20, "no",  1 }, -- starts inactive, RED only
--     { "pickzone13",  "none",   -1, "yes", 0 },
--     { "pickzone14",  "none",   -1, "yes", 0 },
--     { "pickzone15",  "none",   -1, "yes", 0 },
--     { "pickzone16",  "none",   -1, "yes", 0 },
--     { "pickzone17",  "none",   -1, "yes", 0 },
--     { "pickzone18",  "none",   -1, "yes", 0 },
--     { "pickzone19",  "none",    5, "yes", 0 },
--     { "pickzone20",  "none",   10, "yes", 0, 1000 }, -- remaining count stored in flag 1000
--     { "USA Carrier", "blue",   10, "yes", 0, 1001 }, -- ship: use DCS unit name
-- }

-- ============================================================
-- AI-only zones (Feature S — config-only, no naming convention in ME).
-- The DCS trigger zone name is used only for position + radius.
-- Each entry supports pickup and/or dropoff on the same zone.
--
-- Required fields:
--   dcsZoneName  : DCS trigger zone name (must exist in Mission Editor)
--   coalition    : "RED" | "BLUE" | "NEUTRAL"
--
-- Optional pickup fields (isPickup = true):
--   cargoType      : "T"=troops | "V"=vehicles | "TV"=both  (default "T")
--   troopStock     : 0=disabled, -1=unlimited, N=limited stock
--   troopTemplates : list of template names (nil/{}=all compatible ; 1=guaranteed ; N=random among listed)
--   vehicleTypes   : list of DCS typeNames to allow (nil=all vehicles physically present in zone)
--
-- Optional dropoff fields (isDropoff = true):
--   aiDropMode   : "G"=ground | "P"=parachute | "GP"=both  (default "GP")
--
-- Note: vehicles at pickup are always physically present DCS units inside the zone radius.
--       CTLD does not manage a virtual vehicle stock.
-- ============================================================
-- _cfg.settings["aiZones"] = {
--
--     -- Pickup zone: troops only, stock=10, any compatible template
--     { dcsZoneName = "Depot_bleu",   coalition = "BLUE",
--       isPickup = true,  cargoType = "T", troopStock = 10 },
--
--     -- Pickup zone: troops, restricted to Standard Group only (guaranteed if fits heli)
--     { dcsZoneName = "Depot_inf",    coalition = "BLUE",
--       isPickup = true,  cargoType = "T", troopStock = 10,
--       troopTemplates = { "Standard Group" } },
--
--     -- Pickup zone: vehicles only, Hummers only (DCS vehicles physically present in zone)
--     { dcsZoneName = "Depot_hummer", coalition = "BLUE",
--       isPickup = true,  cargoType = "V",
--       vehicleTypes = { "Hummer", "M1025 HMMWV" } },
--
--     -- Pickup zone: troops + vehicles, unlimited troop stock
--     { dcsZoneName = "Depot_tv",     coalition = "BLUE",
--       isPickup = true,  cargoType = "TV", troopStock = -1 },
--
--     -- Dropoff zone: ground only
--     { dcsZoneName = "LZ_nord",      coalition = "BLUE",
--       isDropoff = true, aiDropMode = "G" },
--
--     -- Combined zone: pickup troops AND dropoff (same DCS zone)
--     { dcsZoneName = "FARP_avance",  coalition = "BLUE",
--       isPickup = true, isDropoff = true,
--       cargoType = "T", troopStock = 5, aiDropMode = "GP" },
-- }

-- ============================================================
-- Debug-only: AI zones for recette MT-07 to MT-10 (Feature S).
-- Active only when debug=true above. Remove this block after
-- all interactive AI recettes have passed.
-- ============================================================
if _cfg.settings["debug"] == true then
    _cfg.settings["aiZones"] = {
        -- troopStock / vehicleStock are now tables: { [templateName/typeName] = N }
        -- N=-1=unlimited, N>0=limited. Key "All"=all templates, unlimited.

        -- ── MT-07 / MT-08 / MT-09 / MT-10 ──────────────────────────────
        { dcsZoneName="AIZ_base_B_P_5",       coalition="BLUE", isPickup=true,  cargoType="T",
          troopStock = { ["Standard Group"] = 5, ["Anti Tank"] = 2 } },
        { dcsZoneName="AIZ_front_B_D",         coalition="BLUE", isDropoff=true, aiDropMode="GP" },
        { dcsZoneName="AIZ_depot_B_P_V_10",    coalition="BLUE", isPickup=true,  cargoType="V",
          vehicleStock = { ["Hummer"] = 3, ["M1025 HMMWV Armament"] = -1 } },
        { dcsZoneName="AIZ_depot_B_P_TV_5_10", coalition="BLUE", isPickup=true,  cargoType="TV",
          troopStock = { ["All"] = -1 }, vehicleStock = { ["Hummer"] = 5 } },
        { dcsZoneName="AIZ_livraison_B_D_G",   coalition="BLUE", isDropoff=true, aiDropMode="G"  },
        { dcsZoneName="AIZ_mt10d_B_D_G",       coalition="BLUE", isDropoff=true, aiDropMode="G"  },
        { dcsZoneName="AIZ_depot_B_P_T_10",    coalition="BLUE", isPickup=true,  cargoType="T",
          troopStock = { ["All"] = -1 } },

        -- ── MT-11 : 2 troop templates with limited stock ──────────────────
        { dcsZoneName="AIZ_mt11_B_P_T",  coalition="BLUE", isPickup=true,  cargoType="T",
          troopStock = { ["Standard Group"] = 3, ["Anti Tank"] = 2 } },
        { dcsZoneName="AIZ_mt11_B_D",    coalition="BLUE", isDropoff=true, aiDropMode="GP" },

        -- ── MT-12 : véhicule DCS natif via vehicleStock (Hummer) ────────
        { dcsZoneName="AIZ_mt12_B_P_V",  coalition="BLUE", isPickup=true,  cargoType="V",
          vehicleStock = { ["Hummer"] = 2 } },
        { dcsZoneName="AIZ_mt12_B_D",    coalition="BLUE", isDropoff=true, aiDropMode="G"  },

        -- ── MT-13 : scène (FARP Alpha) via vehicleStock isScene=true ────
        { dcsZoneName="AIZ_mt13_B_P_V",  coalition="BLUE", isPickup=true,  cargoType="V",
          vehicleStock = { ["FARP Alpha"] = 1 } },
        { dcsZoneName="AIZ_mt13_B_D",    coalition="BLUE", isDropoff=true, aiDropMode="G"  },

        -- ── MT-14 : système AA (HAWK) via vehicleStock isAASystem=true (Feature U) ────
        { dcsZoneName="AIZ_mt14_B_P_V",  coalition="BLUE", isPickup=true,  cargoType="V",
          vehicleStock = { ["HAWK AA System"] = 1 } },
        { dcsZoneName="AIZ_mt14_B_D",    coalition="BLUE", isDropoff=true, aiDropMode="G"  },
    }
end

-- ============================================================
-- Waypoint zones (AI routing — transport will fly to each active
-- waypoint zone in sequence before reaching the drop-off zone)
-- Each entry: { "zone_name", "smoke_color", "active", side }
-- ============================================================
-- _cfg.settings["wpZones"] = {
--     { "wpzone1",  "green",  "yes", 2 },
--     { "wpzone2",  "blue",   "yes", 2 },
--     { "wpzone3",  "orange", "yes", 2 },
--     { "wpzone4",  "none",   "yes", 2 },
--     { "wpzone5",  "none",   "yes", 2 },
--     { "wpzone6",  "none",   "yes", 1 },
--     { "wpzone7",  "none",   "yes", 1 },
--     { "wpzone8",  "none",   "yes", 1 },
--     { "wpzone9",  "none",   "yes", 1 },
--     { "wpzone10", "none",   "no",  0 }, -- inactive at start ; both sides
-- }

-- ============================================================
-- Extractable groups
-- DCS group names that can be extracted by a transport.
-- ============================================================
-- _cfg.settings["extractableGroups"] = {
--     "extract1",  "extract2",  "extract3",  "extract4",  "extract5",
--     "extract6",  "extract7",  "extract8",  "extract9",  "extract10",
--     "extract11", "extract12", "extract13", "extract14", "extract15",
--     "extract16", "extract17", "extract18", "extract19", "extract20",
--     "extract21", "extract22", "extract23", "extract24", "extract25",
-- }

-- ============================================================
-- Logistic units — unit names near which crate spawning is allowed.
-- When a logistic unit is destroyed, crate spawning at its location stops.
-- ============================================================
-- _cfg.settings["logisticUnits"] = {
--     "logistic1",  "logistic2",  "logistic3",  "logistic4",  "logistic5",
--     "logistic6",  "logistic7",  "logistic8",  "logistic9",  "logistic10",
--     "logistic11", "logistic12", "logistic13", "logistic14", "logistic15",
--     "logistic16", "logistic17", "logistic18", "logistic19", "logistic20",
-- }

-- ============================================================
-- Vehicle weights (kg) used to determine if a transport can carry a vehicle.
-- Add any DCS unit type that appears in loadableVehiclesRED/BLUE.
-- ============================================================
-- _cfg.settings["groundVehicleWeights"] = {
--     ["BRDM-2"]               = 7000,
--     ["BTR_D"]                = 8000,
--     ["M1045 HMMWV TOW"]      = 3220,
--     ["M1043 HMMWV Armament"] = 2500,
-- }

-- ============================================================
-- Smoke colour at troop pickup zones (TRZ_ trigger zones)
-- Table indexed by coalition number: 1 = RED, 2 = BLUE.
-- -1 = no smoke ; 0=Green  1=Red  2=White  3=Orange  4=Blue.
-- Omit the table entirely (default) to use no smoke.
-- ============================================================
-- _cfg.settings["troopZoneSmokeColor"] = {
--     [1] = 1,  -- RED side zones use red smoke
--     [2] = 4,  -- BLUE side zones use blue smoke
-- }

-- ============================================================
-- Infantry spawn cap — cumulative limit on the number of troops
-- that can be loaded aboard transports across the whole mission.
-- { redLimit, blueLimit }  —  0 = no limit.
-- Example: { 200, 200 } caps each side at 200 troops total.
-- ============================================================
-- _cfg.settings["nbLimitSpawnedTroops"] = { 0, 0 }

-- ============================================================
-- Loadable troop groups
-- Defines the infantry group templates shown in the F10 "Troops" menu.
-- Each entry replaces/adds one loadable group template.
--
-- Fields:
--   name   : label shown in the F10 menu
--   inf    : number of standard riflemen
--   mg     : number of M249 / PKM machine-gunners
--   at     : number of RPG anti-tank soldiers
--   aa     : number of Stinger / Igla MANPAD soldiers
--   mortar : number of 2B11 mortar crews
--   jtac   : number of JTAC soldiers (auto-lase when deployed)
--   side   : 1 = RED only ; 2 = BLUE only ; omit = both coalitions
-- ============================================================
-- _cfg.settings["loadableGroups"] = {
--     { name = "Standard Group",             inf = 6, mg = 2, at = 2 },
--     { name = "Anti Air",                   inf = 2, aa = 3 },
--     { name = "Anti Tank",                  inf = 2, at = 6 },
--     { name = "Mortar Squad",               mortar = 6 },
--     { name = "JTAC Group",                 inf = 4, jtac = 1 },
--     { name = "Single JTAC",                jtac = 1 },
--     { name = "2x Standard Groups",         inf = 12, mg = 4, at = 4 },
--     { name = "2x Anti Air",                inf = 4,  aa = 6 },
--     { name = "2x Anti Tank",               inf = 4,  at = 12 },
--     { name = "2x Standard + 2x Mortar",    inf = 12, mg = 4, at = 4, mortar = 12 },
--     { name = "3x Standard Groups",         inf = 18, mg = 6, at = 6 },
--     { name = "3x Anti Air",                inf = 6,  aa = 9 },
--     { name = "3x Anti Tank",               inf = 6,  at = 18 },
--     { name = "3x Mortar Squad",            mortar = 18 },
--     { name = "5x Mortar Squad",            mortar = 30 },
--     -- { name = "Red Mortar Squad", mortar = 5, side = 1 }, -- RED only
-- }

-- ============================================================
-- Spawnable crates — F10 crate menu catalogue
--
-- The table is keyed by sub-menu name.  Each sub-menu contains
-- one or more crate descriptor entries.
--
-- Crate descriptor fields:
--   weight        (number) : unique kg value used as lookup key — MUST be unique
--   desc          (string) : label shown in the F10 menu
--   unit          (string) : DCS unit type name spawned when the crate is unpacked
--   cratesRequired (number): number of identical crates that must be assembled
--                            within 100 m of each other to build the unit (default 1)
--   side          (number) : 1 = RED only ; 2 = BLUE only ; omit = both coalitions
--   multiple      (table)  : list of weights — shortcut entry that spawns all listed
--                            crates at once (no weight/unit fields needed here)
-- ============================================================
-- _cfg.settings["spawnableCrates"] = {
--
--     ["Combat Vehicles"] = {
--         --- BLUE
--         { weight = 1000.01,                                   desc = "Humvee - MG",                      unit = "M1043 HMMWV Armament", side = 2 },
--         { weight = 1000.02,                                   desc = "Humvee - TOW",                     unit = "M1045 HMMWV TOW",      side = 2, cratesRequired = 2 },
--         { multiple = { 1000.02, 1000.02 },                    desc = "Humvee - TOW - All crates",        side = 2 },
--         { weight = 1000.03,                                   desc = "Light Tank - MRAP",                unit = "MaxxPro_MRAP",         side = 2, cratesRequired = 2 },
--         { multiple = { 1000.03, 1000.03 },                    desc = "Light Tank - MRAP - All crates",   side = 2 },
--         { weight = 1000.04,                                   desc = "Med Tank - LAV-25",                unit = "LAV-25",               side = 2, cratesRequired = 3 },
--         { multiple = { 1000.04, 1000.04, 1000.04 },           desc = "Med Tank - LAV-25 - All crates",   side = 2 },
--         { weight = 1000.05,                                   desc = "Heavy Tank - Abrams",              unit = "M-1 Abrams",           side = 2, cratesRequired = 4 },
--         { multiple = { 1000.05, 1000.05, 1000.05, 1000.05 }, desc = "Heavy Tank - Abrams - All crates", side = 2 },
--         --- RED
--         { weight = 1000.11,                                   desc = "BTR-D",                            unit = "BTR_D",                side = 1 },
--         { weight = 1000.12,                                   desc = "BRDM-2",                           unit = "BRDM-2",               side = 1 },
--     },
--
--     ["Support"] = {
--         --- BLUE
--         { weight = 1001.01,                                   desc = "Hummer - JTAC",                    unit = "Hummer",               side = 2, cratesRequired = 2 },
--         { multiple = { 1001.01, 1001.01 },                    desc = "Hummer - JTAC - All crates",       side = 2 },
--         { weight = 1001.02,                                   desc = "M-818 Ammo Truck",                 unit = "M 818",                side = 2, cratesRequired = 2 },
--         { multiple = { 1001.02, 1001.02 },                    desc = "M-818 Ammo Truck - All crates",    side = 2 },
--         { weight = 1001.03,                                   desc = "M-978 Tanker",                     unit = "M978 HEMTT Tanker",    side = 2, cratesRequired = 2 },
--         { multiple = { 1001.03, 1001.03 },                    desc = "M-978 Tanker - All crates",        side = 2 },
--         --- RED
--         { weight = 1001.11,                                   desc = "SKP-11 - JTAC",                    unit = "SKP-11",               side = 1 },
--         { weight = 1001.12,                                   desc = "Ural-375 Ammo Truck",              unit = "Ural-375",             side = 1, cratesRequired = 2 },
--         { multiple = { 1001.12, 1001.12 },                    desc = "Ural-375 Ammo Truck - All crates", side = 1 },
--         { weight = 1001.13,                                   desc = "KAMAZ Ammo Truck",                 unit = "KAMAZ Truck",          side = 1, cratesRequired = 2 },
--         --- Both
--         { weight = 1001.21,                                   desc = "EWR Radar",                        unit = "FPS-117",              cratesRequired = 3 },
--         { multiple = { 1001.21, 1001.21, 1001.21 },           desc = "EWR Radar - All crates" },
--         { weight = 1001.22,                                   desc = "FOB Crate",                        unit = "FOB",          side = nil, cratesRequired = 3 },
--     },
--
--     ["Artillery"] = {
--         --- BLUE
--         { weight = 1002.01,                                   desc = "MLRS",                       unit = "MLRS",         side = 2, cratesRequired = 3 },
--         { multiple = { 1002.01, 1002.01, 1002.01 },           desc = "MLRS - All crates",          side = 2 },
--         { weight = 1002.02,                                   desc = "SpGH DANA",                  unit = "SpGH_Dana",    side = 2, cratesRequired = 3 },
--         { multiple = { 1002.02, 1002.02, 1002.02 },           desc = "SpGH DANA - All crates",     side = 2 },
--         { weight = 1002.03,                                   desc = "T155 Firtina",               unit = "T155_Firtina", side = 2, cratesRequired = 3 },
--         { multiple = { 1002.03, 1002.03, 1002.03 },           desc = "T155 Firtina - All crates",  side = 2 },
--         { weight = 1002.04,                                   desc = "Howitzer M-109",             unit = "M-109",        side = 2, cratesRequired = 3 },
--         { multiple = { 1002.04, 1002.04, 1002.04 },           desc = "Howitzer M-109 - All crates", side = 2 },
--         --- RED
--         { weight = 1002.11,                                   desc = "SPH 2S19 Msta",              unit = "SAU Msta",     side = 1, cratesRequired = 3 },
--         { multiple = { 1002.11, 1002.11, 1002.11 },           desc = "SPH 2S19 Msta - All crates", side = 1 },
--     },
--
--     ["SAM short range"] = {
--         --- BLUE
--         { weight = 1003.01,                                   desc = "M1097 Avenger",              unit = "M1097 Avenger",       side = 2, cratesRequired = 3 },
--         { multiple = { 1003.01, 1003.01, 1003.01 },           desc = "M1097 Avenger - All crates", side = 2 },
--         { weight = 1003.02,                                   desc = "M48 Chaparral",              unit = "M48 Chaparral",       side = 2, cratesRequired = 2 },
--         { multiple = { 1003.02, 1003.02 },                    desc = "M48 Chaparral - All crates", side = 2 },
--         { weight = 1003.03,                                   desc = "Roland ADS",                 unit = "Roland ADS",          side = 2, cratesRequired = 3 },
--         { multiple = { 1003.03, 1003.03, 1003.03 },           desc = "Roland ADS - All crates",    side = 2 },
--         { weight = 1003.04,                                   desc = "Gepard AAA",                 unit = "Gepard",              side = 2, cratesRequired = 3 },
--         { multiple = { 1003.04, 1003.04, 1003.04 },           desc = "Gepard AAA - All crates",    side = 2 },
--         { weight = 1003.05,                                   desc = "LPWS C-RAM",                 unit = "HEMTT_C-RAM_Phalanx", side = 2, cratesRequired = 3 },
--         { multiple = { 1003.05, 1003.05, 1003.05 },           desc = "LPWS C-RAM - All crates",    side = 2 },
--         --- RED
--         { weight = 1003.11,                                   desc = "9K33 Osa",                   unit = "Osa 9A33 ln",         side = 1, cratesRequired = 3 },
--         { multiple = { 1003.11, 1003.11, 1003.11 },           desc = "9K33 Osa - All crates",      side = 1 },
--         { weight = 1003.12,                                   desc = "9P31 Strela-1",              unit = "Strela-1 9P31",       side = 1, cratesRequired = 3 },
--         { multiple = { 1003.12, 1003.12, 1003.12 },           desc = "9P31 Strela-1 - All crates", side = 1 },
--         { weight = 1003.13,                                   desc = "9K35M Strela-10",            unit = "Strela-10M3",         side = 1, cratesRequired = 3 },
--         { multiple = { 1003.13, 1003.13, 1003.13 },           desc = "9K35M Strela-10 - All crates", side = 1 },
--         { weight = 1003.14,                                   desc = "9K331 Tor",                  unit = "Tor 9A331",           side = 1, cratesRequired = 3 },
--         { multiple = { 1003.14, 1003.14, 1003.14 },           desc = "9K331 Tor - All crates",     side = 1 },
--         { weight = 1003.15,                                   desc = "2K22 Tunguska",              unit = "2S6 Tunguska",        side = 1, cratesRequired = 3 },
--         { multiple = { 1003.15, 1003.15, 1003.15 },           desc = "2K22 Tunguska - All crates", side = 1 },
--     },
--
--     ["SAM mid range"] = {
--         --- BLUE — HAWK system
--         { weight = 1004.01,                                   desc = "HAWK Launcher",               unit = "Hawk ln",              side = 2 },
--         { weight = 1004.02,                                   desc = "HAWK Search Radar",           unit = "Hawk sr",              side = 2 },
--         { weight = 1004.03,                                   desc = "HAWK Track Radar",            unit = "Hawk tr",              side = 2 },
--         { weight = 1004.04,                                   desc = "HAWK PCP",                   unit = "Hawk pcp",             side = 2 },
--         { weight = 1004.05,                                   desc = "HAWK CWAR",                  unit = "Hawk cwar",            side = 2 },
--         { weight = 1004.06,                                   desc = "HAWK Repair",                unit = "HAWK Repair",          side = 2 },
--         { multiple = { 1004.01, 1004.02, 1004.03 },           desc = "HAWK - All crates",           side = 2 },
--         --- BLUE — NASAMS system
--         { weight = 1004.11,                                   desc = "NASAMS Launcher 120C",        unit = "NASAMS_LN_C",          side = 2 },
--         { weight = 1004.12,                                   desc = "NASAMS Search/Track Radar",   unit = "NASAMS_Radar_MPQ64F1", side = 2 },
--         { weight = 1004.13,                                   desc = "NASAMS Command Post",         unit = "NASAMS_Command_Post",  side = 2 },
--         { weight = 1004.14,                                   desc = "NASAMS Repair",              unit = "NASAMS Repair",        side = 2 },
--         { multiple = { 1004.11, 1004.12, 1004.13 },           desc = "NASAMS - All crates",         side = 2 },
--         --- RED — KUB system
--         { weight = 1004.21,                                   desc = "KUB Launcher",               unit = "Kub 2P25 ln",          side = 1 },
--         { weight = 1004.22,                                   desc = "KUB Radar",                  unit = "Kub 1S91 str",         side = 1 },
--         { weight = 1004.23,                                   desc = "KUB Repair",                 unit = "KUB Repair",           side = 1 },
--         { multiple = { 1004.21, 1004.22 },                    desc = "KUB - All crates",            side = 1 },
--         --- RED — BUK system
--         { weight = 1004.31,                                   desc = "BUK Launcher",               unit = "SA-11 Buk LN 9A310M1", side = 1 },
--         { weight = 1004.32,                                   desc = "BUK Search Radar",           unit = "SA-11 Buk SR 9S18M1",  side = 1 },
--         { weight = 1004.33,                                   desc = "BUK CC Radar",               unit = "SA-11 Buk CC 9S470M1", side = 1 },
--         { weight = 1004.34,                                   desc = "BUK Repair",                 unit = "BUK Repair",           side = 1 },
--         { multiple = { 1004.31, 1004.32, 1004.33 },           desc = "BUK - All crates",            side = 1 },
--     },
--
--     ["SAM long range"] = {
--         --- BLUE — Patriot system
--         { weight = 1005.01,                                   desc = "Patriot Launcher",            unit = "Patriot ln",        side = 2 },
--         { weight = 1005.02,                                   desc = "Patriot Radar",               unit = "Patriot str",       side = 2 },
--         { weight = 1005.03,                                   desc = "Patriot ECS",                 unit = "Patriot ECS",       side = 2 },
--         { weight = 1005.06,                                   desc = "Patriot AMG (optional)",      unit = "Patriot AMG",       side = 2 },
--         { weight = 1005.07,                                   desc = "Patriot Repair",              unit = "Patriot Repair",    side = 2 },
--         { multiple = { 1005.01, 1005.02, 1005.03 },           desc = "Patriot - All crates",        side = 2 },
--         --- RED — S-300 system
--         { weight = 1005.11,                                   desc = "S-300 TEL C",                 unit = "S-300PS 5P85C ln",  side = 1 },
--         { weight = 1005.12,                                   desc = "S-300 Flap Lid-A TR",         unit = "S-300PS 40B6M tr",  side = 1 },
--         { weight = 1005.13,                                   desc = "S-300 Clam Shell SR",         unit = "S-300PS 40B6MD sr", side = 1 },
--         { weight = 1005.14,                                   desc = "S-300 Big Bird SR",           unit = "S-300PS 64H6E sr",  side = 1 },
--         { weight = 1005.15,                                   desc = "S-300 C2",                    unit = "S-300PS 54K6 cp",   side = 1 },
--         { weight = 1005.16,                                   desc = "S-300 Repair",                unit = "S-300 Repair",      side = 1 },
--         { multiple = { 1005.11, 1005.12, 1005.13, 1005.14, 1005.15 }, desc = "S-300 - All crates", side = 1 },
--     },
--
--     ["Drone"] = {
--         --- BLUE
--         { weight = 1006.01,                                   desc = "MQ-9 Reaper - JTAC",         unit = "MQ-9 Reaper",    side = 2 },
--         --- RED
--         { weight = 1006.11,                                   desc = "RQ-1A Predator - JTAC",      unit = "RQ-1A Predator", side = 1 },
--     },
-- }

-- ============================================================
-- Crate 3D model templates
-- Controls which DCS static object model is spawned for each
-- crate usage type.
--
-- Three slots:
--   "load"    : crate spawned for standard hover / menu loading
--               (canCargo = false : not a real DCS slingload cargo)
--   "sling"   : crate spawned when ctld.slingLoad = true
--               (canCargo = true  : DCS native cargo physics)
--   "dynamic" : crate spawned when the aircraft is in dynamicCargoUnits
--               (canCargo = true  : DCS native cargo physics)
--
-- Available DCS cargo models and their type strings:
--   model shape               | type
--   ─────────────────────────────────────────────────────────
--   ammo_box_cargo            | ammo_cargo         (default load)
--   bw_container_cargo        | container_cargo    (default sling)
--   iso_container_cargo       | iso_container
--   iso_container_small_cargo | iso_container_small
--   ab-212_cargo              | uh1h_cargo
--   barrels_cargo             | barrels_cargo
--   fueltank_cargo            | fueltank_cargo
--   oiltank_cargo             | oiltank_cargo
--   pipes_big_cargo           | pipes_big_cargo
--   pipes_small_cargo         | pipes_small_cargo
--   tetrapod_cargo            | tetrapod_cargo
--   trunks_long_cargo         | trunks_long_cargo
--   trunks_small_cargo        | trunks_small_cargo
--   f_bar_cargo               | f_bar_cargo
-- ============================================================
-- _cfg.settings["spawnableCratesModels"] = {
--     ["load"] = {
--         category   = "Cargos",
--         type       = "ammo_cargo",
--         canCargo   = false,
--     },
--     ["sling"] = {
--         category   = "Cargos",
--         shape_name = "bw_container_cargo",
--         type       = "container_cargo",
--         canCargo   = true,
--     },
--     ["dynamic"] = {
--         category   = "Cargos",
--         type       = "ammo_cargo",
--         canCargo   = true,
--     },
-- }

-- ============================================================
-- AUTO-START
-- Boots all CTLD singletons after config is applied.
-- Set ctld.dontInitialize = true in your mission script BEFORE
-- loading CTLD_Next.lua if you need to call ctld.initialize()
-- manually (e.g. to run additional setup between loading and starting).
-- ============================================================

---@diagnostic disable-next-line: lowercase-global
function ctld.initialize()
    CTLDConfig.get():load()
    ctld.utils.initLog()

    -- Boot all domain managers first so they can register their menu sections.
    -- Order matters: PlayerManager must be up before any other manager calls
    -- registerMenuSection(), and _scanExistingPlayers() must run last so all
    -- sections are registered before menus are built for pre-existing players.
    CTLDPlayerManager.getInstance()   -- creates _menuSections registry
    CTLDZoneManager.getInstance()
    CTLDTroopManager.getInstance()    -- registers "troops" section
    CTLDCrateManager.getInstance()    -- registers "crates" + "smoke" sections
    CTLDVehicleSpawner.getInstance()  -- registers "vehicles" section
    CTLDFOBManager.getInstance()
    CTLDBeaconManager.getInstance()   -- registers "beacons" section
    CTLDReconManager.getInstance()    -- registers "recon" section
    CTLDJTACManager.getInstance()             -- registers "jtac" section
    CTLDCrateAssemblyManager.getInstance()
    CTLDCoreManager.getInstance()     -- INIT-B (MM crates) + INIT-C (MM JTACs)

    -- Now that all sections are registered, build menus for any player
    -- already in a slot (no retroactive S_EVENT_PLAYER_ENTER_UNIT).
    CTLDPlayerManager.getInstance():_scanExistingPlayers()

    ctld.utils.log("INFO", "CTLD initialized.")
end

if ctld.dontInitialize then
    ctld.utils.log("INFO", "CTLD auto-start skipped (ctld.dontInitialize=true). Call ctld.initialize() manually.")
else
    ctld.initialize()
end
