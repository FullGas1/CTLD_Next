-- CTLDConfig Singleton Class
-- src version — do not edit source/ original
ctld = ctld or {}

ctld.VERSION = "2.0.0"

CTLDConfig = {}
CTLDConfig._instance = nil

-- Get the unique instance of the config
function CTLDConfig.get()
    if CTLDConfig._instance == nil then
        CTLDConfig._instance = setmetatable({}, { __index = CTLDConfig })
        CTLDConfig._instance.settings = {}
        CTLDConfig._instance.isLoaded = false
    end
    return CTLDConfig._instance
end

-- Load settings from the text file
function CTLDConfig:load()
    if self.isLoaded then
        return true, "CTLDConfig: Configuration already loaded."
    end
    self.isLoaded                                       = true

    -- ****************************************************************
    -- ******************** DEFAULT CONFIGURATION AREA ****************
    -- ****************************************************************

    -- ═══════════════════════════════════════════════════════════
    -- [1] SYSTEM — Global switches and display options
    -- ═══════════════════════════════════════════════════════════
    self.settings["debug"]                              = false -- if true, enables verbose logging to CTLD.log (requires non-sanitized DCS)
    self.settings["ctldLogPath"]                        = ""    -- override log file path (default: DCS Saved Games folder); empty = default
    self.settings["debugScreenLog"]                     = false -- if true, ctld.utils.log() also echoes to DCS screen via outText
    self.settings["debugScreenLogDuration"]             = 10    -- seconds each screen log message is displayed (requires debugScreenLog=true)
    self.settings["disableAllSmoke"]                    = false -- if true, all smoke is diabled at pickup and drop off zones regardless of settings below. Leave false to respect settings below
    self.settings["location_DMS"]                       = false -- shows coordinates as Degrees Minutes Seconds instead of Degrees Decimal minutes

    -- ═══════════════════════════════════════════════════════════
    -- [2] TRANSPORTS — Aircraft types and pilot names
    -- ═══════════════════════════════════════════════════════════

    -- If true (default): any player in a type listed in capabilitiesByType gets CTLD menus.
    -- If false: only unit names explicitly listed in transportPilotNames get CTLD menus.
    --           Use this to restrict CTLD to a fixed set of named slots in a controlled mission.
    self.settings["addPlayerAircraftByType"]            = true

    -- Use any of the predefined names or set your own ones
    self.settings["transportPilotNames"]                = {
        "helicargo1",
        "helicargo2",
        "helicargo3",
        "helicargo4",
        "helicargo5",
        "helicargo6",
        "helicargo7",
        "helicargo8",
        "helicargo9",
        "helicargo10",

        "helicargo11",
        "helicargo12",
        "helicargo13",
        "helicargo14",
        "helicargo15",
        "helicargo16",
        "helicargo17",
        "helicargo18",
        "helicargo19",
        "helicargo20",

        "helicargo21",
        "helicargo22",
        "helicargo23",
        "helicargo24",
        "helicargo25",

        "MEDEVAC #1",
        "MEDEVAC #2",
        "MEDEVAC #3",
        "MEDEVAC #4",
        "MEDEVAC #5",
        "MEDEVAC #6",
        "MEDEVAC #7",
        "MEDEVAC #8",
        "MEDEVAC #9",
        "MEDEVAC #10",
        "MEDEVAC #11",
        "MEDEVAC #12",
        "MEDEVAC #13",
        "MEDEVAC #14",
        "MEDEVAC #15",
        "MEDEVAC #16",

        "MEDEVAC RED #1",
        "MEDEVAC RED #2",
        "MEDEVAC RED #3",
        "MEDEVAC RED #4",
        "MEDEVAC RED #5",
        "MEDEVAC RED #6",
        "MEDEVAC RED #7",
        "MEDEVAC RED #8",
        "MEDEVAC RED #9",
        "MEDEVAC RED #10",
        "MEDEVAC RED #11",
        "MEDEVAC RED #12",
        "MEDEVAC RED #13",
        "MEDEVAC RED #14",
        "MEDEVAC RED #15",
        "MEDEVAC RED #16",
        "MEDEVAC RED #17",
        "MEDEVAC RED #18",
        "MEDEVAC RED #19",
        "MEDEVAC RED #20",
        "MEDEVAC RED #21",

        "MEDEVAC BLUE #1",
        "MEDEVAC BLUE #2",
        "MEDEVAC BLUE #3",
        "MEDEVAC BLUE #4",
        "MEDEVAC BLUE #5",
        "MEDEVAC BLUE #6",
        "MEDEVAC BLUE #7",
        "MEDEVAC BLUE #8",
        "MEDEVAC BLUE #9",
        "MEDEVAC BLUE #10",
        "MEDEVAC BLUE #11",
        "MEDEVAC BLUE #12",
        "MEDEVAC BLUE #13",
        "MEDEVAC BLUE #14",
        "MEDEVAC BLUE #15",
        "MEDEVAC BLUE #16",
        "MEDEVAC BLUE #17",
        "MEDEVAC BLUE #18",
        "MEDEVAC BLUE #19",
        "MEDEVAC BLUE #20",
        "MEDEVAC BLUE #21",

        -- *** AI transports names (different names only to ease identification in mission) ***

        -- Use any of the predefined names or set your own ones
        "transport1",
        "transport2",
        "transport3",
        "transport4",
        "transport5",
        "transport6",
        "transport7",
        "transport8",
        "transport9",
        "transport10",

        "transport11",
        "transport12",
        "transport13",
        "transport14",
        "transport15",
        "transport16",
        "transport17",
        "transport18",
        "transport19",
        "transport20",

        "transport21",
        "transport22",
        "transport23",
        "transport24",
        "transport25",
    }

    -- ═══════════════════════════════════════════════════════════
    -- [3] CRATES — Crate spawning, hover pickup, sling load, timers
    -- ═══════════════════════════════════════════════════════════
    self.settings["enableCrates"]                       = true  -- if false, Helis will not be able to spawn or unpack crates so will be normal CTTS
    self.settings["enableAllCrates"]                    = true  -- if false, the "all crates" menu items will not be displayed
    self.settings["enableHoverSlingload"]               = true  -- if false, hover-based slingload pickup is disabled; crates can still be loaded via F10 menu (loadCrateFromMenu)
    self.settings["loadCrateFromMenu"]                  = true  -- if set to true, you can load crates with the F10 menu OR hovering, in case of using choppers and planes for example.
    self.settings["slingLoad"]                          = false -- if false, crates can be used WITHOUT slingloading, by hovering above the crate, simulating slingloading but not the weight...
    -- There are some bug with Sling-loading that can cause crashes, if these occur set slingLoad to false
    -- to use the other method.
    -- Set staticBugFix    to FALSE if use set ctld.slingLoad to TRUE
    self.settings["enableSmokeDrop"]                    = true -- if false, helis and c-130 will not be able to drop smoke
    self.settings["smokeAutoResume"]                    = false -- Feature H: global default for smoke auto-resume (per-player toggle overrides)
    self.settings["smokeAutoResumeInterval"]            = 270  -- Feature H: seconds before a smoke is re-triggered (default 4min30, DCS smoke lasts ~5min)
    self.settings["maximumDistanceLogistic"]            = 200  -- max distance from vehicle to logistics to allow a loading or spawning operation
    self.settings["groundAglThreshold"]                 = 5.0  -- AGL (m) below which a stationary aircraft is considered on the ground.
                                                                -- Handles high-chassis types (e.g. CH-47) whose unit:inAir() returns true
                                                                -- even when fully at rest.  Combined with a near-zero velocity check.
    self.settings["crateSpacing"]                       = 5    -- spacing (m) between consecutive crate spawn positions along the drop axis
    self.settings["spawnDistanceInCircle"]              = 10   -- extra radius (m) added to safe-radius when placing units in circle formation on deploy

    -- Simulated Sling load configuration (Feature B)
    self.settings["minimumHoverHeight"]                 = 7.5  -- Lowest allowable height for crate hover
    self.settings["maximumHoverHeight"]                 = 12.0 -- Highest allowable height for crate hover
    self.settings["maxDistanceFromCrate"]               = 5.5  -- Maximum distance from from crate for hover
    self.settings["hoverTime"]                          = 10   -- Time to hold hover above a crate for loading in seconds
    self.settings["maxSlingloadSpeed"]                  = 50   -- Max speed (m/s) while carrying a slingloaded crate — exceed it and the crate is lost
    self.settings["maxDropHeight"]                      = 7.5  -- max altitude AGL (m) for a safe crate drop; above this the crate is destroyed on impact
    -- end of Simulated Sling load configuration

    -- ═══════════════════════════════════════════════════════════
    -- [4] TROOPS — Infantry loading, fast rope, extraction limits
    -- ═══════════════════════════════════════════════════════════
    self.settings["numberOfTroops"]                     = 10       -- default number of troops to load on a transport heli or C-130
    self.settings["maxTransportWeight"]                 = 0        -- max cargo weight (kg) per transport; 0 = unlimited
    -- multiGroupTransport removed: multiple groups always allowed up to transport capacity.
    self.settings["enableFastRopeInsertion"]            = true     -- allows you to drop troops by fast rope
    self.settings["fastRopeMaximumHeight"]              = 18.28    -- in meters which is 60 ft max fast rope (not rappell) safe height
    self.settings["allowRandomAiTeamPickups"]           = false    -- Allows the AI to randomize the loading of infantry teams (specified below) at pickup zones
    -- Feature S: AI zones declared by config (no naming convention).
    -- Each entry: { dcsZoneName, coalition, isPickup, isDropoff, cargoType,
    --              troopStock, troopTemplates, vehicleTypes, aiDropMode }
    -- troopStock: 0=disabled, -1=unlimited, N=limited stock
    -- troopTemplates: nil/{}=all templates ; {"Name1","Name2"}=strict whitelist
    -- vehicleTypes: nil=all DCS vehicles in zone ; {"typeName1",...}=whitelist
    -- aiDropMode: "G"|"P"|"GP" (default "GP") — dropoff only
    self.settings["aiZones"]                           = self.settings["aiZones"] or {}
    -- Limit the dropping of infantry teams -- this limit control is inactive if ctld.nbLimitSpawnedTroops = {0, 0} ----
    self.settings["nbLimitSpawnedTroops"]               = { 0, 0 } -- {redLimitInfantryCount, blueLimitInfantryCount} when this cumulative number of troops is reached, no more troops can be loaded onboard
    self.settings["maxExtractDistance"]                 = 125      -- max distance from vehicle to troops to allow a group extraction
    self.settings["maximumSearchDistance"]              = 3000     -- max distance for troops to search for enemy

    -- ═══════════════════════════════════════════════════════════
    -- [5] VEHICLES — Packable vehicles and transport configuration
    -- ═══════════════════════════════════════════════════════════
    self.settings["enablePackingVehicles"]              = true  -- if true, vehicles can be packed into crates
    self.settings["maximumDistancePackableUnitsSearch"] = 200   -- max distance from transportUnit to search for packable units in meters
    self.settings["groundVehicleWeights"]               = {
        -- Weights (kg) used to check helicopter sling-load capacity against maxVehicleWeight.
        -- Values are rounded real-world unloaded masses; combat loads intentionally excluded
        -- so that mission makers can adjust maxVehicleWeight per helicopter for gameplay balance.
        ["BRDM-2"]              = 7000,  -- real ~7500 kg; rounded down, only liftable by Mi-26/CH-47 class
        ["BTR_D"]               = 8000,  -- real ~8200 kg; same category
        ["M1045 HMMWV TOW"]     = 5000,  -- M1045A2 combat-ready with TOW launcher, crew, ammo ~4600-5000 kg; 5 crates required
        ["M1043 HMMWV Armament"]= 2500,  -- M1043 with .50 cal ~2500 kg unloaded
        ["Hummer"]              = 2400,  -- M998 HMMWV unloaded ~2359 kg; rounded to 2400 (exceeds UH-1H limit of 1360 kg by design)
    }

    -- ═══════════════════════════════════════════════════════════
    -- [6] FOB — Forward Operating Base building and configuration
    -- ═══════════════════════════════════════════════════════════
    self.settings["enabledFOBBuilding"]                 = true -- if true, you can load a crate INTO a C-130 than when unpacked creates a Forward Operating Base (FOB) which is a new place to spawn (crates) and carry crates from
    -- In future i'd like it to be a FARP but so far that seems impossible...
    -- You can also enable troop Pickup at FOBS
    self.settings["troopPickupAtFOB"]                   = true -- if true, troops can also be picked up at a created FOB
    self.settings["fobMinDistanceFromZones"]            = 500  -- minimum distance (m) from existing logistic zones to deploy a FOB
    self.settings["fobLogisticZoneRadius"]              = 150  -- radius (m) of the logistic zone created around a deployed FOB
    self.settings["fobDestructionThreshold"]            = 0.5  -- fraction of scene objects destroyed before FOB is considered lost (0.0–1.0)
    self.settings["fobTroopPickupRadius"]               = 150  -- radius (m) within which troops can be picked up at a FOB (troopPickupAtFOB)
    self.settings["enableFARPRepack"]                   = true  -- if true, players can pack deployed FARP scenes back into crates to redeploy elsewhere


    -- ═══════════════════════════════════════════════════════════
    -- [FA] PARACHUTE — Virtual parachute drop (Feature A)
    -- ═══════════════════════════════════════════════════════════
    -- Minimum altitude AGL (m) required to initiate a parachute drop.
    self.settings["parachuteMinAltitudeCrates"]           = 152  -- m AGL (≈ 500 ft)
    self.settings["parachuteMinAltitudeTroops"]           = 152  -- m AGL (≈ 500 ft)
    self.settings["parachuteMinAltitudeVehicles"]         = 152  -- m AGL (≈ 500 ft)
    -- Vertical descent speed (m/s) — determines time-to-ground.
    self.settings["parachuteDescentRateCrates"]           = 5    -- m/s
    self.settings["parachuteDescentRateTroops"]           = 5    -- m/s
    self.settings["parachuteDescentRateVehicles"]         = 8    -- m/s (heavier load)
    -- Horizontal drift physics.
    self.settings["parachuteInertiaFactor"]               = 0.3  -- fraction of transport velocity applied as forward drift (0.0–1.0)
    self.settings["parachuteLateralDriftMin"]             = 10   -- m, minimum random lateral drift per unit
    self.settings["parachuteLateralDriftMax"]             = 80   -- m, maximum random lateral drift per unit
    -- Auto-unpack radius for parachuted crates (wider than normal because of dispersion).
    self.settings["autoUnpackRadiusParachute"]            = 1000 -- m

    -- ═══════════════════════════════════════════════════════════
    -- [7] BEACONS — Radio beacon drop, sounds and battery life
    -- ═══════════════════════════════════════════════════════════
    self.settings["enabledRadioBeaconDrop"]               = true  -- if its set to false then beacons cannot be dropped by units
    self.settings["radioSound"]                           =
    "beacon.ogg"                                                  -- the name of the sound file to use for the FOB radio beacons. If this isnt added to the mission BEACONS WONT WORK!
    self.settings["radioSoundFC3"]                        =
    "beaconsilent.ogg"                                            -- name of the second silent radio file, used so FC3 aircraft dont hear ALL the beacon noises... :)
    self.settings["deployedBeaconBattery"]                = 30   -- the battery on deployed beacons will last for this number minutes before needing to be re-deployed
    -- Beacon F10 layer options
    self.settings["beaconLayerEnabled"]                   = false                -- if true, beacon positions are drawn on the F10 map as icons
    self.settings["beaconAutoRefreshLayer"]               = false                -- if true, newly-dropped beacons are auto-added to active layer
    self.settings["beaconRefreshInterval"]                = 60                   -- seconds between beacon layer refreshes
    self.settings["beaconIconRadius"]                     = 25                   -- radius (m) of beacon icon circles on the F10 map
    self.settings["beaconIconColor"]                      = { 1.0, 0.5, 0.0, 1.0 } -- RGBA color of beacon icon (default: orange)
    self.settings["beaconTextSize"]                       = 12                   -- font size of beacon name/coords text on the F10 map

    -- ═══════════════════════════════════════════════════════════
    -- [8] AA — Anti-Aircraft system limits and crate stacking
    -- ═══════════════════════════════════════════════════════════
    self.settings["aaLaunchers"]                          = 3 -- controls how many launchers to add to the AA systems when its spawned if no amount is specified in the template.
    -- Sets a limit on the number of active AA systems that can be built for RED.
    -- A system is counted as Active if its fully functional and has all parts
    -- If a system is partially destroyed, it no longer counts towards the total
    -- When this limit is hit, a player will still be able to get crates for an AA system, just unable
    -- to unpack them
    self.settings["AASystemLimitRED"]                     = 20 -- Red side limit
    self.settings["AASystemLimitBLUE"]                    = 20 -- Blue side limit

    -- Allows players to create systems using as many crates as they like
    -- Example : an amount X of patriot launcher crates allows for Y launchers to be deployed, if a player brings 2*X+Z crates (Z being lower then X), then deploys the patriot site, 2*Y launchers will be in the group and Z launcher crate will be left over
    self.settings["AASystemCrateStacking"]                = false
    --END AA SYSTEM CONFIG ------------------------------------

    -- ═══════════════════════════════════════════════════════════
    -- [9] JTAC — JTAC crate limits, smoke, lasing and 9-Line
    -- ═══════════════════════════════════════════════════════════
    self.settings["JTAC_LIMIT_RED"]                       = 10    -- max number of JTAC Crates for the RED Side
    self.settings["JTAC_LIMIT_BLUE"]                      = 10    -- max number of JTAC Crates for the BLUE Side
    self.settings["JTAC_dropEnabled"]                     = true  -- allow JTAC Crate spawn from F10 menu
    self.settings["JTAC_maxDistance"]                     = 10000 -- How far a JTAC can "see" in meters (with Line of Sight)
    self.settings["JTAC_smokeOn_RED"]                     = false -- enables marking of target with smoke for RED forces
    self.settings["JTAC_smokeOn_BLUE"]                    = false -- enables marking of target with smoke for BLUE forces
    self.settings["JTAC_smokeColour_RED"]                 = 4     -- RED side smoke colour -- Green = 0 , Red = 1, White = 2, Orange = 3, Blue = 4
    self.settings["JTAC_smokeColour_BLUE"]                = 1     -- BLUE side smoke colour -- Green = 0 , Red = 1, White = 2, Orange = 3, Blue = 4
    self.settings["JTAC_smokeMarginOfError"]              = 50    -- error that the JTAC is allowed to make when popping a smoke (in meters)
    self.settings["JTAC_smokeOffset_x"]                   = 0.0   -- distance in the X direction from target to smoke (meters)
    self.settings["JTAC_smokeOffset_y"]                   = 2.0   -- distance in the Y direction from target to smoke (meters)
    self.settings["JTAC_smokeOffset_z"]                   = 0.0   -- distance in the z direction from target to smoke (meters)
    self.settings["JTAC_jtacStatusF10"]                   = true  -- enables F10 JTAC Status menu
    self.settings["JTAC_location"]                        = true  -- shows location of target in JTAC message
    self.settings["location_DMS"]                         = false -- shows coordinates as Degrees Minutes Seconds instead of Degrees Decimal minutes
    self.settings["JTAC_lock"]                            =
    "all"                                                         -- "vehicle" OR "troop" OR "all" forces JTAC to only lock vehicles or troops or all ground units
    self.settings["JTAC_allowStandbyMode"]                = true  -- if true, allow players to toggle lasing on/off
    self.settings["JTAC_laseSpotCorrections"]             = true  -- if true, each JTAC will have a special option (toggle on/off) available in it's menu to attempt to lead the target, taking into account current wind conditions and the speed of the target (particularily useful against moving heavy armor)
    self.settings["JTAC_allowSmokeRequest"]               = true  -- if true, allow players to request a smoke on target (temporary)
    self.settings["JTAC_allow9Line"]                      = true  -- if true, allow players to ask for a 9Line (individual) for a specific JTAC's target
    self.settings["JTAC_laseIntervalSeconds"]             = 15    -- auto-lase loop reschedule delay (s) when actively lasing a target
    self.settings["JTAC_searchIntervalSeconds"]           = 10    -- auto-lase loop reschedule delay (s) when searching for a target (no target acquired)
    self.settings["JTAC_targetDeconfliction"]             = true  -- prevent multiple JTACs from lasing the same target simultaneously
    self.settings["enableAutoOrbitingFlyingJtacOnTarget"] = true  -- if true, flying JTAC drones auto-orbit detected targets

    -- JTAC role is declared via isJTAC=true in spawnableCrates descriptors (no separate type list).
    -- The "Request JTAC Equipment" F10 menu is auto-populated from those same descriptors —
    -- no separate JTAC_unitTypeNames table is needed.
    self.settings["JTAC_droneRadius"]                     = 1000 -- fallback orbit radius (m) when crate specificParams absent
    self.settings["JTAC_droneAltitude"]                   = 4000 -- fallback orbit altitude AGL (m) when crate specificParams absent

    -- ═══════════════════════════════════════════════════════════
    -- [10] RECON — Recon menu, LOS search, auto-refresh
    -- ═══════════════════════════════════════════════════════════
    self.settings["reconF10Menu"]                         = true  -- enable RECON submenu in F10 CTLD menu
    self.settings["reconEnabled"]                         = false -- master switch: set to true to activate RECON functionality
    self.settings["reconSearchRadius"]                    = 5000  -- LOS detection radius (m) around the scanning unit
    self.settings["reconMinAltitude"]                     = 50    -- minimum AGL altitude (m) required to perform a scan
    self.settings["reconRefreshInterval"]                 = 10    -- auto-refresh interval (s) between target position updates
    self.settings["reconIconScale"]                       = 1.0   -- icon size multiplier (1.0 = default sizes; increase for larger icons)

    -- ═══════════════════════════════════════════════════════════
    -- [M10] MINEFIELD — Landmine deployment options
    -- ═══════════════════════════════════════════════════════════
    self.settings["showMinefieldOnF10Map"]                = true  -- if true, draws a bounding quad on the F10 map when a minefield is deployed
    self.settings["demineRadius"]                         = 150   -- max distance (m) from player to minefield center for the "Clear Mine Field" menu to appear

    -- ═══════════════════════════════════════════════════════════
    -- [11] ZONES — Pickup, drop-off and waypoint zones
    -- ═══════════════════════════════════════════════════════════
    self.settings["dynamicZoneRadius"]                    = 200  -- radius (m) of logistic zones created around LGZ_ trigger zones
    self.settings["smokeRefreshInterval"]                 = 300  -- seconds between smoke signal refreshes at logistic/troop zones
    self.settings["logisticZoneSmokeColor"]               = nil  -- optional: table [coalition_id] = smokeColor — nil disables zone smoke
    self.settings["troopZoneSmokeColor"]                  = nil  -- optional: table [coalition_id] = smokeColor — nil disables troop zone smoke

    -- Available colors (anything else like "none" disables smoke): "green", "red", "white", "orange", "blue", "none",
    -- Player troop pickup zones (players only — AI transports use AIZones instead).
    -- You can add number as a third option to limit the number of soldier groups that can be loaded.
    -- Dropping back a group at a limited zone will restore one to the limit.
    -- If a zone isn't ACTIVE then you can't pickup from that zone until activated via ctld.activatePickupZone.
    -- You can pickup from a SHIP by adding the SHIP UNIT NAME instead of a zone name.
    -- Side - Controls which coalition can load/unload troops at the zone.
    -- Flag Number - Optional last field: mirrors the current stock count to a DCS flag.
    --troopZones = { "Zone name or Ship Unit Name", "smoke color", "limit (-1 unlimited)", "ACTIVE (yes/no)", "side (0=Both / 1=Red / 2=Blue)", flag number (optional) }
    self.settings["troopZones"]                           = {
        { "pickzone1",   "blue", -1, "yes", 0 },
        { "pickzone2",   "red",  -1, "yes", 0 },
        { "pickzone3",   "none", -1, "yes", 0 },
        { "pickzone4",   "none", -1, "yes", 0 },
        { "pickzone5",   "none", -1, "yes", 0 },
        { "pickzone6",   "none", -1, "yes", 0 },
        { "pickzone7",   "none", -1, "yes", 0 },
        { "pickzone8",   "none", -1, "yes", 0 },
        { "pickzone9",   "none", 5,  "yes", 1 }, -- limits pickup zone 9 to 5 groups, RED only
        { "pickzone10",  "none", 10, "yes", 2 }, -- limits pickup zone 10 to 10 groups, BLUE only

        { "pickzone11",  "blue", 20, "no",  2 }, -- starts inactive, BLUE only
        { "pickzone12",  "red",  20, "no",  1 }, -- starts inactive, RED only
        { "pickzone13",  "none", -1, "yes", 0 },
        { "pickzone14",  "none", -1, "yes", 0 },
        { "pickzone15",  "none", -1, "yes", 0 },
        { "pickzone16",  "none", -1, "yes", 0 },
        { "pickzone17",  "none", -1, "yes", 0 },
        { "pickzone18",  "none", -1, "yes", 0 },
        { "pickzone19",  "none", 5,  "yes", 0 },
        { "pickzone20",  "none", 10, "yes", 0, 1000 }, -- remaining count mirrored to flag 1000

        { "USA Carrier", "blue", 10, "yes", 0, 1001 }, -- ship: use DCS unit name
    }

    -- AI-only zones (not visible to player menus).
    -- role "P" = AI pickup ; role "D" = AI dropoff
    -- stock     : integer or -1=unlimited (required for "P", ignored for "D")
    -- drop mode : "G"=ground only, "P"=parachute only, "GP"=both (optional, "D" only, default "GP")
    -- AIZones = { "zone_name", "smoke_color", side, role, stock_or_dropmode }
    self.settings["AIZones"]                              = {
        { "aizone1",  "none", 2, "P", -1    }, -- AI pickup BLUE, unlimited stock
        { "aizone2",  "none", 2, "D"        }, -- AI dropoff BLUE, ground+para (default)
        { "aizone3",  "none", 1, "P", -1    }, -- AI pickup RED, unlimited stock
        { "aizone4",  "none", 1, "D", "G"  }, -- AI dropoff RED, ground only
    }

    --wpZones = { "Zone name", "smoke color",    "ACTIVE (yes/no)", "side (0 = Both sides / 1 = Red / 2 = Blue )", }
    self.settings["wpZones"]                              = {
        { "wpzone1",  "green",  "yes", 2 },
        { "wpzone2",  "blue",   "yes", 2 },
        { "wpzone3",  "orange", "yes", 2 },
        { "wpzone4",  "none",   "yes", 2 },
        { "wpzone5",  "none",   "yes", 2 },
        { "wpzone6",  "none",   "yes", 1 },
        { "wpzone7",  "none",   "yes", 1 },
        { "wpzone8",  "none",   "yes", 1 },
        { "wpzone9",  "none",   "yes", 1 },
        { "wpzone10", "none",   "no",  0 }, -- Both sides as its set to 0
    }

    -- ═══════════════════════════════════════════════════════════
    -- MISC — Extractable groups, logistics, unit limits and crate templates
    -- ═══════════════════════════════════════════════════════════

    -- *************** Optional Extractable GROUPS *****************

    -- Use any of the predefined names or set your own ones
    self.settings["extractableGroups"]                    = {
        "extract1",
        "extract2",
        "extract3",
        "extract4",
        "extract5",
        "extract6",
        "extract7",
        "extract8",
        "extract9",
        "extract10",

        "extract11",
        "extract12",
        "extract13",
        "extract14",
        "extract15",
        "extract16",
        "extract17",
        "extract18",
        "extract19",
        "extract20",

        "extract21",
        "extract22",
        "extract23",
        "extract24",
        "extract25",
    }

    -- ************** Logistics UNITS FOR CRATE SPAWNING ******************

    -- Use any of the predefined names or set your own ones
    -- When a logistic unit is destroyed, you will no longer be able to spawn crates
    self.settings["logisticUnits"]                        = {
        "logistic1",
        "logistic2",
        "logistic3",
        "logistic4",
        "logistic5",
        "logistic6",
        "logistic7",
        "logistic8",
        "logistic9",
        "logistic10",
    }

    -- ═══════════════════════════════════════════════════════════
    -- [CAP] CAPABILITIES BY TYPE — unified per-aircraft settings
    -- ═══════════════════════════════════════════════════════════
    -- Each entry defines ALL capabilities for one DCS aircraft type.
    -- Absence of an entry = unit is not a CTLD transport.
    --
    -- Fields:
    --   cratesEnabled            (bool)  can carry/spawn/unpack crates
    --   troopsEnabled            (bool)  can carry/deploy/extract troops
    --   canParachuteDrop         (bool)  enable "Parachute" F10 entries (Feature A)
    --   canSlingload             (bool)  enable hover-pickup + "Release/Cut Slingload" (Feature B)
    --   canTransportWholeVehicle (bool)  can load/unload whole vehicles (Feature Q)
    --   useNativeDcsCargoSystem  (bool)  use DCS native cargo system for crate spawning
    --   maxTroopsOnboard         (int)   max troops/group; fallback = numberOfTroops
    --   maxCratesOnboard         (int)   max crates in hold simultaneously; fallback = 1
    --   maxWholeVehiclesOnboard  (int)   max whole vehicles in hold; 0 = no vehicle transport
    --   loadableVehiclesRED      (table) DCS unit types loadable as whole vehicles (RED coalition)
    --   loadableVehiclesBLUE     (table) DCS unit types loadable as whole vehicles (BLUE coalition)
    --   convertNativeLoadToCTLD  (bool)  when true, a DCS-native cargo load is immediately converted
    --                                    to CTLD-managed (destroys the DCS slot, frees the ghost).
    --                                    Use for aircraft where the DCS cargo UI must not be exposed
    --                                    (e.g. UH-1H).  Leave false for aircraft that rely on the
    --                                    DCS cargo system for ground ops (C-130J-30, CH-47Fbl1).

    self.settings["capabilitiesByType"] = {

        -- ── MODS ────────────────────────────────────────────────────────────────
        -- ["Bronco-OV-10A"] = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
        --    canTransportWholeVehicle=false, useNativeDcsCargoSystem=false, maxTroopsOnboard=4, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
        ["76MD"] = {  -- Il-76 mod (exact DCS type name)
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = false,
            canTransportWholeVehicle = true,  useNativeDcsCargoSystem = false,
            convertNativeLoadToCTLD = false,
            maxTroopsOnboard = 80,  maxCratesOnboard = 20,  maxWholeVehiclesOnboard = 2,
            maxVehicleWeight = 20000,
            loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
            loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
        },
        ["Hercules"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = false,
            canTransportWholeVehicle = true,  useNativeDcsCargoSystem = false,
            convertNativeLoadToCTLD = false,
            maxTroopsOnboard = 30,  maxCratesOnboard = 1,   maxWholeVehiclesOnboard = 2,
            maxVehicleWeight = 20000,
            loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
            loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
        },
        ["SK-60"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = false,
            canTransportWholeVehicle = false, useNativeDcsCargoSystem = false,
            convertNativeLoadToCTLD = false,
            maxTroopsOnboard = 4,   maxCratesOnboard = 1,   maxWholeVehiclesOnboard = 0,
        },
        ["UH-60L"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = true,
            canTransportWholeVehicle = false, useNativeDcsCargoSystem = false,
            convertNativeLoadToCTLD = false,
            maxTroopsOnboard = 12,  maxCratesOnboard = 1,   maxWholeVehiclesOnboard = 0,
        },
        -- ["T-45"] = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
        --    canTransportWholeVehicle=false, useNativeDcsCargoSystem=false, maxTroopsOnboard=4, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },

        -- ── HELICOPTERS ──────────────────────────────────────────────────────────
        -- ["Ka-50"]   = { cratesEnabled=true, troopsEnabled=false, canParachuteDrop=false, canSlingload=true,
        --    canTransportWholeVehicle=false, useNativeDcsCargoSystem=false, maxTroopsOnboard=4, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
        -- ["Ka-50_3"] = { cratesEnabled=true, troopsEnabled=false, canParachuteDrop=false, canSlingload=true,
        --    canTransportWholeVehicle=false, useNativeDcsCargoSystem=false, maxTroopsOnboard=4, maxCratesOnboard=1, maxWholeVehiclesOnboard=0 },
        ["Mi-8MT"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = true,
            canTransportWholeVehicle = true,  useNativeDcsCargoSystem = true,
            convertNativeLoadToCTLD = false,
            maxTroopsOnboard = 16,  maxCratesOnboard = 2,   maxWholeVehiclesOnboard = 0,
        },
        ["Mi-24P"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = false, canSlingload = false,
            canTransportWholeVehicle = false, useNativeDcsCargoSystem = true,
            convertNativeLoadToCTLD = false,
            maxTroopsOnboard = 10,  maxCratesOnboard = 1,   maxWholeVehiclesOnboard = 0,
        },
        -- ["SA342L"]      = { cratesEnabled=false, troopsEnabled=true,  canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=4 },
        -- ["SA342M"]      = { cratesEnabled=false, troopsEnabled=true,  canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=4 },
        -- ["SA342Mistral"]= { cratesEnabled=false, troopsEnabled=true,  canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=4 },
        -- ["SA342Minigun"]= { cratesEnabled=false, troopsEnabled=true,  canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=3 },
        ["UH-1H"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = true,  canSlingload = true,
            canTransportWholeVehicle = true,  useNativeDcsCargoSystem = true,
            convertNativeLoadToCTLD = true,   -- DCS cargo UI causes ghost crates; force CTLD-managed
            maxTroopsOnboard = 8,   maxCratesOnboard = 1,   maxWholeVehiclesOnboard = 1,
            maxVehicleWeight = 1360,  -- ~3000 lbs internal cargo capacity
            loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
            loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
        },
        ["CH-47Fbl1"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = true, canSlingload = true,
            canTransportWholeVehicle = false, useNativeDcsCargoSystem = true,
            convertNativeLoadToCTLD = true,   -- DCS cargo UI causes ghost crates; force CTLD-managed
            maxTroopsOnboard = 40,  maxCratesOnboard = 8,   maxWholeVehiclesOnboard = 1,
            maxVehicleWeight = 11000,
            loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
            loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
        },

        -- ── FIXED-WING ───────────────────────────────────────────────────────────
        -- ["C-101EB"]  = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=4 },
        -- ["Su-25T"]   = { cratesEnabled=true, troopsEnabled=false, canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=1 },
        ["C-130J-30"] = {
            cratesEnabled = true, troopsEnabled = true, canParachuteDrop = true, canSlingload = false,
            canTransportWholeVehicle = true,  useNativeDcsCargoSystem = true,
            convertNativeLoadToCTLD = false,  -- DCS cargo system retained for ground ops
            maxTroopsOnboard = 80,  maxCratesOnboard = 22,  maxWholeVehiclesOnboard = 2,
            maxVehicleWeight = 20000,
            loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
            loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
        },

        -- ── WARBIRDS (examples, all disabled by default) ─────────────────────────
        -- ["P-51D"] = { cratesEnabled=true, troopsEnabled=false, canParachuteDrop=false, canSlingload=false, maxTroopsOnboard=1 },
    }

    -- ************** WEIGHT CALCULATIONS FOR INFANTRY GROUPS ******************

    -- Infantry groups weight is calculated based on the soldiers' roles, and the weight of their kit
    -- Every soldier weights between 90% and 120% of ctld.SOLDIER_WEIGHT, and they all carry a backpack and their helmet (ctld.KIT_WEIGHT)
    -- Standard grunts have a rifle and ammo (ctld.RIFLE_WEIGHT)
    -- AA soldiers have a MANPAD tube (ctld.MANPAD_WEIGHT)
    -- Anti-tank soldiers have a RPG and a rocket (ctld.RPG_WEIGHT)
    -- Machine gunners have the squad MG and 200 bullets (ctld.MG_WEIGHT)
    -- JTAC have the laser sight, radio and binoculars (ctld.JTAC_WEIGHT)
    -- Mortar servants carry their tube and a few rounds (ctld.MORTAR_WEIGHT)

    self.settings["SOLDIER_WEIGHT"] = 80 -- kg, will be randomized between 90% and 120%
    self.settings["KIT_WEIGHT"] = 20     -- kg
    self.settings["RIFLE_WEIGHT"] = 5    -- kg
    self.settings["MANPAD_WEIGHT"] = 18  -- kg
    self.settings["RPG_WEIGHT"] = 7.6    -- kg
    self.settings["MG_WEIGHT"] = 10      -- kg
    self.settings["MORTAR_WEIGHT"] = 26  -- kg
    self.settings["JTAC_WEIGHT"] = 15    -- kg
    self.settings["CIV_WEIGHT"] = 2      -- kg — light personal items for civilian role

    -- ************** INFANTRY GROUPS FOR PICKUP ******************
    -- Unit Types
    -- inf is normal infantry
    -- mg is M249
    -- at is RPG-16
    -- aa is Stinger or Igla
    -- mortar is a 2B11 mortar unit
    -- jtac is a JTAC soldier, which will use JTACAutoLase
    -- You must add a name to the group for it to work
    -- You can also add an optional coalition side to limit the group to one side
    -- for the side - 2 is BLUE and 1 is RED
    self.settings["loadableGroups"] = {
        { name = ctld.tr("Standard Group"),                   inf = 6,    mg = 2,  at = 2 }, -- will make a loadable group with 6 infantry, 2 MGs and 2 anti-tank for both coalitions
        { name = ctld.tr("Anti Air"),                         inf = 2,    aa = 3 },
        { name = ctld.tr("Anti Tank"),                        inf = 2,    at = 6 },
        { name = ctld.tr("Mortar Squad"),                     mortar = 6 },
        { name = ctld.tr("JTAC Group"),                       inf = 4,    jtac = 1 }, -- will make a loadable group with 4 infantry and a JTAC soldier for both coalitions
        { name = ctld.tr("JTAC Group 2"),                     inf = 4,    jtac = 2 }, -- will make a loadable group with 4 infantry and a JTAC soldier for both coalitions
        { name = ctld.tr("Single JTAC"),                      jtac = 1 },             -- will make a loadable group witha single JTAC soldier for both coalitions
        { name = ctld.tr("2x - Standard Groups"),             inf = 12,   mg = 4,  at = 4 },
        { name = ctld.tr("2x - Anti Air"),                    inf = 4,    aa = 6 },
        { name = ctld.tr("2x - Anti Tank"),                   inf = 4,    at = 12 },
        { name = ctld.tr("2x - Standard Groups + 2x Mortar"), inf = 12,   mg = 4,  at = 4, mortar = 12 },
        { name = ctld.tr("3x - Standard Groups"),             inf = 18,   mg = 6,  at = 6 },
        { name = ctld.tr("3x - Anti Air"),                    inf = 6,    aa = 9 },
        { name = ctld.tr("3x - Anti Tank"),                   inf = 6,    at = 18 },
        { name = ctld.tr("3x - Mortar Squad"),                mortar = 18 },
        { name = ctld.tr("5x - Mortar Squad"),                mortar = 30 },
        -- {name = ctld.tr("Mortar Squad Red"), inf = 2, mortar = 5, side =1 }, --would make a group loadable by RED only
        -- Feature I: post-deploy task assignment examples (specificParams.task)
        -- { name = ctld.tr("Assault Team"), inf = 6, mg = 2, at = 2,
        --   specificParams = { task = "AttackNearestEnemyOnLos" } },
        -- { name = ctld.tr("Advance Guard"), inf = 4, at = 2,
        --   specificParams = { task = "gotoNearestWPZ" } },
        --
        -- componentTypes example: custom DCS typeNames per role (including mod units).
        -- Roles not in the standard set (inf/mg/at/aa/mortar/jtac/civ) are supported as
        -- custom roles (e.g. civ1, civ2, civ3) — each maps to a distinct 3D model.
        -- CTLDModValidator probes each typeName at mission start and logs missing mods.
        -- If a typeName is not found in DCS, CTLD falls back to the standard soldier model.
        --
        -- { name = "Civilian Crowd", civ1 = 3, civ2 = 2, civ3 = 1,
        --   componentTypes = {
        --     civ1 = { [1] = "CivilianMod_Worker", [2] = "CivilianMod_Worker" },
        --     civ2 = { [1] = "CivilianMod_Farmer", [2] = "CivilianMod_Farmer" },
        --     civ3 = { [1] = "CivilianMod_Vendor", [2] = "CivilianMod_Vendor" },
        --   }
        -- },
    }

    -- ************** SPAWNABLE CRATES ******************
    -- Weights must be unique as we use the weight to change the cargo to the correct unit
    -- when we unpack
    --
    self.settings["spawnableCrates"] = {
        -- name of the sub menu on F10 for spawning crates
        ["Combat Vehicles"] = {
            --crates you can spawn
            -- weight in KG
            -- Desc is the description on the F10 MENU
            -- unit is the model name of the unit to spawn
            -- cratesRequired - if set requires that many crates of the same type within 100m of each other in order build the unit
            -- side is optional but 2 is BLUE and 1 is RED

            -- Some descriptions are filtered to determine if JTAC or not!

            --- BLUE
            { weight = 1000.01, desc = ctld.tr("Humvee - MG"),         unit = "M1043 HMMWV Armament", side = 2, cratesRequired = 3 }, --careful with the names as the script matches the desc to JTAC types
            { weight = 1000.02, desc = ctld.tr("Humvee - TOW"),        unit = "M1045 HMMWV TOW",      side = 2, cratesRequired = 5 },
            { weight = 1000.03, desc = ctld.tr("Light Tank - MRAP"),   unit = "MaxxPro_MRAP",         side = 2, cratesRequired = 2 },
            { weight = 1000.04, desc = ctld.tr("Med Tank - LAV-25"),   unit = "LAV-25",               side = 2, cratesRequired = 3 },
            { weight = 1000.05, desc = ctld.tr("Heavy Tank - Abrams"), unit = "M-1 Abrams",           side = 2, cratesRequired = 4 },

            --- RED
            { weight = 1000.11, desc = ctld.tr("BTR-D"),               unit = "BTR_D",                side = 1, cratesRequired = 8 },
            { weight = 1000.12, desc = ctld.tr("BRDM-2"),              unit = "BRDM-2",               side = 1, cratesRequired = 7 },
            -- need more redfor!
        },
        ["Support"] = {
            --- BLUE
            { weight = 1001.01, desc = ctld.tr("Hummer - JTAC"),       unit = "Hummer",            side = 2,          cratesRequired = 2, isJTAC = true }, -- hidden when JTAC_dropEnabled=false
            { weight = 1001.02, desc = ctld.tr("M-818 Ammo Truck"),    unit = "M 818",             side = 2,          cratesRequired = 2 },
            { weight = 1001.03, desc = ctld.tr("M-978 Tanker"),        unit = "M978 HEMTT Tanker", side = 2,          cratesRequired = 2 },

            --- RED
            { weight = 1001.11, desc = ctld.tr("SKP-11 - JTAC"),       unit = "SKP-11",            side = 1,          isJTAC = true }, -- hidden when JTAC_dropEnabled=false
            { weight = 1001.12, desc = ctld.tr("Ural-375 Ammo Truck"), unit = "Ural-375",          side = 1,          cratesRequired = 2 },
            { weight = 1001.13, desc = ctld.tr("KAMAZ Ammo Truck"),    unit = "KAMAZ Truck",       side = 1,          cratesRequired = 2 },

            --- Both
            { weight = 1001.21, desc = ctld.tr("EWR Radar"),           unit = "FPS-117",           cratesRequired = 3 },
            -- FOB, FARP Alpha, Countryside FARP: auto-injected from scene files via CTLDSceneManager (model.crate).

        },
        ["Artillery"] = {
            --- BLUE
            { weight = 1002.01, desc = ctld.tr("MLRS"),          unit = "MLRS",         side = 2, cratesRequired = 3 },
            { weight = 1002.02, desc = ctld.tr("SpGH DANA"),     unit = "SpGH_Dana",    side = 2, cratesRequired = 3 },
            { weight = 1002.03, desc = ctld.tr("T155 Firtina"),  unit = "T155_Firtina", side = 2, cratesRequired = 3 },
            { weight = 1002.04, desc = ctld.tr("Howitzer"),      unit = "M-109",        side = 2, cratesRequired = 3 },

            --- RED
            { weight = 1002.11, desc = ctld.tr("SPH 2S19 Msta"), unit = "SAU Msta",     side = 1, cratesRequired = 3 },

        },
        ["SAM short range"] = {
            --- BLUE
            { weight = 1003.01, desc = ctld.tr("M1097 Avenger"),   unit = "M1097 Avenger",       side = 2, cratesRequired = 3 },
            { weight = 1003.02, desc = ctld.tr("M48 Chaparral"),   unit = "M48 Chaparral",       side = 2, cratesRequired = 2 },
            { weight = 1003.03, desc = ctld.tr("Roland ADS"),      unit = "Roland ADS",          side = 2, cratesRequired = 3 },
            { weight = 1003.04, desc = ctld.tr("Gepard AAA"),      unit = "Gepard",              side = 2, cratesRequired = 3 },
            { weight = 1003.05, desc = ctld.tr("LPWS C-RAM"),      unit = "HEMTT_C-RAM_Phalanx", side = 2, cratesRequired = 3 },

            --- RED
            { weight = 1003.11, desc = ctld.tr("9K33 Osa"),        unit = "Osa 9A33 ln",         side = 1, cratesRequired = 3 },
            { weight = 1003.12, desc = ctld.tr("9P31 Strela-1"),   unit = "Strela-1 9P31",       side = 1, cratesRequired = 3 },
            { weight = 1003.13, desc = ctld.tr("9K35M Strela-10"), unit = "Strela-10M3",         side = 1, cratesRequired = 3 },
            { weight = 1003.14, desc = ctld.tr("9K331 Tor"),       unit = "Tor 9A331",           side = 1, cratesRequired = 3 },
            { weight = 1003.15, desc = ctld.tr("2K22 Tunguska"),   unit = "2S6 Tunguska",        side = 1, cratesRequired = 3 },
        },
        -- NOTE: AA system crate entries (SAM mid range, SAM long range) are NOT declared here.
        -- They are injected automatically from CTLDCrateAssemblyManager.TEMPLATES at init
        -- (via injectAACrates called from CTLDCrateManager._processSpawnableCrates).
        -- To add or modify AA system crates, edit the TEMPLATES declaration below.
        -- DESIGN NOTE (Option A): if you add non-AA entries to a section whose name matches
        -- a template sectionName (e.g. "SAM mid range"), both sources coexist in that section.
        -- This is intentional — do NOT manually declare AA part entries here (they will duplicate).
        ["Drone"] = {
            --- BLUE MQ-9 Repear
            {
                weight = 1006.01,
                desc = ctld.tr("MQ-9 Repear - JTAC"),
                unit = "MQ-9 Reaper",
                side = 2,
                isJTAC = true,
                spawnAs = "AIRPLANE",
                specificParams = { speed = 150, alti = 3000, orbitRadiusNoLase = 2000, orbitRadiusOnLase = 1000 }
            },
            -- End of BLUE MQ-9 Repear

            --- RED RQ-1A Predator
            {
                weight = 1006.11,
                desc = ctld.tr("RQ-1A Predator - JTAC"),
                unit = "RQ-1A Predator",
                side = 1,
                isJTAC = true,
                spawnAs = "AIRPLANE",
                specificParams = { speed = 150, alti = 3000, orbitRadiusNoLase = 2000, orbitRadiusOnLase = 1000 }
            },
            -- End of RED RQ-1A Predator
        },
    }

    self.settings["spawnableCratesModels"] = {
        ["load"] = {
            ["category"] = "Cargos", --"Fortifications"
            ["type"] = "ammo_cargo", --"uh1h_cargo"    --"Cargo04"
            ["canCargo"] = true,
        },
        ["sling"] = {
            ["category"] = "Cargos",
            ["shape_name"] = "bw_container_cargo",
            ["type"] = "container_cargo",
            ["canCargo"] = true
        },
        ["dynamic"] = {
            ["category"] = "Cargos",
            ["type"] = "ammo_cargo",
            ["canCargo"] = true
        }
    }


    --[[ Placeholder for different type of cargo containers. Let's say pipes and trunks, fuel for FOB building
        ["shape_name"] = "ab-212_cargo",
        ["type"] = "uh1h_cargo" --new type for the container previously used

        ["shape_name"] = "ammo_box_cargo",
        ["type"] = "ammo_cargo",

        ["shape_name"] = "barrels_cargo",
        ["type"] = "barrels_cargo",

        ["shape_name"] = "bw_container_cargo",
        ["type"] = "container_cargo",

        ["shape_name"] = "f_bar_cargo",
        ["type"] = "f_bar_cargo",

        ["shape_name"] = "fueltank_cargo",
        ["type"] = "fueltank_cargo",

        ["shape_name"] = "iso_container_cargo",
        ["type"] = "iso_container",

        ["shape_name"] = "iso_container_small_cargo",
        ["type"] = "iso_container_small",

        ["shape_name"] = "oiltank_cargo",
        ["type"] = "oiltank_cargo",

        ["shape_name"] = "pipes_big_cargo",
        ["type"] = "pipes_big_cargo",

        ["shape_name"] = "pipes_small_cargo",
        ["type"] = "pipes_small_cargo",

        ["shape_name"] = "tetrapod_cargo",
        ["type"] = "tetrapod_cargo",

        ["shape_name"] = "trunks_long_cargo",
        ["type"] = "trunks_long_cargo",

        ["shape_name"] = "trunks_small_cargo",
        ["type"] = "trunks_small_cargo",
]] --

    -- ************** AA SYSTEM ASSEMBLY TEMPLATES **********************
    -- Single source of truth for deployable AA systems: parts, assembly rules, AND menu crates.
    -- At init, CTLDCrateAssemblyManager.injectAACrates() reads this table and populates the
    -- spawnableCrates sections automatically — no manual duplication needed.
    --
    -- Field reference:
    --   name           string   display name of the system (used in messages and event data)
    --   count          number   number of unique part types required for a complete system
    --   side           number   coalition owning this system (1=RED, 2=BLUE)
    --   sectionName    string   spawnableCrates section where crate entries will be injected
    --   allCratesLabel string   i18n key for the auto-generated "All crates" mixedSet entry
    --                           (optional — omit to suppress the mixedSet)
    --   parts          array:
    --     DCSTypename  string   DCS type name of the ground unit spawned at assembly
    --     desc         string   i18n key — used for crate menu label AND "Missing X" messages
    --     weight       number   crate weight (kg). Dual role: DCS slingload mass AND unique
    --                           lookup key. MUST be globally unique across all spawnableCrates.
    --                           Omit for NoCrate parts that have no standalone crate at all.
    --     launcher     bool     true = this part triggers rearm detection
    --     amount       number   units spawned per template (default 1; launchers use aaLaunchers)
    --     NoCrate      bool     true = part always present at assembly, not counted in mixedSet.
    --                           Can still carry a weight (spawnable as a standalone crate).
    --     cratesRequired number number of crates of this type needed to unlock the part (default 1)
    --   repair         table:
    --     desc         string   i18n key for repair crate menu label
    --     weight       number   unique crate weight for the repair crate (side = tmpl.side)
    --
    CTLDCrateAssemblyManager.TEMPLATES = {
        {
            name           = "HAWK AA System",
            count          = 5,
            side           = 2,
            sectionName    = "SAM mid range",
            allCratesLabel = "HAWK - All crates",
            parts = {
                { DCSTypename = "Hawk ln",   desc = "HAWK Launcher",     launcher = true, weight = 1004.01 },
                { DCSTypename = "Hawk sr",   desc = "HAWK Search Radar", amount = 2,      weight = 1004.02 },
                { DCSTypename = "Hawk tr",   desc = "HAWK Track Radar",  amount = 2,      weight = 1004.03 },
                { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",          NoCrate = true,  weight = 1004.04 },
                { DCSTypename = "Hawk cwar", desc = "HAWK CWAR",         amount = 2, NoCrate = true, weight = 1004.05 },
            },
            repair = { desc = "HAWK Repair", weight = 1004.06 },
        },
        {
            name           = "NASAMS AA System",
            count          = 3,
            side           = 2,
            sectionName    = "SAM mid range",
            allCratesLabel = "NASAMS - All crates",
            parts = {
                { DCSTypename = "NASAMS_LN_C",          desc = "NASAMS Launcher 120C",     launcher = true, weight = 1004.11 },
                { DCSTypename = "NASAMS_Radar_MPQ64F1", desc = "NASAMS Search/Track Radar",                 weight = 1004.12 },
                { DCSTypename = "NASAMS_Command_Post",  desc = "NASAMS Command Post",                       weight = 1004.13 },
            },
            repair = { desc = "NASAMS Repair", weight = 1004.14 },
        },
        {
            name           = "BUK AA System",
            count          = 3,
            side           = 1,
            sectionName    = "SAM mid range",
            allCratesLabel = "BUK - All crates",
            parts = {
                { DCSTypename = "SA-11 Buk LN 9A310M1", desc = "BUK Launcher",     launcher = true, weight = 1004.31 },
                { DCSTypename = "SA-11 Buk SR 9S18M1",  desc = "BUK Search Radar",                  weight = 1004.32 },
                { DCSTypename = "SA-11 Buk CC 9S470M1", desc = "BUK CC Radar",                      weight = 1004.33 },
            },
            repair = { desc = "BUK Repair", weight = 1004.34 },
        },
        {
            name           = "KUB AA System",
            count          = 2,
            side           = 1,
            sectionName    = "SAM mid range",
            allCratesLabel = "KUB - All crates",
            parts = {
                { DCSTypename = "Kub 2P25 ln",  desc = "KUB Launcher", launcher = true, weight = 1004.21 },
                { DCSTypename = "Kub 1S91 str", desc = "KUB Radar",                     weight = 1004.22 },
            },
            repair = { desc = "KUB Repair", weight = 1004.23 },
        },
        {
            name           = "Patriot AA System",
            count          = 4,
            side           = 2,
            sectionName    = "SAM long range",
            allCratesLabel = "Patriot - All crates",
            parts = {
                { DCSTypename = "Patriot ln",  desc = "Patriot Launcher",        launcher = true, amount = 8, weight = 1005.01 },
                { DCSTypename = "Patriot str", desc = "Patriot Radar",           amount = 2,                  weight = 1005.02 },
                { DCSTypename = "Patriot ECS", desc = "Patriot ECS",                                          weight = 1005.03 },
                { DCSTypename = "Patriot AMG", desc = "Patriot AMG (optional)",  NoCrate = true,              weight = 1005.06 },
            },
            repair = { desc = "Patriot Repair", weight = 1005.07 },
        },
        {
            name           = "S-300 AA System",
            count          = 6,
            side           = 1,
            sectionName    = "SAM long range",
            allCratesLabel = "S-300 - All crates",
            parts = {
                { DCSTypename = "S-300PS 5P85C ln",  desc = "S-300 Grumble TEL C",         launcher = true, amount = 1, weight = 1005.11 },
                { DCSTypename = "S-300PS 5P85D ln",  desc = "S-300 Grumble TEL D",         NoCrate = true,  amount = 2 },   -- no standalone crate
                { DCSTypename = "S-300PS 40B6M tr",  desc = "S-300 Grumble Flap Lid-A TR",                             weight = 1005.12 },
                { DCSTypename = "S-300PS 40B6MD sr", desc = "S-300 Grumble Clam Shell SR",                             weight = 1005.13 },
                { DCSTypename = "S-300PS 64H6E sr",  desc = "S-300 Grumble Big Bird SR",                               weight = 1005.14 },
                { DCSTypename = "S-300PS 54K6 cp",   desc = "S-300 Grumble C2",                                        weight = 1005.15 },
            },
            repair = { desc = "S-300 Repair", weight = 1005.16 },
        },
    }

    -- ******************************************************************
    -- ****************** END OF CONFIGURATION AREA *********************
    -- ******************************************************************

    -- overwrite defaults settings from CTLD_userConfig.lua --------------------------------------------
    if ctld.yamlConfigDatas then
        local userConfigTable = CTLDConfig.parseYAML(ctld.yamlConfigDatas) -- get user config coming from CTLD_userConfig.lua execution in ME

        local report = "REPORT - CTLD user config loaded :"
        for k, v in pairs(userConfigTable) do
            local tableName, fieldName = k:match("([^%.]+)%.(.+)") -- extract key after "ctld."
            if tableName == "ctld" then                            -- load general settings
                self.settings[fieldName] =
                    v                                              -- fix: use variable fieldName, not literal "fieldName"
                report = report .. "\nctld." .. fieldName .. " = " .. tostring(v)
            end
        end
        return true, report
    else
        if self.settings["debug"] then
            ctld.utils.log("WARN", "CTLDConfig: No YAML config data found in ctld.yamlConfigDatas")
        end
    end

    -- Temporary: Loading old ctld settings variables for backward compatibility
    if ctld ~= nil then
        for k, v in pairs(CTLDConfig.getAllSettings()) do
            if self.settings[k] ~= nil then
                ctld[k] = v -- set old ctld variables
            end
        end
    end
end

-- Retrieve a specific setting
function CTLDConfig:getSetting(key)
    return self.settings[key]
end

-- Retrieve a specific setting
function CTLDConfig.getAllSettings()
    return CTLDConfig._instance.settings
end

-- Retrieve a specific setting
function CTLDConfig:setSetting(key, value)
    self.settings[key] = value
    return self.settings[key]
end

------------------------------------------------------------------
-- yaml parsing utilities
------------------------------------------------------------------
-- Utility: Trims whitespace from both ends of a string
-- @param s: The raw string to trim
function CTLDConfig.trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Utility: Converts string values to their appropriate Lua types
-- @param v: The string value to convert
function CTLDConfig.to_type(v)
    if v == "true" then return true end
    if v == "false" then return false end
    if tonumber(v) then return tonumber(v) end
    return v:gsub("^['\"]", ""):gsub("['\"]$", "")
end

-- Main Parser: Converts a YAML-formatted string into a Lua Table
function CTLDConfig.parseYAML(data)
    local result = {}
    local stack = { result }
    local indentStack = { -1 }

    local literalMode = false
    local literalKey, literalIndent = "", 0
    local literalLines = {}

    for line in data:gmatch("[^\r\n]+") do
        local indent = line:match("^%s*"):len()
        local content = CTLDConfig.trim(line)

        -- 1. EXIT MULTILINE MODE
        if literalMode and #content > 0 and indent <= literalIndent then
            stack[#stack][literalKey] = table.concat(literalLines, "\n")
            literalMode = false
            literalLines = {}
        end

        -- 2. PROCESSING
        if literalMode then
            literalLines[#literalLines + 1] = line:sub(literalIndent + 3) or ""
        elseif content ~= "" and not content:match("^#") then
            -- STACK REALIGNMENT
            while #indentStack > 1 and indent <= indentStack[#indentStack] do
                table.remove(stack)
                table.remove(indentStack)
            end

            -- Check for list item with key attached (- polar:)
            local listDashKey, listDashValue = content:match("^%- ([^:]+):%s*(.*)")
            local key, value

            if listDashKey then
                -- NEW LIST ITEM OBJECT
                local newEntry = {}
                local parent = stack[#stack]
                parent[#parent + 1] = newEntry

                -- We push the entry into the stack
                table.insert(stack, newEntry)
                table.insert(indentStack, indent)

                key, value = listDashKey, listDashValue
                -- Important: update indent to match the key position after the dash
                indent = line:find(listDashKey) - 1
            else
                -- Standard key:value
                key, value = content:match("([^:]+):%s*(.*)")
            end

            if key then
                key, value = CTLDConfig.trim(key), CTLDConfig.trim(value)
                if value == "|" then
                    literalMode, literalKey, literalIndent = true, key, indent
                    literalLines = {}
                elseif value == "" then
                    -- Nested object
                    local newSubTable = {}
                    stack[#stack][key] = newSubTable
                    -- Move into the sub-table
                    table.insert(stack, newSubTable)
                    table.insert(indentStack, indent)
                else
                    -- Simple assignment
                    stack[#stack][key] = CTLDConfig.to_type(value)
                end
            elseif content:match("^%-") then
                -- Simple list item (- SAM-6)
                local item = CTLDConfig.trim(content:sub(2))
                local parent = stack[#stack]
                if type(parent) == "table" then
                    parent[#parent + 1] = CTLDConfig.to_type(item)
                end
            end
        end
    end

    if literalMode then stack[#stack][literalKey] = table.concat(literalLines, "\n") end
    return result
end

local config = CTLDConfig.get() -- get the singleton instance

-- Global shortcut for config access.
-- Usage: ctld.gs("paramName")  instead of  CTLDConfig.get():getSetting("paramName")
-- This is the ONLY authorised form to read config parameters throughout src/.
function ctld.gs(key)
    return CTLDConfig.get():getSetting(key)
end

--[[
------------------------------------------------------------------
-- Example: At start of CTLD initialization : Load ctld user config from CTLD_userConfig.lua
-- and set the ctld settings accordingly
-- ctld.yamlConfigDatas must be loaded beforehand by executing CTLD_userConfig.lua in the mission editor
-- with a trigger at START MISSION in "DO SCRIPT FILE" action
------------------------------------------------------------------

local myConfig = CTLDConfig.get()   -- Get the singleton instance
local success, report = myConfig:load()   -- Load the data from your specific path
if success then
    trigger.action.outText(report, 10)    -- Display the result if loading was successful
end

--At this stage, the ctld configuration settings are loaded with the user's values.


------------------------------------------------------------------
--- How to use the CTLDConfig singleton class in your scripts
--- to get ex "ctld.maximumDistanceLogistic = 200" value
------------------------------------------------------------------
local config = CTLDConfig.get()                                        -- get the singleton instance
local maximumDistanceLogistic = config:getSetting("maximumDistanceLogistic")  -- retrieve specific setting
-- Now you can use maximumDistanceLogistic in your script

-- You can also modify settings:
config:setSetting("maximumDistanceLogistic", 250)

-- To completely reset the singleton (useful for testing):
CTLDConfig.reset()  -- class method (dot notation)
]] --
