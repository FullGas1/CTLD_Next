---@diagnostic disable
-- CTLD_menu.lua
-- Menu model and DCS F10 menu manager.
--
-- ARCHITECTURE — two layers:
--
--   ctld.Menu         : Logical tree model for one group's menu.
--                       Callers work exclusively with this model.
--                       The tree is unlimited in memory; pagination is transparent.
--
--   ctld.MenuManager  : Singleton. Owns all ctld.Menu instances (one per groupId).
--                       Handles DCS rendering: wipe + rebuild atomically on refresh().
--
-- ORDER CONVENTION:
--   Every node carries an optional `order` field (number).
--   Siblings are sorted by `order` (ascending) before DCS rendering, regardless of
--   insertion order or manager initialization order.
--   Recommended spacing: 10, 20, 30 … to leave room for future entries.
--   Nodes without an explicit `order` value are appended last (math.huge).
--
--   WHY: each manager calls addSubMenu() independently. Without explicit order,
--   the visual position of a submenu would depend on the manager init sequence —
--   fragile and hard to control. Explicit order makes positions declarative and stable.
--
-- ENABLED CONVENTION:
--   Every node carries an `enabled` field (boolean, default true).
--   Disabled nodes are invisible in DCS but remain in the memory tree.
--   This PRESERVES their ORDER position: re-enabling a node brings it back
--   to the exact same F-key slot it would have occupied if always enabled.
--   Use setBranchEnabled() + refresh() to toggle features at runtime
--   (e.g. a mission trigger unlocks FOB building mid-mission).
--
-- PAGINATION:
--   DCS F10 menus: F1-F10 under programmer control, F11 = Previous Page (DCS),
--   F12 = Quit (DCS). Effective programmer slots per level: 10.
--   Rule applied by _rebuildPagedChildren():
--     - If visible children count <= 10 : render all on one page (no pagination).
--     - If visible children count  > 10 : render 9 in F1-F9,
--                                         F10 = "→ Next Page" submenu (DCS-only, not in memory),
--                                         recurse with remaining items inside that submenu.
--     The last page always receives <= 10 items and needs no "→ Next Page".
--   The "→ Next Page" node NEVER exists in the memory model — it is generated
--   at render time only.
--
-- DYNAMIC REFRESH PATTERN (proximity-based lists):
--   local menu = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
--   menu:clearBranch({"CTLD Commands", "Pack Vehicles"})  -- empty children, keep container
--   for _, v in ipairs(nearbyVehicles) do
--       menu:addCommand({"CTLD Commands", "Pack Vehicles"}, v.name, packFn, { unitName = v.name })
--   end
--   menu:refresh()   -- wipe DCS + rebuild (paged, ordered) atomically

ctld = ctld or {}

-- =============================================================================
-- ctld.MenuManager — Singleton: owns all group menus, drives DCS rendering
-- =============================================================================

ctld.MenuManager = ctld.MenuManager or {}
ctld.MenuManager._instance = nil

function ctld.MenuManager:getInstance()
    if not self._instance then
        self._instance = self:_new()
    end
    return self._instance
end

function ctld.MenuManager:_new()
    local obj = { menus = {}, _pendingRefresh = {} }
    setmetatable(obj, { __index = ctld.MenuManager })
    return obj
end

-- Create a ctld.Menu for groupId. Idempotent: returns existing menu if already created.
function ctld.MenuManager:createMenuForGroup(groupId)
    if not groupId or type(groupId) ~= "number" then
        ctld.logWarning("ctld.MenuManager:createMenuForGroup: invalid groupId %s", tostring(groupId))
        return nil
    end
    if self.menus[groupId] then
        return self.menus[groupId]
    end
    local menu = ctld.Menu:_new(groupId, self)
    self.menus[groupId] = menu
    ctld.logInfo("ctld.MenuManager:createMenuForGroup: created menu for group %d", groupId)
    return menu
end

-- Debounced refresh: coalesce all refresh() calls for a given group within
-- DEBOUNCE_S seconds into a single DCS rebuild.  This prevents rapid-fire
-- calls (flight-state poller oscillation, cargo detection, landing events)
-- from ejecting the player from the F10 menu mid-navigation.
local DEBOUNCE_S = 0.15   -- seconds — one DCS frame is ~0.02 s; 0.15 s absorbs any burst
function ctld.MenuManager:deferredRefreshForGroup(groupId)
    if not self.menus[groupId] then return end
    if self._pendingRefresh[groupId] then return end   -- already scheduled
    self._pendingRefresh[groupId] = true
    local selfRef = self
    timer.scheduleFunction(function()
        selfRef._pendingRefresh[groupId] = nil
        if selfRef.menus[groupId] then
            selfRef:refreshMenuForGroup(groupId)
        end
    end, nil, timer.getTime() + DEBOUNCE_S)
