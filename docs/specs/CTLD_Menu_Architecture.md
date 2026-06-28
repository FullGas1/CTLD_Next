# CTLD Menu Manager — Architecture & Design

*January 9, 2026 — revised 2026-06-28: class names updated (`ctld.MenuManager`, `ctld.Menu`)*

---

## System Overview

The CTLD Menu Manager is a singleton-based hierarchical menu system designed to manage complex, dynamic menu structures for DCS World groups. It provides an abstraction layer over the native DCS mission command APIs while adding automatic pagination, error handling, and state management.

### Key Components

- **ctld.MenuManager** — Singleton that manages all group menus globally
- **Menu** — Individual menu structure for a single group
- **Node** — Single item in the menu tree (submenu or command)
- **Logger** — Handles INFO, WARN, ERROR logging

---

## System Architecture

### Component Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                    ctld.MenuManager (Singleton)              │
│                                                         │
│  Instance: {                                            │
│    menus = {                                            │
│      [42] = Menu1,     -- Group 42's menu              │
│      [99] = Menu2      -- Group 99's menu              │
│    },                                                   │
│    logger = Logger,                                     │
│    nextMenuId = 1                                       │
│  }                                                      │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│              Menu (for Group 42)                        │
│                                                         │
│  {                                                      │
│    groupId = 42,                                        │
│    groupName = "Alpha",                                 │
│    children = [ ... ],                                  │
│    _lookup = { ... }                                    │
│  }                                                      │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│        Hierarchical Node Structure                      │
│                                                         │
│  Node: Submenu "CTLD"                                   │
│    ├── Node: Submenu "Troop Transport"                  │
│    │   ├── Node: Command "Infantry"                     │
│    │   └── Node: Command "Anti Air"                     │
│    ├── Node: Submenu "Vehicles"                         │
│    │   ├── Node: Command "vehicle_1"                    │
│    │   ├── ...                                          │
│    │   └── [Pagination: "Next Page"]                    │
│    └── Node: Submenu "Drone"                            │
└─────────────────────────────────────────────────────────┘
```

---

## Data Structures

### Root Menu Structure

```lua
menuData = {
    groupId = 42,
    groupName = "Alpha",
    children = {
        [1] = { submenu node },
        [2] = { submenu node }
    },
    _lookup = {
        ["CTLD"] = <reference to children[1]>,
        ["CTLD.Vehicles"] = <reference to nested node>
    },
    nextItemId = 1
}
```

### Submenu Node Structure

```lua
{
    id = "sub_123",
    name = "CTLD",
    type = "submenu",
    index = 1,
    children = {
        [1] = { submenu or command node }
    }
}
```

### Command Node Structure

```lua
{
    id = "cmd_456",
    name = "Infantry",
    type = "command",
    index = 1,
    functionToCall = <function reference>,
    anyArgument = { /* user data */ }
}
```

---

## Refresh Algorithm

```
User calls: mgr:refreshMenuForGroup(groupId)
         ↓
Step 1: Validation
Check if menu exists in memory for groupId
         ↓
Step 2: Clear
Call missionCommands.removeItemForGroup(groupId, nil)
This removes ALL menu items from DCS UI
         ↓
Step 3: Rebuild
Traverse memory structure recursively
For each submenu: addSubMenuForGroup()
For each command: addCommandForGroup()
         ↓
Step 4: Pagination
(Happens automatically during rebuild)
If submenu has >10 items, create pages
         ↓
Step 5: Return
{ success = true, refreshedCount = N }
```

### Pseudo-code

```lua
function refresh(groupId)
    if not menus[groupId] then
        return { success = false, message = "Not found" }
    end
    menu = menus[groupId]
    missionCommands.removeItemForGroup(groupId, nil)
    count = 0
    for each child in menu.children do
        count += rebuildNode(groupId, {}, child)
    end
    return { success = true, refreshedCount = count }
end

function rebuildNode(groupId, parentPath, node)
    if node.type == "submenu" then
        missionCommands.addSubMenuForGroup(groupId, node.name, parentPath)
        count = 1
        newPath = parentPath + [node.name]
        for each child in node.children do
            count += rebuildNode(groupId, newPath, child)
        end
        return count
    else if node.type == "command" then
        missionCommands.addCommandForGroup(groupId, node.name, parentPath, wrappedCallback, {})
        return 1
    end
end
```

---

## Pagination Algorithm

Pagination is triggered during the refresh phase when a submenu's children exceed 10 items. The algorithm automatically distributes items across multiple pages.

### Example: 15 Vehicles

**Before refresh (memory):**

```lua
{
    name = "Vehicles",
    type = "submenu",
    children = [
        { name = "vehicle_1", type = "command" },
        ...
        { name = "vehicle_15", type = "command" }
    ]
}
```

**During refresh — split:**

```
Step 1: Count children = 15 (exceeds 10)
Step 2: Items 1-9 → page 1 ; Items 10-15 → "Next Page" submenu
Step 3: Auto-created "Next Page" node inserted at index 10
```

**DCS display result:**

```
F10 → Vehicles → Page 1:
  1. vehicle_1 … 9. vehicle_9  10. Next Page

