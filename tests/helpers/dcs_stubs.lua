---@diagnostic disable
-- tests/helpers/dcs_stubs.lua
-- Minimal DCS API stubs for busted tests.
-- Covers every global used by src/ modules.
-- Tests that need to inspect or override a stub should save/restore locally.
-- ============================================================

-- ── env ──────────────────────────────────────────────────────
env = {
    info    = function() end,
    warning = function() end,
    error   = function() end,
}

-- ── timer ────────────────────────────────────────────────────
timer = {
    getAbsTime        = function() return 0 end,
    getTime           = function() return 0 end,
    scheduleFunction  = function(fn, arg, t) return 0 end,
    removeFunction    = function(id) end,
}

-- ── coalition ────────────────────────────────────────────────
coalition = {
    side = { NEUTRAL = 0, RED = 1, BLUE = 2 },
    addStaticObject = function(cId, data) end,
    getGroups       = function(side, cat) return {} end,
    getPlayers      = function(side) return {} end,
    getStaticObjects= function(side) return {} end,
}

-- ── country ──────────────────────────────────────────────────
country = {
    id = {
        USA         = 2,
        RUSSIA      = 0,
        GERMANY     = 4,
        UK          = 8,
        FRANCE      = 14,
        UKRAINE     = 51,
    },
    -- Reverse map: integer id → name string (used by ctld.utils.dynAddStatic)
    name = {
        [2]  = "USA",
        [0]  = "RUSSIA",
        [4]  = "GERMANY",
        [8]  = "UK",
        [14] = "FRANCE",
        [51] = "UKRAINE",
    },
}

-- ── Group ────────────────────────────────────────────────────
Group = {
    Category = { AIR = 0, GROUND = 2, HELICOPTER = 1, SHIP = 3 },
    getByName = function(name) return nil end,
}

-- ── Unit ─────────────────────────────────────────────────────
Unit = {
    Category = { AIRPLANE = 1, HELICOPTER = 2, GROUND_UNIT = 3, SHIP = 4, STRUCTURE = 5 },
    getByName = function(name) return nil end,
}

-- ── StaticObject ─────────────────────────────────────────────
StaticObject = {
    getByName = function(name) return nil end,
}

-- ── Object ───────────────────────────────────────────────────
Object = {
    Category = { UNIT = 1, WEAPON = 2, STATIC = 3, BASE = 4, SCENERY = 5, CARGO = 6 },
}

-- ── trigger ──────────────────────────────────────────────────
trigger = {
    smokeColor = { Green = 0, Red = 1, White = 2, Orange = 3, Blue = 4 },
    action = {
        outText           = function() end,
        outTextForGroup   = function() end,
        outTextForCoalition = function() end,
        outTextForUnit    = function() end,
        removeMark        = function() end,
        markToAll         = function() return 0 end,
        markToCoalition   = function() return 0 end,
        quadToAll         = function() end,
        lineToAll         = function() end,
        circleToAll       = function() end,
        textToAll         = function() end,
        smoke             = function() end,
        illuminationBomb  = function() end,
        explosion         = function() end,
        setUnitInternalCargo      = function() end,
        outSoundForCoalition      = function() end,
        outSoundForGroup          = function() end,
        outSoundForUnit           = function() end,
        outSound                  = function() end,
    },
    misc = {
        getZone = function(name) return nil end,
    },
}

-- ── missionCommands ──────────────────────────────────────────
missionCommands = {
    addSubMenuForGroup  = function() end,
    addCommandForGroup  = function() end,
    removeItemForGroup  = function() end,
    addSubMenu          = function() end,
    addCommand          = function() end,
    removeItem          = function() end,
}

-- ── world ────────────────────────────────────────────────────
world = {
    searchObjects   = function(cat, vol, fn) end,
    addEventHandler = function(handler) end,
    removeEventHandler = function(handler) end,
    VolumeType      = { SPHERE = 0, BOX = 4 },
    event           = {
        S_EVENT_INVALID              = 0,
        S_EVENT_SHOT                 = 1,
        S_EVENT_HIT                  = 2,
        S_EVENT_TAKEOFF              = 3,
        S_EVENT_LAND                 = 4,
        S_EVENT_CRASH                = 5,
        S_EVENT_EJECTION             = 6,
        S_EVENT_REFUELING            = 7,
        S_EVENT_DEAD                 = 8,
        S_EVENT_PILOT_DEAD           = 9,
        S_EVENT_BASE_CAPTURED        = 10,
        S_EVENT_MISSION_START        = 11,
        S_EVENT_MISSION_END          = 12,
        S_EVENT_TOOK_CONTROL         = 13,
        S_EVENT_REFUELING_STOP       = 14,
        S_EVENT_BIRTH                = 15,
        S_EVENT_PLAYER_ENTER_UNIT    = 20,
        S_EVENT_PLAYER_LEAVE_UNIT    = 21,
        S_EVENT_PLAYER_COMMENT       = 22,
        S_EVENT_SHOOTING_START       = 23,
        S_EVENT_SHOOTING_END         = 24,
        S_EVENT_MARK_ADDED           = 25,
        S_EVENT_MARK_CHANGE          = 26,
        S_EVENT_MARK_REMOVED         = 27,
    },
}

-- ── land ─────────────────────────────────────────────────────
land = {
    getHeight    = function(p) return 0 end,
    getSurfaceType = function(p) return 1 end,
    SurfaceType  = { LAND = 1, SHALLOW_WATER = 2, WATER = 3, ROAD = 4, RUNWAY = 5 },
}

-- ── coord ────────────────────────────────────────────────────
coord = {
    LOtoLL  = function(p) return 0, 0 end,
    LLtoLO  = function(lat, lon) return { x = 0, y = 0, z = 0 } end,
    LLtoMGRS = function(lat, lon) return { UTMZone = "37T", MGRSDigraph = "CB", Easting = 0, Northing = 0 } end,
}

-- ── atmosphere ───────────────────────────────────────────────
atmosphere = {
    getWind = function(p) return { x = 0, y = 0, z = 0 } end,
}

-- ── radio ────────────────────────────────────────────────────
radio = {
    modulation = { AM = 0, FM = 1 },
}

-- ── Spot (JTAC laser) ────────────────────────────────────────
Spot = {
    createInfraRed = function(unit, local_ref, point) return { remove = function() end } end,
    createLaser    = function(unit, local_ref, point, code) return { remove = function() end, setCode = function() end } end,
}
