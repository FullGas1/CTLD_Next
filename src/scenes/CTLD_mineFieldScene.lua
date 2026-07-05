---@diagnostic disable
-- CTLD_mineFieldScene.lua
-- Minefield scene model — migrated from source_scene_ini/mineFieldSceneDatas.lua.
--
-- ====================================================================================================
-- BLOCK 1 : i18n -- 4 mandatory languages
-- ====================================================================================================

ctld.i18n["en"]["Mine Field Crate"]                        = "Mine Field Crate"
ctld.i18n["fr"]["Mine Field Crate"]                        = "Caisse Champ de Mines"
ctld.i18n["es"]["Mine Field Crate"]                        = "Caja Campo de Minas"
ctld.i18n["ko"]["Mine Field Crate"]                        = "지뢰밭 화물"

ctld.i18n["en"]["Deploy Mine Field"]                       = "Deploy Mine Field"
ctld.i18n["fr"]["Deploy Mine Field"]                       = "Déployer le Champ de Mines"
ctld.i18n["es"]["Deploy Mine Field"]                       = "Desplegar Campo de Minas"
ctld.i18n["ko"]["Deploy Mine Field"]                       = "지뢰밭 배치"

ctld.i18n["en"]["--- mineField Deployed by %1 ---"]        = "--- Mine Field deployed by %1 ---"
ctld.i18n["fr"]["--- mineField Deployed by %1 ---"]        = "--- Champ de Mines déployé par %1 ---"
ctld.i18n["es"]["--- mineField Deployed by %1 ---"]        = "--- Campo de Minas desplegado por %1 ---"
ctld.i18n["ko"]["--- mineField Deployed by %1 ---"]        = "--- %1에 의해 지뢰밭이 배치되었습니다 ---"

ctld.i18n["en"]["Mine Field"]                              = "Mine Field"
ctld.i18n["fr"]["Mine Field"]                              = "Champ de Mines"
ctld.i18n["es"]["Mine Field"]                              = "Campo de Minas"
ctld.i18n["ko"]["Mine Field"]                              = "지뢰밭"

ctld.i18n["en"]["Clear Mine Field (%1 mines, ~%2 m)"]      = "Clear Mine Field (%1 mines, ~%2 m)"
ctld.i18n["fr"]["Clear Mine Field (%1 mines, ~%2 m)"]      = "Déminer (%1 mines, ~%2 m)"
ctld.i18n["es"]["Clear Mine Field (%1 mines, ~%2 m)"]      = "Desactivar Campo (%1 minas, ~%2 m)"
ctld.i18n["ko"]["Clear Mine Field (%1 mines, ~%2 m)"]      = "지뢰밭 제거 (%1개, ~%2 m)"

ctld.i18n["en"]["Mine Field cleared by %1."]               = "Mine Field cleared by %1."
ctld.i18n["fr"]["Mine Field cleared by %1."]               = "Champ de mines déminé par %1."
ctld.i18n["es"]["Mine Field cleared by %1."]               = "Campo de minas despejado por %1."
ctld.i18n["ko"]["Mine Field cleared by %1."]               = "%1이(가) 지뢰밭을 제거했습니다."

-- ====================================================================================================
-- CTLD_mineFieldScene.lua (suite)
--
-- Changes vs. original:
--   - mist.dynAddStatic()        → CTLDObjectRegistry.spawnObject("Landmine", ...)
--   - coalitionId undefined bug  → triggerUnitObj:getCoalition()
--   - _spawnedGroup global leak  → local variable
--   - func step signature updated to (triggerUnitObj, spawnedObj, step)
--   - Registration: CTLDSceneManager.getInstance():registerSceneModel(...)
--   - Layout: quinconce (staggered) pattern — odd rows N mines, even rows N-1 mines offset cs/2
--
-- Dependencies: CTLDUtils, CTLDObjectRegistry, CTLDSceneManager
-- DCS API: trigger.action.outText
-- ====================================================================================================

-- ====================================================================================================
-- BLOCK 2 : ObjectRegistry entries required by this scene
-- ====================================================================================================

CTLDObjectRegistry.registerIfAbsent("Landmine", {
    groupType  = "STATIC",
    namePrefix = "Mine",
    type       = "Landmine",
    category   = "Fortifications",
})

-- ====================================================================================================
-- BLOCK 3 : scene definition + crate attributes
-- ====================================================================================================

local mineFieldScene = {}
mineFieldScene.name  = "mineField"

-- Registry of deployed minefield sets.
-- Each entry: { mines={[DCS static obj, ...]}, center={x, z}, markId=N|nil, coalitionId=N }
-- Populated by setLandMine; consumed by clearSet + refreshDemineSection.
mineFieldScene._sets = {}