end

-- Wipe the entire DCS menu for groupId, then rebuild from the memory model.
-- ALL-OR-NOTHING: avoids partial / inconsistent DCS menu states.
-- Children are rendered in ORDER-field order (see ORDER CONVENTION above).
-- Direct callers (buildMenu on player enter) bypass the debounce intentionally.
function ctld.MenuManager:refreshMenuForGroup(groupId)
    if not self.menus[groupId] then
        ctld.logWarning("ctld.MenuManager:refreshMenuForGroup: no menu for group %s", tostring(groupId))
        return { success = false, message = "Menu not found for group " .. tostring(groupId), refreshedCount = 0 }
    end
    local menu = self.menus[groupId]

    -- Remove only CTLD's own top-level entries — never wipe the whole group menu
    -- (nil path would also destroy standard DCS entries such as Ground Crew / ATC).
    -- We use the opaque DCS handle stored at the previous build (_dcsHandle).
    -- Passing a string array ({"CTLD"}) to removeItemForGroup is silently ignored by DCS,
    -- which expects the opaque handle returned by addSubMenuForGroup/addCommandForGroup.
    for _, item in ipairs(menu.children) do
        if item._dcsHandle ~= nil then
            missionCommands.removeItemForGroup(groupId, item._dcsHandle)
            item._dcsHandle = nil
        end
    end

    local count = 0
    for _, item in ipairs(ctld.MenuManager:_sortByOrder(menu.children)) do
        count = count + ctld.MenuManager:_rebuildMenuNode(groupId, {}, item)
    end

    ctld.logInfo("ctld.MenuManager:refreshMenuForGroup: rebuilt %d items for group %d", count, groupId)
    return { success = true, message = "Menu refreshed: " .. count .. " items", refreshedCount = count }
end

-- Return a copy of `children` sorted by `order` ascending.
-- Nodes without an explicit order are placed last (order = math.huge).
-- Nodes sharing the same order value preserve their insertion order (stable sort).
function ctld.MenuManager:_sortByOrder(children)
    if not children then return {} end
    local sorted = {}
    for _, child in ipairs(children) do table.insert(sorted, child) end
    table.sort(sorted, function(a, b)
        local oa = a.order or math.huge
        local ob = b.order or math.huge
        return oa < ob
    end)
    return sorted
end

-- Recursively render one node into DCS.
-- Disabled nodes (enabled == false) are skipped: invisible in DCS, position preserved in memory.
function ctld.MenuManager:_rebuildMenuNode(groupId, parentPath, node)
    -- Disabled node: skip DCS rendering but preserve memory position.
    if node.enabled == false then return 0 end

    local count  = 0
    local dcsPath = #parentPath > 0 and parentPath or nil

    if node.type == "submenu" then
        -- Capture the DCS handle so refreshMenuForGroup can remove this item precisely
        -- on the next rebuild (removeItemForGroup requires the opaque handle, not a string path).
        local h = missionCommands.addSubMenuForGroup(groupId, node.name, dcsPath)
        node._dcsHandle = h
        count = count + 1
        -- Build the child path for this submenu level.
        local childPath = {}
        for _, p in ipairs(parentPath) do table.insert(childPath, p) end
        table.insert(childPath, node.name)
        -- Sort children by order then paginate into DCS.
        local sorted = ctld.MenuManager:_sortByOrder(node.children)
        ctld.MenuManager:_rebuildPagedChildren(groupId, childPath, sorted)

    elseif node.type == "command" then
        -- Wrap the user callback in pcall to prevent one bad command from crashing the whole menu.
        local fn = node.functionToCall
        local arg = type(node.anyArgument) == "table" and node.anyArgument or {}
        local wrapped = function()
            if fn then
                local ok, err = pcall(fn, arg)
                if not ok then
                    ctld.logError("ctld.MenuManager: callback failed for '%s': %s", node.name, tostring(err))
                end
            end
        end
        missionCommands.addCommandForGroup(groupId, node.name, dcsPath, wrapped, {})
        count = count + 1
    end

    return count
end