F10 → Next Page:
  1. vehicle_10 … 6. vehicle_15
  (F11 Previous Page — handled by DCS)
```

**Key points:**
- Pagination is **automatic** during refresh
- Developer doesn't need to handle pagination manually
- DCS provides "F11 - Previous Page" navigation automatically
- Recalculated on every refresh — supports unlimited nesting depth

---

## Singleton Pattern

```lua
ctld.MenuManager = { _instance = nil }

function ctld.MenuManager:getInstance()
    if not self._instance then
        self._instance = self:new()
    end
    return self._instance
end

function ctld.MenuManager:new()
    local obj = {
        menus = {},
        nextMenuId = 1,
        logger = createLogger()
    }
    setmetatable(obj, { __index = ctld.MenuManager })
    return obj
end
```

### Lifecycle

| Phase | Event | State |
|---|---|---|
| 1. Load | Script loads | `ctld.MenuManager = {}`, `_instance = nil` |
| 2. First Access | `getInstance()` | `_instance` created, `menus = {}` |
| 3. Group Create | `createMenuForGroup()` | `menus[groupId] = new Menu` |
| 4. Runtime | Modify, refresh menus | Menus persist across modifications |
| 5. Mission End | New mission starts | `_instance` discarded (reset) |

---

## Callback Wrapping & GroupId Injection

DCS calls `func(arg)` when a player clicks a command. The ctld.MenuManager wraps callbacks in a closure to inject the `groupId`:

```lua
local wrappedFunc = function()
    local arg = {
        groupId = 42,       -- INJECTED by closure
        userArgs = originalArg
    }
    local ok, err = pcall(node.functionToCall, arg)
    if not ok then
        logger:error("Callback failed: " .. err)
    end
end

missionCommands.addCommandForGroup(42, "MyCommand", path, wrappedFunc, {})
```

---

## `_lookup` Table Optimization

The `_lookup` table provides O(1) path lookups instead of O(n) tree traversal:

```lua
-- Without _lookup (O(n)):
-- traverse root → match each segment → O(depth × siblings)

-- With _lookup (O(1)):
function findNode(path)
    return _lookup[table.concat(path, ".")]
end

-- Content:
_lookup = {
    ["CTLD"] = <ref>,
    ["CTLD.Troop Transport"] = <ref>,
    ["CTLD.Troop Transport.Infantry"] = <ref>,
    ["CTLD.Vehicles.vehicle_1"] = <ref>,
}
```

Updated automatically on `addSubMenu`, `addCommand`, `removeMenuBranch`.

---

## Error Handling Strategy

**Level 1 — Validation at API boundary:**
```lua
if not func or type(func) ~= "function" then
    return { success = false, message = "Invalid function" }
end
```

**Level 2 — Path validation:**
```lua
local parent = self:_findNode(pathTable)
if not parent then
    return { success = false, message = "Path not found" }
end
```

**Level 3 — Callback error isolation:**
```lua
local ok, err = pcall(node.functionToCall, arg)
if not ok then logger:error("Callback failed: " .. err) end
```

### Logging Levels

| Level | When | Example |
|---|---|---|
| INFO | Successful operations | `"addSubMenu: Added 'CTLD' for group 42"` |
| WARN | Recoverable errors | `"Path 'INVALID' not found"` |
| ERROR | Critical failures | `"Callback execution failed in Infantry"` |

---

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|---|---|---|
| `addCommand` / `addSubMenu` | O(1) | Append to children array |
| `removeMenuBranch` | O(n) | n = items in branch |
| `refreshMenuForGroup` | O(n) | n = total menu items |
| Path lookup (via `_lookup`) | O(1) | Hash table lookup |

### Benchmarks

```
Menu Size    Refresh Time    API Calls
──────────────────────────────────────
15 items       ~5ms            15
100 items      ~35ms           100
500 items      ~150ms          500
1000 items     ~250ms          1000
```

Memory: ~100 bytes/item. 1000 items ≈ 100 KB (negligible).

---

## Design Decisions

**1. In-memory tree before DCS apply** — allows atomic all-or-nothing updates; rollback on failure.

**2. Pagination recalculated on every refresh** — simplifies dynamic updates; no cached state to invalidate.

**3. Singleton pattern** — single point of access, matches DCS single-threaded environment.

**4. Return tables instead of exceptions** — Lua 5.1 has no exception handling; explicit `{ success, message }` is more robust.