-- Crate attributes -- auto-injected into CTLDCrateManager._weightIndex by _processSpawnableCrates().
mineFieldScene.crate = {
    weight         = 1001.25,
    i18nKey        = "Mine Field Crate",
    deployKey      = "Deploy Mine Field",
    cratesRequired = 1,
    side           = nil,
    showSets       = false,
}

mineFieldScene.steps = {
    -- Step 1: deploy minefield (func-only — positions computed inside)
    {
        delayAfterPreviousStep = 0,
        func = function(ctx)
            local success, result = mineFieldScene.setLandMine(ctx.unit, 20, 5, 15, 6, 12)
            if trigger and trigger.action and trigger.action.outText then
                trigger.action.outText(
                    ctld.tr("--- mineField Deployed by %1 ---", ctx.unit:getName()), 10)
            end
            return success, result
        end,
    },
}

-- ====================================================================================================
-- mineFieldScene.setLandMine
-- Computes a quinconce (staggered) grid of landmine positions relative to triggerUnitObj
-- and spawns them.
--
-- Layout (nbMinesColumns >= 2):
--   odd rows  : N mines,   centered
--   even rows : N-1 mines, shifted laterally by colSpacing/2
--
-- Special cases:
--   nbMines == 1                  → single mine, diamond F10 marker
--   nbMinesColumns < 2            → straight forward column, no stagger
--
-- @param triggerUnitObj                   DCS Unit object
-- @param distanceOf1stMineFromHeliInMeter number  distance from unit to first row (metres)
-- @param nbMinesColumns                   number  mines per odd (full) row
-- @param nbMinesPerColumns                number  total number of rows
-- @param distanceBetweenColumnsInMeters   number  lateral spacing between adjacent mines (metres)
-- @param distanceBetweenLinesInMeters     number  forward spacing between rows (metres)
-- @return boolean, table|string  success flag + spawned object array or error message
-- ====================================================================================================
function mineFieldScene.setLandMine(triggerUnitObj, distanceOf1stMineFromHeliInMeter, nbMinesColumns, nbMinesPerColumns,
                                    distanceBetweenColumnsInMeters, distanceBetweenLinesInMeters)
    if not triggerUnitObj then
        return false, "ERROR mineFieldScene.setLandMine(): no triggerUnitObj or nbLines <= 0"
    end

    local triggerUnitPosition     = triggerUnitObj:getPosition()
    local triggerUnitHeadingInRad = ctld.utils.getHeadingInRadians(
                                        "mineFieldScene.setLandMine", triggerUnitObj, true)
    local coalitionId             = triggerUnitObj:getCoalition()
    local countryId               = triggerUnitObj:getCountry()

    local nbMines     = nbMinesColumns * nbMinesPerColumns
    local spawnedObjs = {}

    if nbMines <= 0 then
        return false, "ERROR mineFieldScene.setLandMine(): no triggerUnitObj or nbLines <= 0"
    end

    distanceBetweenLinesInMeters = distanceBetweenLinesInMeters or 12

    local vec3Points1To4 = {}
    local unitVec2       = { x = triggerUnitPosition.p.x, y = triggerUnitPosition.p.z }

    -- Spawn a single mine at a Vec2 position {x, y}
    local function spawnAt(pos)
        local obj = CTLDObjectRegistry.spawnObject(
            "Landmine", coalitionId, countryId,
            pos.x, pos.y, 0, nil)
        if obj then
            spawnedObjs[#spawnedObjs + 1] = obj
        end
    end

    if nbMines == 1 then
        -- ----------------------------------------------------------------
        -- Single mine — diamond F10 marker
        -- ----------------------------------------------------------------
        local pt = ctld.utils.GetRelativeVec2Coords(
            unitVec2, triggerUnitHeadingInRad,
            distanceOf1stMineFromHeliInMeter, 0)
        spawnAt(pt)
        -- Square aligned with aircraft heading (3m half-side)
        local half = 3
        local fwd  = ctld.utils.GetRelativeVec2Coords(pt, triggerUnitHeadingInRad,  half,  0)
        local bwd  = ctld.utils.GetRelativeVec2Coords(pt, triggerUnitHeadingInRad, -half,  0)
        local tl   = ctld.utils.GetRelativeVec2Coords(fwd, triggerUnitHeadingInRad, -half, 90)
        local tr   = ctld.utils.GetRelativeVec2Coords(fwd, triggerUnitHeadingInRad,  half, 90)
        local br   = ctld.utils.GetRelativeVec2Coords(bwd, triggerUnitHeadingInRad,  half, 90)
        local bl   = ctld.utils.GetRelativeVec2Coords(bwd, triggerUnitHeadingInRad, -half, 90)
        vec3Points1To4[1] = { x = tl.x, y = 0, z = tl.y }
        vec3Points1To4[2] = { x = tr.x, y = 0, z = tr.y }
        vec3Points1To4[3] = { x = br.x, y = 0, z = br.y }
        vec3Points1To4[4] = { x = bl.x, y = 0, z = bl.y }

    elseif nbMinesColumns < 2 then
        -- ----------------------------------------------------------------
        -- Single column: straight forward line, no stagger
        -- ----------------------------------------------------------------
        local refPoint = ctld.utils.GetRelativeVec2Coords(
            unitVec2, triggerUnitHeadingInRad,
            distanceOf1stMineFromHeliInMeter, 0)
        for r = 1, nbMinesPerColumns do
            local pos = ctld.utils.GetRelativeVec2Coords(
                refPoint, triggerUnitHeadingInRad,
                (r - 1) * distanceBetweenLinesInMeters, 0)
            spawnAt(pos)
        end
        local lastPos = ctld.utils.GetRelativeVec2Coords(
            refPoint, triggerUnitHeadingInRad,
            (nbMinesPerColumns - 1) * distanceBetweenLinesInMeters, 0)
        vec3Points1To4[1] = { x = refPoint.x - 3, y = 0, z = refPoint.y }
        vec3Points1To4[2] = { x = refPoint.x + 3, y = 0, z = refPoint.y }
        vec3Points1To4[3] = { x = lastPos.x  + 3, y = 0, z = lastPos.y  }
        vec3Points1To4[4] = { x = lastPos.x  - 3, y = 0, z = lastPos.y  }

    else
        -- ----------------------------------------------------------------
        -- Quinconce (staggered) layout — nbMinesColumns >= 2
        --   odd rows  (r=1,3,...) : N mines,   leftmost at -halfWidth
        --   even rows (r=2,4,...) : N-1 mines, leftmost at -halfWidth + cs/2
        -- ----------------------------------------------------------------
        local refPoint  = ctld.utils.GetRelativeVec2Coords(
            unitVec2, triggerUnitHeadingInRad,
            distanceOf1stMineFromHeliInMeter, 0)
        local halfWidth = ((nbMinesColumns - 1) / 2) * distanceBetweenColumnsInMeters

        for r = 1, nbMinesPerColumns do
            local rowCenter = ctld.utils.GetRelativeVec2Coords(
                refPoint, triggerUnitHeadingInRad,
                (r - 1) * distanceBetweenLinesInMeters, 0)

            local minesInRow, leftmostLateral
            if r % 2 == 1 then
                -- Odd row: full width
                minesInRow      = nbMinesColumns
                leftmostLateral = -halfWidth
            else
                -- Even row: one mine less, shifted right by cs/2
                minesInRow      = nbMinesColumns - 1
                leftmostLateral = -halfWidth + distanceBetweenColumnsInMeters / 2
            end

            for col = 1, minesInRow do
                local lateralOffset = leftmostLateral + (col - 1) * distanceBetweenColumnsInMeters
                local pos = ctld.utils.GetRelativeVec2Coords(
                    rowCenter, triggerUnitHeadingInRad, lateralOffset, 90)
                spawnAt(pos)
            end
        end

        -- Bounding rectangle corners (based on full-row lateral extent)
        local lastRowCenter = ctld.utils.GetRelativeVec2Coords(
            refPoint, triggerUnitHeadingInRad,
            (nbMinesPerColumns - 1) * distanceBetweenLinesInMeters, 0)
        local tl = ctld.utils.GetRelativeVec2Coords(refPoint,      triggerUnitHeadingInRad, -halfWidth, 90)
        local tr = ctld.utils.GetRelativeVec2Coords(refPoint,      triggerUnitHeadingInRad,  halfWidth, 90)
        local br = ctld.utils.GetRelativeVec2Coords(lastRowCenter, triggerUnitHeadingInRad,  halfWidth, 90)
        local bl = ctld.utils.GetRelativeVec2Coords(lastRowCenter, triggerUnitHeadingInRad, -halfWidth, 90)
        vec3Points1To4[1] = { x = tl.x, y = 0, z = tl.y }
        vec3Points1To4[2] = { x = tr.x, y = 0, z = tr.y }
        vec3Points1To4[3] = { x = br.x, y = 0, z = br.y }
        vec3Points1To4[4] = { x = bl.x, y = 0, z = bl.y }
    end

    -- Draw bounding quadrilateral on the F10 map (unless disabled in config).
    -- drawQuad returns the markId so the set can be removed later.
    local lastSpawned = spawnedObjs[#spawnedObjs]
    local markId = nil
    if lastSpawned and ctld.gs("showMinefieldOnF10Map") ~= false then
        markId = ctld.utils.drawQuad(coalitionId, vec3Points1To4, lastSpawned:getName())
    end

    -- Register the deployed set for demine tracking.
    local centerX = (vec3Points1To4[1].x + vec3Points1To4[2].x
                   + vec3Points1To4[3].x + vec3Points1To4[4].x) / 4
    local centerZ = (vec3Points1To4[1].z + vec3Points1To4[2].z
                   + vec3Points1To4[3].z + vec3Points1To4[4].z) / 4
    mineFieldScene._sets[#mineFieldScene._sets + 1] = {
        mines       = spawnedObjs,
        center      = { x = centerX, z = centerZ },
        markId      = markId,
        coalitionId = coalitionId,
    }

    return true, spawnedObjs
end

-- ====================================================================================================
-- mineFieldScene.setLandMineAuto
-- Parametric minefield: derives column count and row count automatically from a target area
-- (width × length in metres) and a desired total mine count, then delegates to setLandMine.
--
-- The layout is always quinconce (staggered rows):
--   odd rows  : N mines
--   even rows : N-1 mines, laterally offset by colSpacing/2
-- Total for N cols and R rows: T(N,R) = R*N - floor(R/2)
--
-- The algorithm finds the (N, R) pair whose T(N,R) is closest to nbMines while respecting
-- the requested aspect ratio (width/length).  Column and line spacings are derived from the
-- dimensions: cs = width/(N-1),  ls = length/(R-1).
--
-- @param triggerUnitObj  DCS Unit object — defines origin and heading
-- @param distFromUnit    number  forward distance (m) from unit to first mine row
-- @param widthMeters     number  lateral extent of the minefield (m)
-- @param lengthMeters    number  forward extent of the minefield (m)
-- @param nbMines         number  desired number of mines
-- @return boolean, table|string  success flag + spawned object array or error message
--
-- Example (MM usage):
--   local ok, result = mineFieldScene.setLandMineAuto(transport, 30, 50, 80, 40)
--   -- lays ~40 mines in a 50 m wide × 80 m long staggered field starting 30 m ahead
-- ====================================================================================================
function mineFieldScene.setLandMineAuto(triggerUnitObj, distFromUnit, widthMeters, lengthMeters, nbMines)
    if not triggerUnitObj then
        return false, "ERROR mineFieldScene.setLandMineAuto(): triggerUnitObj is nil"
    end
    if not nbMines or nbMines < 1 then
        return false, "ERROR mineFieldScene.setLandMineAuto(): nbMines must be >= 1"
    end
    if not widthMeters or widthMeters <= 0 or not lengthMeters or lengthMeters <= 0 then
        return false, "ERROR mineFieldScene.setLandMineAuto(): widthMeters and lengthMeters must be > 0"
    end

    -- Single mine: bypass layout computation
    if nbMines == 1 then
        return mineFieldScene.setLandMine(triggerUnitObj, distFromUnit, 1, 1, widthMeters, lengthMeters)
    end

    -- T(N,R) = R*N - floor(R/2)  →  R ≈ nbMines / (N - 0.5)
    local function countForNR(N, R)
        return R * N - math.floor(R / 2)
    end

    -- Estimate N from aspect ratio; clamp to [2, 50]
    local N0 = math.max(2, math.min(50, math.floor(math.sqrt(nbMines * widthMeters / lengthMeters) + 0.5)))

    local bestN, bestR, bestDiff = N0, 1, math.huge
    for _, N in ipairs({ N0 - 1, N0, N0 + 1 }) do
        if N >= 2 then
            local R = math.max(1, math.min(200, math.floor(nbMines / (N - 0.5) + 0.5)))
            for _, Rc in ipairs({ R - 1, R, R + 1 }) do
                if Rc >= 1 then
                    local diff = math.abs(countForNR(N, Rc) - nbMines)
                    if diff < bestDiff then
                        bestDiff, bestN, bestR = diff, N, Rc
                    end
                end
            end
        end
    end

    local cs = widthMeters  / (bestN - 1)
    local ls = lengthMeters / math.max(1, bestR - 1)

    return mineFieldScene.setLandMine(triggerUnitObj, distFromUnit, bestN, bestR, cs, ls)
end

-- ====================================================================================================
-- mineFieldScene.clearSet
-- Destroys all mines in a tracked set and removes its F10 marker.
-- After clearing, the set is removed from mineFieldScene._sets.
--
-- @param idx  number  index in mineFieldScene._sets
-- ====================================================================================================
function mineFieldScene.clearSet(idx)
    local s = mineFieldScene._sets[idx]
    if not s then return end

    for _, obj in ipairs(s.mines) do
        local ok, exists = pcall(function() return obj:isExist() end)
        if ok and exists then
            obj:destroy()
        end
    end

    if s.markId then
        trigger.action.removeMark(s.markId)
        ctld.utils.marks[s.markId] = nil
    end

    table.remove(mineFieldScene._sets, idx)
end

-- ====================================================================================================
-- mineFieldScene:refreshDemineSection
-- Rebuilds the "Mine Field" submenu for playerObj.
-- Lists each deployed set within demineRadius with a "Clear Mine Field (N mines, ~Xm)" command.
-- Called on S_EVENT_LAND and whenever a set is cleared.
--
-- @param playerObj CTLDPlayer
-- ====================================================================================================
function mineFieldScene:refreshDemineSection(playerObj)
    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root    = ctld.tr("CTLD")
    local mineSub = ctld.tr("Mine Field")
    menu:clearBranch({ root, mineSub })

    local unit = Unit.getByName(playerObj.unitName)
    if not unit or not unit:isExist() then return end
    if unit:inAir() then return end

    local pt     = unit:getPoint()
    local radius = ctld.gs("demineRadius") or 150

    for idx, s in ipairs(mineFieldScene._sets) do
        -- Count alive mines in this set.
        local aliveCount = 0
        for _, obj in ipairs(s.mines) do
            local ok, exists = pcall(function() return obj:isExist() end)
            if ok and exists then aliveCount = aliveCount + 1 end
        end

        if aliveCount > 0 then
            local dist = ctld.utils.getDistance(
                "mineFieldScene:refreshDemineSection",
                { x = pt.x, z = pt.z },
                { x = s.center.x, z = s.center.z }
            )
            if dist <= radius then
                local label = ctld.tr("Clear Mine Field (%1 mines, ~%2 m)",
                    aliveCount, math.floor(dist))
                -- Capture center coords to find the set robustly at click time
                -- (index may shift if another set was cleared in the meantime).
                local cx, cz = s.center.x, s.center.z
                menu:addCommand({ root, mineSub }, label,
                    function(arg)
                        local t = Unit.getByName(arg.unitName)
                        if not (t and t:isExist()) then return end
                        if t:inAir() then return end

                        -- Find set by center match.
                        local foundIdx = nil
                        for i, ss in ipairs(mineFieldScene._sets) do
                            if math.abs(ss.center.x - arg.cx) < 1
                            and math.abs(ss.center.z - arg.cz) < 1 then
                                foundIdx = i
                                break
                            end
                        end
                        if not foundIdx then return end

                        mineFieldScene.clearSet(foundIdx)
                        trigger.action.outText(
                            ctld.tr("Mine Field cleared by %1.", t:getName()), 10)

                        -- Refresh the demine section for all tracked players.
                        local pm = CTLDPlayerManager.getInstance()
                        for _, pObj in pairs(pm._players) do
                            mineFieldScene:refreshDemineSection(pObj)
                        end
                    end,
                    { unitName = playerObj.unitName, cx = cx, cz = cz })
            end
        end
    end
end

-- ====================================================================================================
-- mineFieldScene:buildDemineSection
-- Creates the "Mine Field" submenu container and populates it via refreshDemineSection.
-- Registered with CTLDPlayerManager as a menu section (called once per player on menu build).
--
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
-- ====================================================================================================
function mineFieldScene:buildDemineSection(playerObj, menu)
    local root    = ctld.tr("CTLD")
    local mineSub = ctld.tr("Mine Field")
    menu:addSubMenu({ root }, mineSub, { order = 75 })
    self:refreshDemineSection(playerObj)
end

-- ====================================================================================================
-- BLOCK 4 : self-registration (always last)
-- ====================================================================================================

CTLDSceneManager.getInstance():registerSceneModel(mineFieldScene)

-- Register the demine menu section so it appears in F10 CTLD menus.
-- Uses deferMenuSection (class-level) so this is safe to call before CTLDCoreManager init.
-- refreshMethod is called by CTLDPlayerManager:onLand to update proximity-based content.
CTLDPlayerManager.deferMenuSection({
    key           = "minefield_demine",
    manager       = mineFieldScene,
    method        = "buildDemineSection",
    refreshMethod = "refreshDemineSection",
    order         = 75,
})