-- Paginate and render a pre-sorted list of children at parentPath.
--
-- PAGINATION RULE (see file header for full explanation):
--   visible count <= 10 → render all directly           (last / only page, F1-F10 free)
--   visible count  > 10 → render 9 items in F1-F9,
--                          F10 = "→ Next Page" submenu,
--                          recurse with remaining items inside that submenu.
--
-- The "→ Next Page" DCS submenu is created here only; it does not exist in the memory model.
function ctld.MenuManager:_rebuildPagedChildren(groupId, parentPath, children)
    -- Keep only enabled nodes for DCS rendering.
    local visible = {}
    for _, child in ipairs(children) do
        if child.enabled ~= false then table.insert(visible, child) end
    end

    local PAGE_SIZE = 9   -- F1-F9 for content on intermediate pages
    local dcsPath   = #parentPath > 0 and parentPath or nil

    if #visible <= 10 then
        -- Last (or only) page: all F1-F10 available for content, no "→ Next Page" needed.
        for _, child in ipairs(visible) do
            ctld.MenuManager:_rebuildMenuNode(groupId, parentPath, child)
        end
        return
    end

    -- Intermediate page: render PAGE_SIZE items, then add "→ Next Page" at F10.
    for i = 1, PAGE_SIZE do
        ctld.MenuManager:_rebuildMenuNode(groupId, parentPath, visible[i])
    end

    -- F10 = "→ Next Page" (translated, DCS-only — never in memory model).
    local nextLabel = ctld.tr("→ Next Page")
    missionCommands.addSubMenuForGroup(groupId, nextLabel, dcsPath)

    -- Build path into the "→ Next Page" submenu and recurse with remaining items.
    local nextPath = {}
    for _, p in ipairs(parentPath) do table.insert(nextPath, p) end
    table.insert(nextPath, nextLabel)

    local remaining = {}
    for i = PAGE_SIZE + 1, #visible do table.insert(remaining, visible[i]) end
    ctld.MenuManager:_rebuildPagedChildren(groupId, nextPath, remaining)
end

-- Retrieve group name by iterating all coalitions.
-- Note: Group.getByID() does not exist in the DCS SSE API (only Group.getByName() is documented).
-- Coalition iteration is the only reliable way to resolve groupId → name.
function ctld.MenuManager:_getGroupName(groupId)
    for _, coalId in ipairs({ 0, 1, 2 }) do
        for _, gp in pairs(coalition.getGroups(coalId) or {}) do
            if gp:getID() == groupId then return gp:getName() end
        end
    end
    return "Unknown"
end

-- Lookup helpers
function ctld.MenuManager:getMenuByGroupId(groupId)   return self.menus[groupId] or nil end
function ctld.MenuManager:getMenuByGroupName(groupName)
    for _, menu in pairs(self.menus) do
        if menu.groupName == groupName then return menu end
    end
    return nil
end
function ctld.MenuManager:getMenuByUnitName(unitName)
    local unit = Unit.getByName(unitName)
    if unit then
        local group = unit:getGroup()
        if group then return self:getMenuByGroupId(group:getID()) end
    end
    return nil
end
function ctld.MenuManager:getMenuByUnitId(unitId)
    local unit = Unit.getByID(unitId)
    if unit then
        local group = unit:getGroup()
        if group then return self:getMenuByGroupId(group:getID()) end
    end
    return nil
end

-- =============================================================================
-- ctld.Menu — Logical tree model for one group's F10 menu
-- =============================================================================

ctld.Menu = {}

function ctld.Menu:_new(groupId, manager)
    local obj = {
        groupId    = groupId,
        groupName  = manager:_getGroupName(groupId),
        children   = {},   -- root-level nodes (ordered by `order` field at render time)
        _lookup    = {},   -- path string → node (for fast access)
        manager    = manager,
        nextItemId = 1,
    }
    setmetatable(obj, { __index = ctld.Menu })
    return obj
end

