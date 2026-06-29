-- ============================================================
-- CTLDParachuteEffect.lua
-- Abstract interface + null implementation for virtual parachute side effects.
--
-- Allows mission makers / mods to hook into parachute drop events
-- for visual effects (smoke, markers, animations) without touching
-- core physics logic.
--
-- Usage:
--   manager:setParachuteEffect(CTLDNullParachuteEffect:new())
--   -- or any custom subclass:
--   manager:setParachuteEffect(MyVisualEffect:new())
--
-- dropData payload (passed to all hooks):
--   type          "crate" | "troop" | "vehicle"
--   unitName      string              name of dropped unit / group
--   dropPosition  {x,y,z}            transport position at drop time
--   landPositions {{x,y,z}, ...}     computed ground positions (1 per unit)
--   altitude      number             AGL at drop time (m)
--   descentTime   number             descent duration (s)
--   transport     Unit               DCS transport unit
--   player        string or nil      player name if applicable
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDParachuteEffect  (abstract base)
-- ============================================================

CTLDParachuteEffect = class()

--- Called when the parachute drop is initiated (cargo leaves the transport).
-- @param dropData table
function CTLDParachuteEffect:onStart(dropData)  end  -- luacheck: ignore

--- Called once per second during the descent.
-- @param dropData table
function CTLDParachuteEffect:onTick(dropData)   end  -- luacheck: ignore

--- Called when the cargo has landed (spawn at ground position done).
-- @param dropData table
function CTLDParachuteEffect:onLanded(dropData) end  -- luacheck: ignore

-- ============================================================
-- CTLDNullParachuteEffect  (default no-op implementation)
-- ============================================================

CTLDNullParachuteEffect = class(CTLDParachuteEffect)
-- Inherits all three no-ops — zero overhead, safe default.
