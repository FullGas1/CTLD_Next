---@diagnostic disable
-- tests/unit/troop_manager_spec.lua
-- busted specs for CTLDTroopGroup and CTLDTroopManager
-- Reference: live_tests/unit/U-035 through U-038, U-076 through U-081
-- CTLD_Next adaptations vs DCS-CTLD_FG references:
--   * STATE.TRZ_LOADED (not LOADED) is the initial state
--   * isInTransit() = true for TRZ_LOADED | FIELD_LOADED
--   * _inTransit[unitName] = list of groups (not single group)
--   * getInTransit() returns list-or-nil (not single group)
--   * _transportLimit uses capabilitiesByType[t].maxTroopsOnboard (not transportLimitByType)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopGroup entity", function()

    local function makeGroup(overrides)
        local data = {
            templateKey  = "troop_squad",
            templateName = "Infantry Squad",
            unitTotal    = 5,
            weight       = 545,
            coalitionId  = coalition.side.BLUE,
            countryId    = 2,
        }
        if overrides then
            for k, v in pairs(overrides) do data[k] = v end
        end
        return CTLDTroopGroup:new(data)
    end

    -- ── Initial state (U-035) ─────────────────────────────────
    describe("initial state (U-035)", function()

        it("new() returns a non-nil object", function()
            assert.is_not_nil(makeGroup())
        end)

        it("state is TRZ_LOADED after new()", function()
            assert.equals(CTLDTroopGroup.STATE.TRZ_LOADED, makeGroup().state)
        end)

        it("templateKey is stored", function()
            assert.equals("troop_squad", makeGroup().templateKey)
        end)

        it("templateName is stored", function()
            assert.equals("Infantry Squad", makeGroup().templateName)
        end)

        it("unitTotal is stored", function()
            assert.equals(5, makeGroup().unitTotal)
        end)

        it("weight is stored", function()
            assert.equals(545, makeGroup().weight)
        end)

        it("dcsGroup is nil after new()", function()
            assert.is_nil(makeGroup().dcsGroup)
        end)

        it("isInTransit() is true when TRZ_LOADED", function()
            assert.is_true(makeGroup():isInTransit())
        end)

    end)

    -- ── State transitions (U-035) ─────────────────────────────
    describe("state transitions (U-035)", function()

        it("deploy(nil) transitions to DEPLOYED (EXZ silent drop)", function()
            local g = makeGroup()
            g:deploy(nil)
            assert.equals(CTLDTroopGroup.STATE.DEPLOYED, g.state)
        end)

        it("deploy(nil) leaves dcsGroup nil", function()
            local g = makeGroup()
            g:deploy(nil)
            assert.is_nil(g.dcsGroup)
        end)

        it("isInTransit() is false when DEPLOYED", function()
            local g = makeGroup()
            g:deploy(nil)
            assert.is_false(g:isInTransit())
        end)

        it("deploy(mockGroup) sets dcsGroup", function()
            local mock = {
                isExist  = function() return false end,
                getUnits = function() return {} end,
            }
            local g = makeGroup()
            g:deploy(mock)
            assert.equals(mock, g.dcsGroup)
        end)

        it("FIELD_LOADED state also counts as in-transit", function()
            local g = makeGroup({ state = CTLDTroopGroup.STATE.FIELD_LOADED })
            assert.is_true(g:isInTransit())
        end)

        it("DEPLOYED_EXZ state is not in-transit", function()
            local g = makeGroup({ state = CTLDTroopGroup.STATE.DEPLOYED_EXZ })
            assert.is_false(g:isInTransit())
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopManager", function()

    -- Reset singleton before each test
    before_each(function()
        CTLDTroopManager._instance = nil
        -- Clear loadableGroups so init doesn't create unexpected templates
        CTLDConfig.get().settings["loadableGroups"] = {}
        CTLDConfig.get().settings["capabilitiesByType"] = nil
    end)

    -- ── Singleton (U-036) ─────────────────────────────────────
    describe("singleton (U-036)", function()

        it("getInstance() returns a non-nil instance", function()
            assert.is_not_nil(CTLDTroopManager.getInstance())
        end)

        it("getInstance() is idempotent", function()
            local m1 = CTLDTroopManager.getInstance()
            local m2 = CTLDTroopManager.getInstance()
            assert.equals(m1, m2)
        end)

        it("instance has _inTransit table", function()
            local m = CTLDTroopManager.getInstance()
            assert.equals("table", type(m._inTransit))
        end)

        it("instance has _droppedGroups table", function()
            local m = CTLDTroopManager.getInstance()
            assert.equals("table", type(m._droppedGroups))
        end)

    end)

    -- ── _registerTemplates (U-036) ────────────────────────────
    describe("_registerTemplates (U-036)", function()

        before_each(function()
            CTLDTroopManager._instance = nil
            CTLDConfig.get().settings["loadableGroups"] = {
                { name = "Alpha Squad", inf = 3, mg = 1, at = 0, aa = 0, mortar = 0, jtac = 0 },
                { name = "Bravo JTAC",  inf = 2, mg = 0, at = 0, aa = 0, mortar = 0, jtac = 1 },
            }
        end)

        it("_templateCount equals number of loadableGroups", function()
            local m = CTLDTroopManager.getInstance()
            assert.equals(2, m._templateCount)
        end)

        it("template[1]._dbKey is assigned", function()
            local m = CTLDTroopManager.getInstance()
            assert.is_not_nil(m._templates[1]._dbKey)
        end)

        it("template[1].total == 4 (3 inf + 1 mg)", function()
            local m = CTLDTroopManager.getInstance()
            assert.equals(4, m._templates[1].total)
        end)

        it("template[1].hasJtac == false", function()
            local m = CTLDTroopManager.getInstance()
            assert.is_false(m._templates[1].hasJtac)
        end)

        it("template[2].total == 3 (2 inf + 1 jtac)", function()
            local m = CTLDTroopManager.getInstance()
            assert.equals(3, m._templates[2].total)
        end)

        it("template[2].hasJtac == true", function()
            local m = CTLDTroopManager.getInstance()
            assert.is_true(m._templates[2].hasJtac)
        end)

        it("ObjectRegistry entry created for template[1]", function()
            local m = CTLDTroopManager.getInstance()
            assert.is_not_nil(CTLDObjectRegistry._db[m._templates[1]._dbKey])
        end)

        it("ObjectRegistry entry groupType is GROUND", function()
            local m = CTLDTroopManager.getInstance()
            local entry = CTLDObjectRegistry._db[m._templates[1]._dbKey]
            assert.equals("GROUND", entry.groupType)
        end)

        it("ObjectRegistry entry has 4 units for template[1]", function()
            local m = CTLDTroopManager.getInstance()
            local entry = CTLDObjectRegistry._db[m._templates[1]._dbKey]
            assert.equals(4, #entry.units)
        end)

    end)

    -- ── hasTroops / getInTransit / getWeight (U-037) ──────────
    describe("hasTroops / getInTransit / getWeight (U-037)", function()

        local mgr
        local grp

        before_each(function()
            mgr = CTLDTroopManager.getInstance()
            grp = CTLDTroopGroup:new({
                templateKey  = "k",
                templateName = "Squad A",
                unitTotal    = 4,
                weight       = 436,
                coalitionId  = coalition.side.BLUE,
                countryId    = 2,
            })
        end)

        it("hasTroops unknown unit == false", function()
            assert.is_false(mgr:hasTroops("heli_1"))
        end)

        it("getInTransit unknown unit == nil", function()
            assert.is_nil(mgr:getInTransit("heli_1"))
        end)

        it("getWeight unknown unit == 0", function()
            assert.equals(0, mgr:getWeight("heli_1"))
        end)

        it("hasTroops == true after injection", function()
            mgr._inTransit["heli_1"] = { grp }
            assert.is_true(mgr:hasTroops("heli_1"))
        end)

        it("getInTransit returns list after injection", function()
            mgr._inTransit["heli_1"] = { grp }
            local list = mgr:getInTransit("heli_1")
            assert.is_not_nil(list)
            assert.equals(grp, list[1])
        end)

        it("getWeight returns group weight after injection", function()
            mgr._inTransit["heli_1"] = { grp }
            assert.equals(436, mgr:getWeight("heli_1"))
        end)

        it("different unit has no troops", function()
            mgr._inTransit["heli_1"] = { grp }
            assert.is_false(mgr:hasTroops("heli_2"))
        end)

        it("hasTroops == false after removal", function()
            mgr._inTransit["heli_1"] = { grp }
            mgr._inTransit["heli_1"] = nil
            assert.is_false(mgr:hasTroops("heli_1"))
        end)

        it("getWeight returns sum of multiple groups", function()
            local grp2 = CTLDTroopGroup:new({
                templateKey="k2", templateName="Squad B",
                unitTotal=2, weight=200,
                coalitionId=coalition.side.BLUE, countryId=2,
            })
            mgr._inTransit["heli_1"] = { grp, grp2 }
            assert.equals(636, mgr:getWeight("heli_1"))
        end)

    end)

    -- ── _transportLimit (U-038) ───────────────────────────────
    describe("_transportLimit (U-038)", function()

        local mgr

        before_each(function()
            CTLDConfig.get().settings["numberOfTroops"]      = 10
            CTLDConfig.get().settings["capabilitiesByType"]  = nil
            mgr = CTLDTroopManager.getInstance()
        end)

        it("default fallback == numberOfTroops", function()
            assert.equals(10, mgr:_transportLimit("UH-1H"))
        end)

        it("default fallback applies to any unknown type", function()
            assert.equals(10, mgr:_transportLimit("ANY_AIRCRAFT"))
        end)

        it("per-type override via capabilitiesByType", function()
            CTLDConfig.get().settings["capabilitiesByType"] = {
                ["UH-1H"]  = { maxTroopsOnboard = 8 },
                ["CH-47D"] = { maxTroopsOnboard = 20 },
            }
            assert.equals(8,  mgr:_transportLimit("UH-1H"))
            assert.equals(20, mgr:_transportLimit("CH-47D"))
        end)

        it("type without override falls back to numberOfTroops", function()
            CTLDConfig.get().settings["capabilitiesByType"] = {
                ["UH-1H"] = { maxTroopsOnboard = 8 },
            }
            assert.equals(10, mgr:_transportLimit("Mi-8MT"))
        end)

        it("fallback follows updated numberOfTroops", function()
            CTLDConfig.get().settings["numberOfTroops"] = 6
            assert.equals(6, mgr:_transportLimit("Unknown"))
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
-- Feature D tests (U-076 → U-081)
-- These use a common setup: 2 standard templates.
-- ─────────────────────────────────────────────────────────────

local function _setupManagerWithTwoTemplates()
    CTLDTroopManager._instance = nil
    CTLDConfig.get().settings["loadableGroups"] = {
        { name = "Standard Group", inf = 10 },
        { name = "JTAC Group",     inf = 4, jtac = 1 },
    }
    return CTLDTroopManager.getInstance()
end

describe("CTLDTroopManager createLoadableGroup", function()

    local mgr

    before_each(function()
        mgr = _setupManagerWithTwoTemplates()
    end)

    -- ── Valid cases (U-076) ────────────────────────────────────
    describe("valid cases (U-076)", function()

        it("initial template count is 2", function()
            assert.equals(2, #mgr._templates)
        end)

        it("mortar-only group: returns true", function()
            local ok = mgr:createLoadableGroup({
                name        = "Mortar Only",
                composition = { mortar = 8 },
            })
            assert.is_true(ok)
        end)

        it("mortar-only group: template added", function()
            mgr:createLoadableGroup({ name="MortarX", composition={ mortar=8 } })
            assert.equals(3, #mgr._templates)
        end)

        it("mortar-only group: _findTemplate returns entry", function()
            mgr:createLoadableGroup({ name="MortarY", composition={ mortar=4 } })
            assert.is_not_nil(mgr:_findTemplate("MortarY"))
        end)

        it("mortar-only: total computed correctly", function()
            mgr:createLoadableGroup({ name="Mort8", composition={ mortar=8 } })
            local t = mgr:_findTemplate("Mort8")
            assert.equals(8, t.total)
        end)

        it("mortar-only: inf defaults to 0", function()
            mgr:createLoadableGroup({ name="MortZ", composition={ mortar=3 } })
            local t = mgr:_findTemplate("MortZ")
            assert.equals(0, t.inf)
        end)

        it("custom=true for created group", function()
            mgr:createLoadableGroup({ name="CustA", composition={ inf=4 } })
            assert.is_true(mgr:_findTemplate("CustA").custom)
        end)

        it("disabled=false for created group", function()
            mgr:createLoadableGroup({ name="CustB", composition={ inf=4 } })
            assert.is_false(mgr:_findTemplate("CustB").disabled)
        end)

        it("_dbKey assigned for custom group", function()
            mgr:createLoadableGroup({ name="CustC", composition={ inf=4 } })
            assert.is_not_nil(mgr:_findTemplate("CustC")._dbKey)
        end)

        it("CTLDObjectRegistry entry created for custom group", function()
            mgr:createLoadableGroup({ name="CustD", composition={ inf=4 } })
            local t = mgr:_findTemplate("CustD")
            assert.is_not_nil(CTLDObjectRegistry._db[t._dbKey])
        end)

        it("heavy squad: total == 15 (8+2+2+1+1+1)", function()
            mgr:createLoadableGroup({
                name = "Heavy Squad",
                composition = { inf=8, mg=2, at=2, aa=1, mortar=1, jtac=1 },
            })
            assert.equals(15, mgr:_findTemplate("Heavy Squad").total)
        end)

        it("heavy squad: hasJtac == true", function()
            mgr:createLoadableGroup({
                name = "Heavy2",
                composition = { inf=8, mg=2, at=2, aa=1, mortar=1, jtac=1 },
            })
            assert.is_true(mgr:_findTemplate("Heavy2").hasJtac)
        end)

        it("side=nil stored as nil", function()
            mgr:createLoadableGroup({ name="Univ", composition={ inf=4 } })
            assert.is_nil(mgr:_findTemplate("Univ").side)
        end)

        it("standard templates remain after custom create", function()
            mgr:createLoadableGroup({ name="Extra", composition={ inf=1 } })
            assert.is_not_nil(mgr:_findTemplate("Standard Group"))
            assert.is_false(mgr:_findTemplate("Standard Group").custom)
        end)

    end)

    -- ── Guard / error cases (U-077) ───────────────────────────
    describe("guard cases (U-077)", function()

        it("nil config returns false", function()
            local ok = mgr:createLoadableGroup(nil)
            assert.is_false(ok)
        end)

        it("nil config returns error message", function()
            local _, e = mgr:createLoadableGroup(nil)
            assert.is_not_nil(e)
        end)

        it("missing name returns false", function()
            local ok = mgr:createLoadableGroup({ composition = { inf=4 } })
            assert.is_false(ok)
        end)

        it("empty name returns false", function()
            local ok = mgr:createLoadableGroup({ name="", composition={ inf=4 } })
            assert.is_false(ok)
        end)

        it("missing composition returns false", function()
            local ok = mgr:createLoadableGroup({ name="X" })
            assert.is_false(ok)
        end)

        it("all-zero composition returns false", function()
            local ok = mgr:createLoadableGroup({
                name="Empty", composition={ inf=0, mg=0, at=0 }
            })
            assert.is_false(ok)
        end)

        it("duplicate name (standard) returns false", function()
            local ok = mgr:createLoadableGroup({
                name="Standard Group", composition={ inf=1 }
            })
            assert.is_false(ok)
        end)

        it("duplicate custom name returns false", function()
            mgr:createLoadableGroup({ name="Recon", composition={ inf=4, jtac=1 } })
            local ok = mgr:createLoadableGroup({ name="Recon", composition={ inf=2 } })
            assert.is_false(ok)
        end)

        it("template count unchanged after multiple failed creates", function()
            mgr:createLoadableGroup({ name="ValidOne", composition={ inf=4 } })
            mgr:createLoadableGroup(nil)
            mgr:createLoadableGroup({ composition={ inf=4 } })
            mgr:createLoadableGroup({ name="", composition={ inf=4 } })
            assert.equals(3, #mgr._templates)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopManager removeLoadableGroup", function()

    local mgr

    before_each(function()
        mgr = _setupManagerWithTwoTemplates()
    end)

    -- ── U-078 ─────────────────────────────────────────────────
    it("add then remove custom: returns true", function()
        mgr:createLoadableGroup({ name="Custom Alpha", composition={ inf=4 } })
        local ok = mgr:removeLoadableGroup("Custom Alpha")
        assert.is_true(ok)
    end)

    it("remove custom: template count decremented", function()
        mgr:createLoadableGroup({ name="Del Me", composition={ inf=4 } })
        mgr:removeLoadableGroup("Del Me")
        assert.equals(2, #mgr._templates)
    end)

    it("remove custom: _findTemplate returns nil after remove", function()
        mgr:createLoadableGroup({ name="Bye", composition={ inf=4 } })
        mgr:removeLoadableGroup("Bye")
        assert.is_nil(mgr:_findTemplate("Bye"))
    end)

    it("remove custom: ObjectRegistry entry cleared", function()
        mgr:createLoadableGroup({ name="ClearMe", composition={ inf=4 } })
        local dbKey = mgr:_findTemplate("ClearMe")._dbKey
        mgr:removeLoadableGroup("ClearMe")
        assert.is_nil(CTLDObjectRegistry._db[dbKey])
    end)

    it("remove standard template: returns true (no guard)", function()
        local ok = mgr:removeLoadableGroup("Standard Group")
        assert.is_true(ok)
    end)

    it("remove standard template: template count decremented", function()
        mgr:removeLoadableGroup("Standard Group")
        assert.equals(1, #mgr._templates)
    end)

    it("remove non-existent: returns false", function()
        local ok = mgr:removeLoadableGroup("Does Not Exist")
        assert.is_false(ok)
    end)

    it("remove non-existent: returns error message", function()
        local _, e = mgr:removeLoadableGroup("Does Not Exist")
        assert.is_not_nil(e)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopManager editLoadableGroup", function()

    local mgr

    before_each(function()
        mgr = _setupManagerWithTwoTemplates()
        mgr:createLoadableGroup({
            name        = "Custom Bravo",
            composition = { inf=6, at=2 },
            side        = 2,
        })
    end)

    -- ── U-079 ─────────────────────────────────────────────────
    it("initial Custom Bravo total == 8", function()
        assert.equals(8, mgr:_findTemplate("Custom Bravo").total)
    end)

    it("edit composition: returns true", function()
        local ok = mgr:editLoadableGroup("Custom Bravo", {
            composition = { inf=4, at=4, jtac=1 },
        })
        assert.is_true(ok)
    end)

    it("edit composition: total recomputed to 9", function()
        mgr:editLoadableGroup("Custom Bravo", { composition={ inf=4, at=4, jtac=1 } })
        assert.equals(9, mgr:_findTemplate("Custom Bravo").total)
    end)

    it("edit composition: hasJtac recomputed to true", function()
        mgr:editLoadableGroup("Custom Bravo", { composition={ inf=4, at=4, jtac=1 } })
        assert.is_true(mgr:_findTemplate("Custom Bravo").hasJtac)
    end)

    it("edit side only: returns true", function()
        local ok = mgr:editLoadableGroup("Custom Bravo", { side=1 })
        assert.is_true(ok)
    end)

    it("edit side only: total unchanged", function()
        mgr:editLoadableGroup("Custom Bravo", { side=1 })
        assert.equals(8, mgr:_findTemplate("Custom Bravo").total)
    end)

    it("_dbKey unchanged after edit", function()
        local key = mgr:_findTemplate("Custom Bravo")._dbKey
        mgr:editLoadableGroup("Custom Bravo", { composition={ inf=4, at=4, jtac=1 } })
        assert.equals(key, mgr:_findTemplate("Custom Bravo")._dbKey)
    end)

    it("ObjectRegistry units count updated after edit", function()
        mgr:editLoadableGroup("Custom Bravo", { composition={ inf=4, at=4, jtac=1 } })
        local t = mgr:_findTemplate("Custom Bravo")
        assert.equals(9, #CTLDObjectRegistry._db[t._dbKey].units)
    end)

    it("guard: edit standard template returns false", function()
        local ok = mgr:editLoadableGroup("Standard Group", { composition={ inf=1 } })
        assert.is_false(ok)
    end)

    it("guard: edit standard template returns error", function()
        local _, e = mgr:editLoadableGroup("Standard Group", { composition={ inf=1 } })
        assert.is_not_nil(e)
    end)

    it("guard: edit unknown template returns false", function()
        local ok = mgr:editLoadableGroup("Ghost", { composition={ inf=1 } })
        assert.is_false(ok)
    end)

    it("guard: zero composition returns false", function()
        local ok = mgr:editLoadableGroup("Custom Bravo", {
            composition = { inf=0, at=0, jtac=0 },
        })
        assert.is_false(ok)
    end)

    it("guard: zero composition leaves total unchanged", function()
        local origTotal = mgr:_findTemplate("Custom Bravo").total
        mgr:editLoadableGroup("Custom Bravo", { composition={ inf=0, at=0, jtac=0 } })
        assert.equals(origTotal, mgr:_findTemplate("Custom Bravo").total)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopManager disable/enableLoadableGroup", function()

    local mgr

    before_each(function()
        mgr = _setupManagerWithTwoTemplates()
    end)

    -- ── U-080 ─────────────────────────────────────────────────
    it("all templates start with disabled=false", function()
        for _, tmpl in ipairs(mgr._templates) do
            assert.is_false(tmpl.disabled)
        end
    end)

    it("disable standard: returns true", function()
        local ok = mgr:disableLoadableGroup("Standard Group")
        assert.is_true(ok)
    end)

    it("disable standard: disabled=true", function()
        mgr:disableLoadableGroup("Standard Group")
        assert.is_true(mgr:_findTemplate("Standard Group").disabled)
    end)

    it("disable: template count unchanged", function()
        mgr:disableLoadableGroup("Standard Group")
        assert.equals(2, #mgr._templates)
    end)

    it("enable after disable: disabled=false", function()
        mgr:disableLoadableGroup("Standard Group")
        mgr:enableLoadableGroup("Standard Group")
        assert.is_false(mgr:_findTemplate("Standard Group").disabled)
    end)

    it("enable: returns true", function()
        mgr:disableLoadableGroup("Standard Group")
        local ok = mgr:enableLoadableGroup("Standard Group")
        assert.is_true(ok)
    end)

    it("disable unknown: returns false", function()
        local ok = mgr:disableLoadableGroup("Ghost")
        assert.is_false(ok)
    end)

    it("disable unknown: returns error message", function()
        local _, e = mgr:disableLoadableGroup("Ghost")
        assert.is_not_nil(e)
    end)

    it("enable unknown: returns false", function()
        local ok = mgr:enableLoadableGroup("Ghost")
        assert.is_false(ok)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDTroopManager _resolveTemplateForLegacy", function()

    local mgr

    before_each(function()
        mgr = _setupManagerWithTwoTemplates()
        -- _templates[1]: "Standard Group" total=10
        -- _templates[2]: "JTAC Group" total=5
    end)

    -- ── U-081 ─────────────────────────────────────────────────
    it("integer exact match 10 → Standard Group", function()
        local t = mgr:_resolveTemplateForLegacy(2, 10)
        assert.is_not_nil(t)
        assert.equals("Standard Group", t.name)
    end)

    it("integer closest match 6 → JTAC Group (delta=1 vs delta=4)", function()
        local t = mgr:_resolveTemplateForLegacy(2, 6)
        assert.is_not_nil(t)
        assert.equals("JTAC Group", t.name)
    end)

    it("integer 9 → Standard Group (delta=1)", function()
        local t = mgr:_resolveTemplateForLegacy(1, 9)
        assert.is_not_nil(t)
        assert.equals("Standard Group", t.name)
    end)

    it("integer 0 → JTAC Group (total=5 closer to 0 than 10)", function()
        local t = mgr:_resolveTemplateForLegacy(2, 0)
        assert.is_not_nil(t)
        assert.equals("JTAC Group", t.name)
    end)

    it("composition table sum=10 → Standard Group", function()
        local t = mgr:_resolveTemplateForLegacy(2, { inf=6, mg=2, at=2 })
        assert.is_not_nil(t)
        assert.equals("Standard Group", t.name)
    end)

    it("composition table sum=4 → JTAC Group (delta=1)", function()
        local t = mgr:_resolveTemplateForLegacy(1, { inf=4 })
        assert.is_not_nil(t)
        assert.equals("JTAC Group", t.name)
    end)

    it("disabled template is skipped", function()
        mgr._templates[1].disabled = true
        local t = mgr:_resolveTemplateForLegacy(2, 10)
        mgr._templates[1].disabled = false   -- restore
        assert.equals("JTAC Group", t.name)
    end)

    it("empty templates list returns nil", function()
        local orig = mgr._templates
        mgr._templates = {}
        local t = mgr:_resolveTemplateForLegacy(2, 5)
        mgr._templates = orig
        assert.is_nil(t)
    end)

end)