-- Add a submenu node at pathTable / menuName.
--
-- opts (optional table):
--   order   : number  — position among siblings in the DCS menu (ascending).
--             See ORDER CONVENTION at file top. Recommended: multiples of 10.
--             Without this field the node is appended after all ordered siblings.
--   enabled : boolean — initial DCS visibility (default true).
--             false = node reserved in memory but invisible in DCS until
--             setBranchEnabled(path, true) + refresh() is called.
--
-- Idempotent: if the submenu already exists at that path, returns it unchanged.
function ctld.Menu:addSubMenu(pathTable, menuName, opts)
    pathTable = pathTable or {}
    opts      = opts or {}

    if not menuName or type(menuName) ~= "string" then
        ctld.logWarning("ctld.Menu:addSubMenu: invalid menu name")
        return { success = false, message = "Invalid menu name", subMenuId = nil }
    end

    local parent = self:_findOrCreateNode(pathTable)
    if not parent then
        return { success = false, message = "Path not found: " .. self:_pathToString(pathTable), subMenuId = nil }
    end
    if parent.type == "command" then
        return { success = false, message = "Cannot add submenu under a command node", subMenuId = nil }
    end

    -- Idempotent check: if already exists, update mutable props (order, enabled) if provided.
    for _, child in ipairs(parent.children or {}) do
        if child.name == menuName and child.type == "submenu" then
            if opts.order   ~= nil then child.order   = opts.order end
            if opts.enabled ~= nil then child.enabled = opts.enabled end
            return { success = true, message = "Submenu already exists", subMenuId = child.id }
        end
    end

    local subMenuId = "sub_" .. self.nextItemId
    self.nextItemId = self.nextItemId + 1

    local newNode = {
        id       = subMenuId,
        name     = menuName,
        type     = "submenu",
        children = {},
        -- ORDER: controls position among siblings during DCS render.
        -- Lower values appear higher in the menu (smaller F-key number).
        -- Gaps of 10 allow future insertions without renumbering existing entries.
        order   = opts.order,
        -- ENABLED: false keeps the node in memory (ORDER slot reserved) but
        -- hides it from DCS. Toggle with setBranchEnabled() + refresh().
        enabled = (opts.enabled ~= false),
    }

    if not parent.children then parent.children = {} end
    table.insert(parent.children, newNode)
    self._lookup[self:_buildPathString(pathTable, menuName)] = newNode

    return { success = true, message = "Submenu added", subMenuId = subMenuId }
end

-- Add a command leaf at pathTable / commandName.
-- anyArgument must be a table (or nil → defaults to {}).
function ctld.Menu:addCommand(pathTable, commandName, functionToCall, anyArgument, opts)
    pathTable = pathTable or {}

    if not commandName or type(commandName) ~= "string" then
        ctld.logWarning("ctld.Menu:addCommand: invalid command name")
        return { success = false, message = "Invalid command name", commandId = nil }
    end
    if not functionToCall or type(functionToCall) ~= "function" then
        ctld.logWarning("ctld.Menu:addCommand: invalid function for '%s'", tostring(commandName))
        return { success = false, message = "Invalid function reference", commandId = nil }
    end
    if anyArgument ~= nil and type(anyArgument) ~= "table" then
        ctld.logWarning("ctld.Menu:addCommand: anyArgument must be a table for '%s'", tostring(commandName))
        return { success = false, message = "anyArgument must be a table", commandId = nil }
    end

    local parent = self:_findOrCreateNode(pathTable)
    if not parent then
        return { success = false, message = "Path not found: " .. self:_pathToString(pathTable), commandId = nil }
    end
    if parent.type == "command" then
        return { success = false, message = "Cannot add command under a command node", commandId = nil }
    end

    local commandId = "cmd_" .. self.nextItemId
    self.nextItemId = self.nextItemId + 1

    local newNode = {
        id             = commandId,
        name           = commandName,
        type           = "command",
        functionToCall = functionToCall,
        anyArgument    = anyArgument or {},
        enabled        = true,
        order          = opts and opts.order or nil,
    }

    if not parent.children then parent.children = {} end
    table.insert(parent.children, newNode)
    self._lookup[self:_buildPathString(pathTable, commandName)] = newNode

    return { success = true, message = "Command added", commandId = commandId }
end

-- Empty all children of the node at pathTable WITHOUT removing the node itself.
--
-- Use for dynamic content that must be refreshed (nearby crates, vehicles, etc.):
-- the submenu CONTAINER stays at its ORDER position in its parent, so the
-- F-key slot does not shift when content changes.
--
-- Pattern:
--   menu:clearBranch({"CTLD Commands", "Pack Vehicles"})
--   for _, v in ipairs(nearbyVehicles) do
--       menu:addCommand({"CTLD Commands", "Pack Vehicles"}, v.name, fn, args)
--   end
--   menu:refresh()
function ctld.Menu:clearBranch(pathTable)
    pathTable = pathTable or {}
    local node = self:_getNode(pathTable)
    if not node then
        ctld.logWarning("ctld.Menu:clearBranch: path not found: %s", self:_pathToString(pathTable))
        return { success = false, message = "Path not found" }
    end
    if node.type == "command" then
        return { success = false, message = "Cannot clear a command node" }
    end
    -- Remove child entries from the lookup index.
    self:_cleanupLookup(self:_buildPathString(pathTable, ""))
    -- Wipe children; the node itself remains at its position in its parent's children list.
    node.children = {}
    return { success = true, message = "Branch cleared" }
