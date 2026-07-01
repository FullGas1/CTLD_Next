---@diagnostic disable
-- ============================================================
-- F-112 — Repack JTAC vehicle: deregisterJTAC — no false OnJTACDead
-- UH-1H BLUE only (no C-130/CH-47 required)
--
-- Tests the anti-false-KIA mechanism used during repack:
--   1. packVehicle calls deregisterJTAC BEFORE unit:destroy()
--   2. deregisterJTAC silently removes the jtacs entry (no OnJTACDead)
--   3. laser code is freed (returned to pool)
--   4. OnJTACDead is NOT published
--
-- Approach: inject a fake CTLDJTAC entry into jmgr.jtacs and call deregisterJTAC
-- directly (the same path packVehicle takes). packVehicle itself requires a real DCS
-- unit — that path is covered live (F-109e visual PASS 2026-04-27).
-- ============================================================

local LOG_PATH = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/"
local SRC      = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"

-- Purge CTLD.log
local _f = io.open(LOG_PATH .. "CTLD.log", "w"); if _f then _f:close() end

dofile(LOG_PATH .. "setup.lua")
dofile(SRC .. "CTLD_menu.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_crate.lua")
dofile(SRC .. "CTLD_troop.lua")
dofile(SRC .. "CTLD_jtac.lua")
dofile(SRC .. "CTLD_vehicle.lua")

ctld_test.start("F-112", "Repack JTAC vehicle — deregisterJTAC, no false OnJTACDead")
ctld_test.cleanup()

local jmgr = CTLDJTACManager.getInstance()
local ed   = EventDispatcher.getInstance()

-- ── Track events ─────────────────────────────────────────────────────────────

local jtacDeadFired = false
local subDead = ed:subscribe("OnJTACDead", function()
    jtacDeadFired = true
end)

-- ── 1. Inject a fake JTAC entry ───────────────────────────────────────────

local FAKE_GROUP = "CTLD_VEH_JTAC_TEST_repack"

-- Allocate a laser code from the pool so deregisterJTAC can free it
local laserCode = jmgr:_assignLaserCode()
ctld_test.assertNotNil(laserCode, "[1a] laser code allocated from pool")

-- Build a minimal CTLDJTAC-like entry (stopLase is called by deregisterJTAC)
local fakeJtac = {
    state      = CTLDJTAC.STATE.LASING,
    laserCode  = laserCode,
    isFlying   = false,
    stopLase   = function(self, reason)
        -- minimal stub — no unit:destroy needed in sandbox
        self.state = CTLDJTAC.STATE.IDLE
    end,
}
jmgr.jtacs[FAKE_GROUP] = fakeJtac

ctld_test.assertNotNil(jmgr.jtacs[FAKE_GROUP], "[1b] fake jtac injected into jmgr.jtacs")

-- Track pool size before deregister
local poolSizeBefore = #jmgr._laserPool

-- ── 2. Call deregisterJTAC (the path used by packVehicle) ────────────────

local deregOk = pcall(function()
    jmgr:deregisterJTAC(FAKE_GROUP)
end)
ctld_test.assert(deregOk, "[2] deregisterJTAC: no Lua error")

-- ── 3. jtacs entry removed ───────────────────────────────────────────────

ctld_test.assertNil(jmgr.jtacs[FAKE_GROUP],
    "[3] jmgr.jtacs[FAKE_GROUP] nil after deregisterJTAC (silent deregister)")

-- ── 4. OnJTACDead NOT published ───────────────────────────────────────────

ctld_test.assert(not jtacDeadFired,
    "[4] OnJTACDead NOT published (anti-false-KIA confirmed)")

-- ── 5. Laser code freed (returned to pool) ───────────────────────────────

local poolSizeAfter = #jmgr._laserPool
ctld_test.assert(poolSizeAfter == poolSizeBefore + 1,
    string.format("[5] laser code freed: pool %d → %d", poolSizeBefore, poolSizeAfter))

-- ── 6. deregisterJTAC is idempotent (second call on absent entry) ────────

local idempotentOk = pcall(function()
    jmgr:deregisterJTAC(FAKE_GROUP)
end)
ctld_test.assert(idempotentOk, "[6] deregisterJTAC: idempotent (no error on second call)")

-- ── Teardown ─────────────────────────────────────────────────────────────

ed:unsubscribe("OnJTACDead", subDead)

ctld_test.finish()
