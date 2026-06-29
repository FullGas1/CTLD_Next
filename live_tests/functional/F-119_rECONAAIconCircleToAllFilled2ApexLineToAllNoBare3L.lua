-- F-119 — RECON AA icon: circleToAll (filled) + 2 apex lineToAll (no bare 3-line triangle).
-- Verify: drawAAIcon() calls circleToAll on slot +1 and lineToAll on slots +2, +3.
-- Also verify: reconIconScale multiplier is applied (s = 35 * scale).

local results = {}
local function assert_eq(label, got, exp)
    if got == exp then
        results[#results+1] = "PASS " .. label
    else
        results[#results+1] = string.format("FAIL %s  got=%s  exp=%s", label, tostring(got), tostring(exp))
    end
end
local function assert_true(label, cond) assert_eq(label, not not cond, true) end
local function assert_near(label, got, exp, tol)
    tol = tol or 0.01
    if math.abs(got - exp) <= tol then
        results[#results+1] = "PASS " .. label
    else
        results[#results+1] = string.format("FAIL %s  got=%.4f  exp=%.4f  tol=%.4f", label, got, exp, tol)
    end
end

local cfg = CTLDConfig.get().settings

-- ── mock trigger.action ───────────────────────────────────────────────────────
local calls = { circle = {}, line = {} }

local _orig_circle = trigger.action.circleToAll
local _orig_line   = trigger.action.lineToAll

trigger.action.circleToAll = function(coa, mid, center, radius, borderColor, fillColor, lineType, readonly, msg)
    calls.circle[#calls.circle+1] = { coa=coa, mid=mid, center=center, radius=radius,
        borderColor=borderColor, fillColor=fillColor, msg=msg }
end
trigger.action.lineToAll = function(coa, mid, p1, p2, color, lineType, readonly, msg)
    calls.line[#calls.line+1] = { coa=coa, mid=mid, p1=p1, p2=p2, color=color, msg=msg }
end

-- ── test with scale=1.0 ───────────────────────────────────────────────────────
local _origScale = cfg["reconIconScale"]
cfg["reconIconScale"] = 1.0

local testPos   = { x = 0, y = 0, z = 0 }
local testColor = { 1.0, 0.0, 0.0, 1.0 }
local markId    = 9900  -- arbitrary non-conflicting ID

CTLDReconRenderer.drawAAIcon(testPos, markId, testColor)

-- Slot allocation
assert_eq("U-01 exactly 1 circleToAll call",  #calls.circle, 1)
assert_eq("U-02 exactly 2 lineToAll calls",    #calls.line,   2)

-- Circle is on slot markId*10+1
assert_eq("U-03 circle markId slot+1",  calls.circle[1].mid, markId * 10 + 1)

-- Lines are on slots +2 and +3
local lineIds = { calls.line[1].mid, calls.line[2].mid }
table.sort(lineIds)
assert_eq("U-04 line slot+2", lineIds[1], markId * 10 + 2)
assert_eq("U-05 line slot+3", lineIds[2], markId * 10 + 3)

-- Fill color has alpha 0.3
local fill = calls.circle[1].fillColor
assert_true("U-06 fill not nil",       fill ~= nil)
assert_near("U-07 fill alpha=0.3",     fill[4] or 0, 0.3, 0.01)
assert_near("U-08 fill red=testColor", fill[1] or 0, 1.0, 0.01)

-- Circle radius = hs*0.9 = (35/2)*0.9 = 15.75
assert_near("U-09 circle radius scale=1.0", calls.circle[1].radius, 15.75, 0.1)

-- Label
assert_eq("U-10 circle label AA", calls.circle[1].msg, "AA")

-- ── test with scale=2.0 — radius doubles ─────────────────────────────────────
calls.circle = {}; calls.line = {}
cfg["reconIconScale"] = 2.0
CTLDReconRenderer.drawAAIcon(testPos, markId + 1, testColor)
-- radius = (35*2)/2 * 0.9 = 31.5
assert_near("U-11 circle radius scale=2.0", calls.circle[1].radius, 31.5, 0.1)

-- ── restore ───────────────────────────────────────────────────────────────────
cfg["reconIconScale"]        = _origScale
trigger.action.circleToAll   = _orig_circle
trigger.action.lineToAll     = _orig_line

local pass = 0; local fail = 0
for _, r in ipairs(results) do
    env.info("[F-119] " .. r)
    if r:sub(1,4) == "PASS" then pass = pass+1 else fail = fail+1 end
end

local summary = string.format("F-119: %d PASS / %d FAIL", pass, fail)
trigger.action.outText(summary, 15)
env.info("[F-119] " .. summary)
return summary
