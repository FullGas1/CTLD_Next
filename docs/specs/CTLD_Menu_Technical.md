# CTLD Menu Manager — Technical Specification Reference

*January 9, 2026 — revised 2026-06-28: class names updated (`ctld.MenuManager`, `ctld.Menu`); `addSubMenu`/`addCommand` carry `opts` parameter in v2*

---

## API Overview

The ctld.MenuManager provides public methods in four categories:

- **Singleton management** — `getInstance()`
- **Group menu creation** — `createMenuForGroup()`
- **Menu item modification** — `addSubMenu()`, `addCommand()`, `removeMenuBranch()`
- **Menu refresh** — `refreshMenuForGroup()`
- **Menu retrieval** — `getMenuByGroupId()`, `getMenuByGroupName()`, `getMenuByUnitName()`

---

## Complete Method Reference

### 1. `ctld.MenuManager:getInstance()`

Returns the singleton ctld.MenuManager instance. Creates it on first call.

```lua
local mgr = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(42)
```

**Returns:** ctld.MenuManager singleton instance.

---

### 2. `ctld.MenuManager:createMenuForGroup(groupId)`

Creates an empty menu structure for a group. Must be called before adding items.

| Parameter | Type | Description | Required |
|---|---|---|---|
| `groupId` | number | Numeric group identifier in DCS | Yes |

**Returns:** Menu object on success, `nil` on failure.

**Errors:** Invalid `groupId` (nil, non-numeric) · Menu already exists for group.

```lua
local menu = mgr:createMenuForGroup(42)
if menu then
    menu:addSubMenu({}, "CTLD")
end
```

---

### 3. `ctld.Menu:addSubMenu(pathTable, menuName)`

Adds a submenu at the specified path.

| Parameter | Type | Description | Required |
|---|---|---|---|
| `pathTable` | table | Path to parent (e.g. `{"CTLD"}`) or `{}` for root | Yes |
| `menuName` | string | Display name | Yes |

**Returns:**
```lua
{ success = bool, message = string, subMenuId = "sub_123" }
```

**Errors:** Path not found · Adding submenu to command · Invalid name.

```lua
local result = menu:addSubMenu({"CTLD"}, "Troop Transport")
if result.success then
    print("Created: " .. result.subMenuId)
end
```

---

### 4. `ctld.Menu:addCommand(pathTable, commandName, functionToCall, anyArgument)`

Adds an executable command at the specified path.

| Parameter | Type | Description | Required |
|---|---|---|---|
| `pathTable` | table | Path to parent or `{}` for root | Yes |
| `commandName` | string | Display name | Yes |
| `functionToCall` | function | Callback. Signature: `function(arg)` | Yes |
| `anyArgument` | table | Data passed as-is to callback | No (default `{}`) |

**Returns:**
```lua
{ success = bool, message = string, commandId = "cmd_456" }
```

**Errors:** Path not found · Invalid function reference · Capacity exceeded (1000 items) · Adding command to command.

```lua
local function myCallback(arg)
    print("Deploying: " .. arg.squadType)
end

local result = menu:addCommand(
    {"CTLD", "Deploy"}, "Infantry",
    myCallback, { squadType = "squad_1" }
)
```

---

### 5. `ctld.Menu:removeMenuBranch(pathTable)`

Recursively removes a menu branch and all its children.

| Parameter | Type | Description | Required |
|---|---|---|---|
| `pathTable` | table | Path to branch | Yes |

**Returns:**
```lua
{ success = bool, message = string, removedCount = number }
```

**Errors:** Path not found · Cannot remove root menu.

```lua
local result = menu:removeMenuBranch({"CTLD", "Vehicles"})
if result.success then
    mgr:refreshMenuForGroup(groupId)
end
```

---

### 6. `ctld.MenuManager:refreshMenuForGroup(groupId)`

Clears entire DCS menu for group and reconstructs from memory. Atomic operation.

| Parameter | Type | Description | Required |
|---|---|---|---|
| `groupId` | number | Group to refresh | Yes |

**Returns:**
```lua
{ success = bool, message = string, refreshedCount = number }
```

**Algorithm:**
1. Validate menu exists in memory
2. `missionCommands.removeItemForGroup()` — clear all items
3. Traverse menu tree depth-first
4. Call `addSubMenuForGroup` or `addCommandForGroup` per node
5. Handle pagination automatically
6. Return status

