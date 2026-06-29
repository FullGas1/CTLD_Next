---@diagnostic disable
-- tests/unit/menu_manager_spec.lua
-- busted specs for ctld.MenuManager singleton, ctld.Menu node operations, and pagination
-- Reference: live_tests/unit/U-057 through U-066
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager singleton", function()
    -- U-057

    before_each(function()
        ctld.MenuManager._instance = nil
    end)

    it("_instance is nil before first call", function()
        assert.is_nil(ctld.MenuManager._instance)
    end)

    it("getInstance() returns a non-nil instance", function()
        assert.is_not_nil(ctld.MenuManager:getInstance())
    end)

    it("getInstance() is idempotent", function()
        local a = ctld.MenuManager:getInstance()
        local b = ctld.MenuManager:getInstance()
        assert.equals(a, b)
    end)

    it("instance has a menus table", function()
        assert.equals("table", type(ctld.MenuManager:getInstance().menus))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager createMenuForGroup", function()
    -- U-058

    local mgr

    before_each(function()
        ctld.MenuManager._instance = nil
        mgr = ctld.MenuManager:getInstance()
    end)

    it("valid numeric groupId returns a menu object", function()
        assert.is_not_nil(mgr:createMenuForGroup(1001))
    end)

    it("returned menu has correct groupId", function()
        local menu = mgr:createMenuForGroup(1001)
        assert.equals(1001, menu.groupId)
    end)

    it("nil groupId returns nil", function()
        assert.is_nil(mgr:createMenuForGroup(nil))
    end)

    it("string groupId returns nil", function()
        assert.is_nil(mgr:createMenuForGroup("Pilot"))
    end)

    it("idempotent: second call returns same object", function()
        local a = mgr:createMenuForGroup(1002)
        local b = mgr:createMenuForGroup(1002)
        assert.equals(a, b)
    end)

    it("menu is stored in manager.menus[groupId]", function()
        local menu = mgr:createMenuForGroup(1003)
        assert.equals(menu, mgr.menus[1003])
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager _sortByOrder", function()
    -- U-059

    it("sorts children ascending by order field", function()
        local children = {
            { name = "C", order = 30 },
            { name = "A", order = 10 },
            { name = "B", order = 20 },
        }
        local sorted = ctld.MenuManager:_sortByOrder(children)
        assert.equals("A", sorted[1].name)
        assert.equals("B", sorted[2].name)
        assert.equals("C", sorted[3].name)
    end)

    it("nodes without order are appended last", function()
        local children = {
            { name = "NoOrder" },
            { name = "First", order = 5 },
        }
        local sorted = ctld.MenuManager:_sortByOrder(children)
        assert.equals("First",   sorted[1].name)
        assert.equals("NoOrder", sorted[2].name)
    end)

    it("empty list returns empty table", function()
        local sorted = ctld.MenuManager:_sortByOrder({})
        assert.equals(0, #sorted)
    end)

    it("nil input returns empty table", function()
        local sorted = ctld.MenuManager:_sortByOrder(nil)
        assert.equals(0, #sorted)
    end)

    it("does not mutate the original list", function()
        local children = {
            { name = "B", order = 20 },
            { name = "A", order = 10 },
        }
        ctld.MenuManager:_sortByOrder(children)
        -- Original order must be preserved
        assert.equals("B", children[1].name)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu addSubMenu", function()

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2001)
    end)

    -- ── Success and options (U-060) ──────────────────────────
    describe("success and options (U-060)", function()

        it("returns success=true", function()
            assert.is_true(menu:addSubMenu({}, "CTLD Commands").success)
        end)

        it("returns a non-nil subMenuId", function()
            assert.is_not_nil(menu:addSubMenu({}, "CTLD Commands").subMenuId)
        end)

        it("idempotent: second call returns same subMenuId", function()
            local r1 = menu:addSubMenu({}, "CTLD Commands")
            local r2 = menu:addSubMenu({}, "CTLD Commands")
            assert.equals(r1.subMenuId, r2.subMenuId)
        end)

        it("opts.order stored on node", function()
            menu:addSubMenu({}, "Ordered", { order = 10 })
            assert.equals(10, menu:_getNode({"Ordered"}).order)
        end)

        it("opts.enabled=false stored on node", function()
            menu:addSubMenu({}, "Hidden", { enabled = false })
            assert.is_false(menu:_getNode({"Hidden"}).enabled)
        end)

        it("enabled defaults to true when not specified", function()
            menu:addSubMenu({}, "Visible")
            assert.is_true(menu:_getNode({"Visible"}).enabled)
        end)

        it("nested addSubMenu creates child node", function()
            menu:addSubMenu({}, "Parent")
            local r = menu:addSubMenu({"Parent"}, "Child")
            assert.is_true(r.success)
            assert.is_not_nil(menu:_getNode({"Parent", "Child"}))
        end)

    end)

    -- ── Guards (U-061) ────────────────────────────────────────
    describe("guards (U-061)", function()

        it("nil name returns success=false and nil subMenuId", function()
            local r = menu:addSubMenu({}, nil)
            assert.is_false(r.success)
            assert.is_nil(r.subMenuId)
        end)

        it("number name returns success=false", function()
            assert.is_false(menu:addSubMenu({}, 42).success)
        end)

        it("parent=command node returns success=false", function()
            menu:addSubMenu({}, "Parent")
            menu:addCommand({"Parent"}, "Leaf", function() end)
            local r = menu:addSubMenu({"Parent", "Leaf"}, "Child")
            assert.is_false(r.success)
        end)

    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu addCommand", function()
    -- U-062

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2002)
    end)

    it("valid call returns success=true", function()
        assert.is_true(menu:addCommand({}, "Load Troops", function() end, {}).success)
    end)

    it("returns a non-nil commandId", function()
        assert.is_not_nil(menu:addCommand({}, "Load Troops", function() end, {}).commandId)
    end)

    it("nil anyArgument defaults to {} on the node", function()
        menu:addCommand({}, "Load Troops", function() end, nil)
        local node = menu:_getNode({"Load Troops"})
        assert.equals("table", type(node.anyArgument))
    end)

    it("nil commandName returns success=false and nil commandId", function()
        local r = menu:addCommand({}, nil, function() end, {})
        assert.is_false(r.success)
        assert.is_nil(r.commandId)
    end)

    it("non-function functionToCall returns success=false", function()
        assert.is_false(menu:addCommand({}, "Bad", "not_a_fn", {}).success)
    end)

    it("non-table anyArgument returns success=false", function()
        assert.is_false(menu:addCommand({}, "Bad", function() end, "string_arg").success)
    end)

    it("parent=command node returns success=false", function()
        menu:addCommand({}, "Leaf", function() end)
        local r = menu:addCommand({"Leaf"}, "Nested", function() end)
        assert.is_false(r.success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu clearBranch", function()
    -- U-063

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2003)
        menu:addSubMenu({}, "Vehicles")
        menu:addCommand({"Vehicles"}, "UH-60", function() end)
        menu:addCommand({"Vehicles"}, "CH-47", function() end)
    end)

    it("returns success=true", function()
        assert.is_true(menu:clearBranch({"Vehicles"}).success)
    end)

    it("children are emptied after clear", function()
        menu:clearBranch({"Vehicles"})
        assert.equals(0, #menu:_getNode({"Vehicles"}).children)
    end)

    it("container node is preserved after clear", function()
        menu:clearBranch({"Vehicles"})
        assert.is_not_nil(menu:_getNode({"Vehicles"}))
    end)

    it("guard: command node returns success=false", function()
        menu:addCommand({}, "TopCmd", function() end)
        assert.is_false(menu:clearBranch({"TopCmd"}).success)
    end)

    it("guard: unknown path returns success=false", function()
        assert.is_false(menu:clearBranch({"NonExistent"}).success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu setBranchEnabled", function()
    -- U-064

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2004)
        menu:addSubMenu({}, "FOB")
    end)

    it("setBranchEnabled(false) marks node enabled=false", function()
        menu:setBranchEnabled({"FOB"}, false)
        assert.is_false(menu:_getNode({"FOB"}).enabled)
    end)

    it("setBranchEnabled(true) marks node enabled=true after disable", function()
        menu:setBranchEnabled({"FOB"}, false)
        menu:setBranchEnabled({"FOB"}, true)
        assert.is_true(menu:_getNode({"FOB"}).enabled)
    end)

    it("returns success=true for known path", function()
        assert.is_true(menu:setBranchEnabled({"FOB"}, false).success)
    end)

    it("returns success=false for unknown path", function()
        assert.is_false(menu:setBranchEnabled({"Unknown"}, true).success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.Menu removeMenuBranch", function()
    -- U-065

    local menu

    before_each(function()
        ctld.MenuManager._instance = nil
        menu = ctld.MenuManager:getInstance():createMenuForGroup(2005)
        -- Build: Vehicles (1 node) → { UH-60 (1), CH-47 (1) } = 3 total
        menu:addSubMenu({}, "Vehicles")
        menu:addCommand({"Vehicles"}, "UH-60", function() end)
        menu:addCommand({"Vehicles"}, "CH-47", function() end)
    end)

    it("returns success=true", function()
        assert.is_true(menu:removeMenuBranch({"Vehicles"}).success)
    end)

    it("removedCount=3 for 1 submenu + 2 commands", function()
        assert.equals(3, menu:removeMenuBranch({"Vehicles"}).removedCount)
    end)

    it("node is no longer accessible after removal", function()
        menu:removeMenuBranch({"Vehicles"})
        assert.is_nil(menu:_getNode({"Vehicles"}))
    end)

    it("guard: empty pathTable returns success=false with removedCount=0", function()
        local r = menu:removeMenuBranch({})
        assert.is_false(r.success)
        assert.equals(0, r.removedCount)
    end)

    it("guard: nil pathTable returns success=false", function()
        assert.is_false(menu:removeMenuBranch(nil).success)
    end)

    it("guard: unknown path returns success=false", function()
        assert.is_false(menu:removeMenuBranch({"NonExistent"}).success)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.MenuManager _rebuildPagedChildren pagination", function()
    -- U-066

    local addSubCount, addCmdCount

    -- Build N command-type nodes (all enabled, carry a stub functionToCall)
    local function makeCommandNodes(n)
        local nodes = {}
        for i = 1, n do
            table.insert(nodes, {
                name           = "Item_" .. i,
                type           = "command",
                enabled        = true,
                functionToCall = function() end,
                anyArgument    = {},
            })
        end
        return nodes
    end

    before_each(function()
        addSubCount = 0
        addCmdCount = 0
        missionCommands.addSubMenuForGroup = function() addSubCount = addSubCount + 1 end
        missionCommands.addCommandForGroup = function() addCmdCount = addCmdCount + 1 end
    end)

    after_each(function()
        missionCommands.addSubMenuForGroup = function() end
        missionCommands.addCommandForGroup = function() end
    end)

    it("10 items → all rendered inline, no NextPage submenu", function()
        ctld.MenuManager:_rebuildPagedChildren(1, {}, makeCommandNodes(10))
        assert.equals(10, addCmdCount)
        assert.equals(0,  addSubCount)
    end)

    it("11 items → 11 commands rendered, 1 NextPage submenu created", function()
        ctld.MenuManager:_rebuildPagedChildren(1, {}, makeCommandNodes(11))
        assert.equals(11, addCmdCount)
        assert.equals(1,  addSubCount)
    end)

    it("20 items → 20 commands rendered, 2 NextPage submenus created", function()
        ctld.MenuManager:_rebuildPagedChildren(1, {}, makeCommandNodes(20))
        assert.equals(20, addCmdCount)
        assert.equals(2,  addSubCount)
    end)

    it("disabled nodes are not rendered", function()
        local nodes = makeCommandNodes(3)
        nodes[2].enabled = false
        ctld.MenuManager:_rebuildPagedChildren(1, {}, nodes)
        assert.equals(2, addCmdCount)
    end)

    it("empty list → no DCS calls", function()
        ctld.MenuManager:_rebuildPagedChildren(1, {}, {})
        assert.equals(0, addCmdCount)
        assert.equals(0, addSubCount)
    end)

end)
