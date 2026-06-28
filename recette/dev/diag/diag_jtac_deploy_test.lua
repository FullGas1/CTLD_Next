-- diag_jtac_deploy_test.lua
-- Full automated JTAC drone test — reusable (target is respawned, never permanently destroyed):
--   1. Cleanup existing JTACs
--   2. Deploy MQ-9 via deployAirJTAC (same path as crate unpack)
--   3. T+5s   : check state + orbitParams + draw circles (blue=initial, red=target)
--   4. T+120s : respawn target (destroy + recreate) to trigger orbit restore
--   5. T+135s : verify drone returned to BLUE circle; drop pin at drone position

local FALLBACK_RADIUS = ctld.gs("jtacDroneRadius") or 1000

-- Monotonic mark index — never reuse a removed ID (DCS removeMark makes ID permanently invalid)
if mIdx == nil then mIdx = 9500 end
local function gidx() mIdx = mIdx + 1; return mIdx end

local function drawCircle(center, radius, r, g, b, label)
    trigger.action.circleToAll(-1, gidx(), center, radius,
        {r, g, b, 1.0}, {r, g, b, 0.05}, 1, false, label)
end

-- ── 1. cleanup ───────────────────────────────────────────────────────────────
CTLDJTACManager.get():cleanup()

-- ── 2. get player ────────────────────────────────────────────────────────────
local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end

-- ── 3. find MQ-9 descriptor ──────────────────────────────────────────────────
local descriptor = nil
local droneCrates = (ctld.gs("spawnableCrates") or {})["Drone"] or {}
for _, d in ipairs(droneCrates) do
    if d.unit == "MQ-9 Reaper" and d.side == 2 then descriptor = d; break end
end
if not descriptor then return "NO_MQ9_DESCRIPTOR" end

-- ── 4. deploy ────────────────────────────────────────────────────────────────
local spawnPos = playerUnit:getPoint()
local ok = CTLDJTACManager.get():deployAirJTAC(playerUnit, spawnPos, descriptor, country.id.USA)
if not ok then return "DEPLOY_FAILED" end

trigger.action.outText("[JTAC test] MQ-9 deployed — circles in 5s, target respawn at T+120s", 10)

-- ── 5. T+5s: state + circles ─────────────────────────────────────────────────
timer.scheduleFunction(function()
    local mgr = CTLDJTACManager.get()
    local gname, jtac
    for k, j in pairs(mgr.jtacs) do if j.isFlying then gname, jtac = k, j; break end end
    if not jtac then
        trigger.action.outText("[JTAC test] T+5s: NO FLYING JTAC", 10); return
    end

    local op = jtac.orbitParams
    local rNoLase = op and op.orbitRadiusNoLase or FALLBACK_RADIUS
    local rOnLase = op and op.orbitRadiusOnLase or FALLBACK_RADIUS

    trigger.action.outText(string.format(
        "[JTAC test] T+5s | %s | state=%s\norbitParams: spd=%s alti=%s rNoLase=%s rOnLase=%s\ntarget=%s",
        gname, tostring(jtac.state),
        tostring(op and op.speed), tostring(op and op.alti),
        tostring(rNoLase), tostring(rOnLase),
        jtac.currentTarget and jtac.currentTarget.unitName or "none"), 25)

    -- Blue = initial orbit (persists for entire test)
    if jtac.initialPosition then
        drawCircle(jtac.initialPosition, rNoLase, 0.2, 0.5, 1.0,
            string.format("INITIAL ORBIT r=%dm", rNoLase))
    end
    -- Red = target orbit (if target already acquired)
    if jtac.currentTarget then
        local tu = Unit.getByName(jtac.currentTarget.unitName)
        if tu and tu:isExist() then
            drawCircle(tu:getPoint(), rOnLase, 1.0, 0.1, 0.1,
                string.format("TARGET ORBIT r=%dm — %s", rOnLase, jtac.currentTarget.unitName))
        end
    end
end, nil, timer.getTime() + 5)

-- ── 6. T+120s: respawn target (destroy + recreate same group) ────────────────
local savedTargetGroupName = nil
timer.scheduleFunction(function()
    local mgr = CTLDJTACManager.get()
    local jtac
    for _, j in pairs(mgr.jtacs) do if j.isFlying then jtac = j; break end end

    local targetName = jtac and jtac.currentTarget and jtac.currentTarget.unitName
    if not targetName then
        -- Target already lost (LOS) — just report
        trigger.action.outText("[JTAC test] T+120s: target already gone — drone should be on BLUE circle", 15)
        return
    end

    local tu = Unit.getByName(targetName)
    if not (tu and tu:isExist()) then
        trigger.action.outText("[JTAC test] T+120s: target not found", 10); return
    end

    -- Save group info for respawn
    local tg = tu:getGroup()
    savedTargetGroupName = tg and tg:getName() or nil
    local tPos = tu:getPoint()
    local tCountry = tu:getCountry()

    -- Destroy target group
    if tg then tg:destroy() end

    trigger.action.outText(string.format(
        "[JTAC test] T+120s: target %s destroyed — drone should return to BLUE circle", targetName), 15)

    -- Respawn at same position after 10s
    timer.scheduleFunction(function()
        local unitDef = {
            id = ctld.utils.getNextUniqId(),
            name = targetName,
            type = "BTR-80",
            x    = tPos.x,
            y    = tPos.z,
            heading = 0,
            skill   = "Average",
            playerCanDrive = false,
        }
        local groupDef = {
            id       = ctld.utils.getNextUniqId(),
            name     = savedTargetGroupName or targetName,
            task     = "Ground Nothing",
            start_time = 0,
            units    = { unitDef },
            route    = { points = {{ x=tPos.x, y=tPos.z, type="Turning Point", action="Off Road", speed=0, alt=tPos.y }} },
        }
        coalition.addGroup(tCountry, Group.Category.GROUND, groupDef)
        trigger.action.outText("[JTAC test] T+130s: target respawned — drone should re-acquire", 10)
    end, nil, timer.getTime() + 10)
end, nil, timer.getTime() + 120)

-- ── 7. T+135s: verify drone state ────────────────────────────────────────────
timer.scheduleFunction(function()
    local mgr = CTLDJTACManager.get()
    local gname, jtac
    for k, j in pairs(mgr.jtacs) do if j.isFlying then gname, jtac = k, j; break end end
    if not jtac then
        trigger.action.outText("[JTAC test] T+135s: JTAC gone", 10); return
    end

    trigger.action.outText(string.format(
        "[JTAC test] T+135s | %s | state=%s | target=%s\nDrone should be inside BLUE circle",
        gname, tostring(jtac.state),
        jtac.currentTarget and jtac.currentTarget.unitName or "none"), 20)

    -- Pin at drone current position
    local g = Group.getByName(gname)
    local u = g and g:getUnit(1)
    if u then
        trigger.action.markToAll(gidx(),
            "DRONE T+135s | state=" .. tostring(jtac.state), u:getPoint(), false, "")
    end
end, nil, timer.getTime() + 135)

return string.format("OK | %s deployed at (%.0f,%.0f)", descriptor.unit, spawnPos.x, spawnPos.z)