```lua
menu:addCommand({}, "New Item", func, {})
local result = mgr:refreshMenuForGroup(groupId)
```

---

### 7. `ctld.MenuManager:getMenuByGroupId(groupId)`

Retrieves menu by group numeric ID.

**Returns:** Menu object or `nil`.

---

### 8. `ctld.MenuManager:getMenuByGroupName(groupName)`

Retrieves menu by group name string.

**Returns:** Menu object or `nil`.

---

### 9. `ctld.MenuManager:getMenuByUnitName(unitName)`

Retrieves menu for the group containing a specific unit.

**Returns:** Menu object of unit's group, or `nil`.

---

## Data Structure Schema

```lua
-- Root menu node
{
    groupId    = number,    -- DCS group ID
    groupName  = "string",  -- Group name for lookup
    children   = { ... },   -- Array of child nodes
    _lookup    = { ... },   -- Path → node reference (O(1))
    nextItemId = number,    -- Counter for unique IDs
    manager    = reference  -- Back-reference to ctld.MenuManager
}

-- Submenu node
{
    id       = "sub_123",
    name     = "string",
    type     = "submenu",
    index    = number,
    children = { ... }
}

-- Command node
{
    id             = "cmd_456",
    name           = "string",
    type           = "command",
    index          = number,
    functionToCall = function,
    anyArgument    = any
}
```

---

## Error Codes & Handling

All failing methods return:
```lua
{ success = false, message = "Descriptive error message" }
```

| Error Message | Cause | Solution |
|---|---|---|
| `"Path not found: ..."` | Parent path doesn't exist | Create parent submenu first |
| `"Invalid groupId"` | `groupId` is nil or non-numeric | Check group extraction from DCS |
| `"Cannot add submenu to command"` | Trying to nest under a command | Use submenu containers |
| `"Invalid function reference"` | `functionToCall` is not callable | Pass function reference, not string |
| `"Menu capacity exceeded"` | Total items > 1000 | Reduce or split across groups |
| `"Menu not found for group"` | No menu created for that `groupId` | Call `createMenuForGroup()` first |

---

## Performance Specifications

### Operation Timing

| Operation | Typical Time | Notes |
|---|---|---|
| `addCommand` / `addSubMenu` | < 1 ms | O(1) |
| `removeMenuBranch` (5 items) | < 2 ms | O(n) |
| `refreshMenuForGroup` (15 items) | 5–10 ms | Includes DCS API calls |
| `refreshMenuForGroup` (100 items) | 35–50 ms | Acceptable in DCS single-thread |
| `refreshMenuForGroup` (1000 items) | 200–300 ms | Not recommended |

### Memory Estimates

| Scenario | Memory |
|---|---|
| ctld.MenuManager instance | ~1 KB |
| Single menu — 15 items | ~2 KB |
| Single menu — 1000 items | ~100 KB |
| 10 groups, 150 items total | ~20 KB |

---

## Limits & Constraints

| Limit | Value | Notes |
|---|---|---|
| Max items per submenu | Unlimited | Paginated if > 10 visible |
| Max menu depth | Unlimited | Recommend < 5 levels for UX |
| Max items per menu | 1000 | Hard limit |
| Max simultaneous menus | Unlimited | Limited by DCS group count |
| Refresh frequency | — | Recommend < 1 refresh/sec |

---

## DCS API Constraints & Workarounds

**No menu listing API** — Cannot query existing DCS menu items. Workaround: full in-memory model, always validate locally before DCS operations.

**All-or-nothing refresh** — Cannot update a single item; must clear and rebuild entire menu. Workaround: accumulate changes, apply via single `refresh()`.

**Pagination is manual** — DCS doesn't auto-paginate. Workaround: ctld.MenuManager handles pagination automatically during refresh.

**No callback introspection** — Cannot validate Lua function signatures at runtime. Workaround: document expected signature, validate via `pcall`.

---

## Compatibility

- **Lua:** 5.1 — no external dependencies beyond DCS APIs
- **DCS:** World 2.7+ (any version with `missionCommands` API)

**Required DCS APIs:**
- `missionCommands.addCommandForGroup()`
- `missionCommands.addSubMenuForGroup()`
- `missionCommands.removeItemForGroup()`
- `Unit.getByName()` / `Unit.getByID()`
- `Group.getByID()`