end

-- Enable or disable the node at pathTable (and its subtree visibility in DCS).
-- The node stays in the memory tree — its ORDER position is preserved.
-- Call refresh() after to apply the change to the live DCS menu.
--
-- Typical use: a mission trigger unlocks a feature mid-mission.
--   menu:setBranchEnabled({"CTLD Commands", "FOB"}, true)
--   menu:refresh()
function ctld.Menu:setBranchEnabled(pathTable, enabled)
    local node = self:_getNode(pathTable)
    if not node then
        ctld.logWarning("ctld.Menu:setBranchEnabled: path not found: %s", self:_pathToString(pathTable))
        return { success = false, message = "Path not found" }
    end
    node.enabled = enabled
    return { success = true }
end

-- Permanently remove the node at pathTable and all its descendants.
-- Frees the ORDER slot in the parent — sibling ORDER values are unaffected but
-- the freed slot will not be visible after the next refresh().
--
-- Prefer clearBranch() for dynamic content and setBranchEnabled() for conditional menus.
-- This method is reserved for truly permanent removals.
function ctld.Menu:removeMenuBranch(pathTable)
    if not pathTable or #pathTable == 0 then
        return { success = false, message = "Cannot remove root menu", removedCount = 0 }
    end

    local parentPath = {}
    for i = 1, #pathTable - 1 do table.insert(parentPath, pathTable[i]) end
    local itemName = pathTable[#pathTable]

    local parent = self:_getNode(parentPath)
    if not parent or not parent.children then
        return { success = false, message = "Path not found: " .. self:_pathToString(pathTable), removedCount = 0 }
    end

    local childIndex = nil
    for i, child in ipairs(parent.children) do
        if child.name == itemName then childIndex = i; break end
    end
    if not childIndex then
        return { success = false, message = "Item not found: " .. itemName, removedCount = 0 }
    end

    local count = self:_countNodeItems(parent.children[childIndex])
    table.remove(parent.children, childIndex)
    self:_cleanupLookup(self:_buildPathString(pathTable, ""))
    return { success = true, message = "Removed branch with " .. count .. " items", removedCount = count }
end

-- Wipe DCS menu + rebuild from memory model (ordered, paged). Convenience shortcut.
function ctld.Menu:refresh()
    return self.manager:deferredRefreshForGroup(self.groupId)
end

-- =============================================================================
-- Private helpers
-- =============================================================================

-- Return the node at exactly pathTable, or nil if any segment is missing.
-- Does NOT auto-create nodes.
function ctld.Menu:_getNode(pathTable)
    if not pathTable or #pathTable == 0 then return self end
    local current = self
    for _, segment in ipairs(pathTable) do
        if not current.children then return nil end
        local found = nil
        for _, child in ipairs(current.children) do
            if child.name == segment then found = child; break end
        end
        if not found then return nil end
        current = found
    end
    return current
end

-- Navigate to the node at pathTable, auto-creating missing submenu nodes.
-- Used by addSubMenu / addCommand to ensure intermediate nodes exist.
function ctld.Menu:_findOrCreateNode(pathTable)
    if not pathTable or #pathTable == 0 then return self end
    local current = self
    for _, segment in ipairs(pathTable) do
        if not current.children then current.children = {} end
        local found = nil
        for _, child in ipairs(current.children) do
            if child.name == segment then found = child; break end
        end
        if not found then
            found = { name = segment, type = "submenu", children = {}, enabled = true }
            table.insert(current.children, found)
        end
        current = found
    end
    return current
end

function ctld.Menu:_pathToString(pathTable)
    if not pathTable or #pathTable == 0 then return "/" end
    return table.concat(pathTable, ".")
end

function ctld.Menu:_buildPathString(pathTable, itemName)
    local parts = {}
    for _, p in ipairs(pathTable) do table.insert(parts, p) end
    if itemName and itemName ~= "" then table.insert(parts, itemName) end
    return table.concat(parts, ".")
end

function ctld.Menu:_countNodeItems(node)
    if not node then return 0 end
    local count = 1
    if node.children then
        for _, child in ipairs(node.children) do
            count = count + self:_countNodeItems(child)
        end
    end
    return count
end

function ctld.Menu:_cleanupLookup(pathPrefix)
    for key in pairs(self._lookup) do
        if key:find(pathPrefix, 1, true) == 1 then self._lookup[key] = nil end
    end
end
