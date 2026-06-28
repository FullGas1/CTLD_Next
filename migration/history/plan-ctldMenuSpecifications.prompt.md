# CTLD Menu Manager - Spécifications Complètes

**Document Version:** 1.0  
**Date:** January 9, 2026  
**Language:** English (all code and documentation)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Deliverables](#deliverables)
3. [Core Requirements](#core-requirements)
4. [DCS API Reference](#dcs-api-reference)
5. [Data Structure](#data-structure)
6. [Public Methods](#public-methods)
7. [Error Handling](#error-handling)
8. [Pagination Logic](#pagination-logic)
9. [Manager (Singleton Pattern)](#manager-singleton-pattern)
10. [Usage Examples](#usage-examples)
11. [Implementation Notes](#implementation-notes)

---

## Overview

The **MenuManager** class provides a complete menu system for DCS World, allowing developers to:
- Create and manage hierarchical menus for aircraft groups
- Automatically handle pagination for menus exceeding 10 entries
- Dynamically modify menus during mission execution
- Persist menu structures in memory with real-time synchronization with DCS UI

### Key Features

- **Hierarchical menus** with unlimited nesting levels
- **Automatic pagination** for menus with >10 entries
- **Atomic refresh** operations (all-or-nothing menu updates)
- **Centralized manager** storing menus for all groups
- **Automatic GroupId injection** into command callbacks
- **Lookup optimization** via `_lookup` table for fast node access

---

## Deliverables

### 1. LUA Class Implementation (`CTLD_Menu.lua`)

A complete Lua script file implementing the MenuManager class that:
- Respects Lua 5.1 standards and DCS environment constraints
- Includes comprehensive code comments in English
- Provides all 9 public methods with full error handling
- Manages menu synchronization with DCS radio menu API

### 2. Test/Example Script (`CTLD_Menu_Example.lua`)

A working example demonstrating:
- Creating a Level-1 menu with 3 submenus: "CTLD", "JTAC", "BEACON"
- Creating Level-2 submenus under "CTLD": "Troop Transport", "Vehicles", "Drone"
- Creating Level-3 commands under "CTLD.Troop Transport": "Infantry", "Anti Air"
- Creating Level-3 commands under "CTLD.Vehicles": "vehicle_1" through "vehicle_15" (pagination test)
- Calling `refresh()` to apply menu to DCS UI

### 3. HTML Documentation (3 Pages)

**Page 1 - Usage Guide** (`CTLD_Menu_Usage.html`)
- Step-by-step tutorial for basic menu creation
- Common use cases with code examples
- Pagination behavior demonstration
- Troubleshooting guide

**Page 2 - Architecture & Design** (`CTLD_Menu_Architecture.html`)
- Menu structure diagram (hierarchical flow)
- Refresh algorithm flowchart
- Pagination algorithm explanation
- Singleton manager lifecycle
- Memory layout and data organization

**Page 3 - Technical Specifications** (`CTLD_Menu_Technical.html`)
- Complete method reference (all 8 methods with signatures)
- Data structure schema with field descriptions
- Error codes and handling strategies
- Performance characteristics and limits
- DCS API constraints and workarounds

---

## Core Requirements

### Functional Requirements

1. **Menu Creation & Management**
   - Create initial menu structure for a group: `createMenuForGroup(groupId)`
   - Add submenus at any level: `addSubMenu(pathTable, menuName)`
   - Add commands at any level: `addCommand(pathTable, commandName, functionToCall, anyArgument)`
   - Remove branches recursively: `removeMenuBranch(pathTable)`

2. **Real-time Modification**
   - All modifications must be applied atomically via `refresh()`
   - Refresh clears entire menu and reconstructs from memory
   - Modifications must preserve menu order and indices

3. **Menu Constraints**
   - Display limit: 10 entries per menu/submenu
   - Automatic pagination when exceeding 10 entries
   - DCS manages "F11 - Previous Page" automatically
   - Cannot add submenu to a command node

4. **Automatic Index Management**
   - Class automatically assigns position indices to entries
   - Indices recompiled on modification or deletion
   - Developer never manually manages indices

5. **Dynamic Entry Generation**
   - Support scripts that generate entries at runtime (e.g., detected vehicle types)
   - Class automatically manages pagination for dynamic entries
   - Support up to 1000 total entries per menu structure

### Non-Functional Requirements

- **Language**: All code, comments, and documentation in English
- **Performance**: Refresh operations must complete within 100ms (DCS single-threaded environment)
- **Memory**: Support minimum 10 simultaneous group menus without degradation
- **Robustness**: All errors must be handled gracefully with informative messages

---

## DCS API Reference

The MenuManager class wraps and manages the following DCS mission command APIs:

### 1. missionCommands.addCommandForGroup()

```
table missionCommands.addCommandForGroup(
    number groupId,
    string name,
    table/nil path,
    function functionToRun,
    any anyArgument
)
```

**Description:**  
Adds a command to the F10 radio menu for a specific group. The command executes a Lua function when selected by the player.

**Parameters:**
- `groupId` – Numeric group identifier
- `name` – Display text in menu (also used as identifier for removal)
- `path` – Table path (e.g., `{"CTLD", "Troop Transport"}`) or `nil` for root level
- `functionToRun` – Function reference to execute when command selected
- `anyArgument` – Optional argument passed to function

**MenuManager Enhancement:**  
MenuManager automatically injects the GroupId into the callback and handles path creation.

---

### 2. missionCommands.addSubMenuForGroup()

```
table missionCommands.addSubMenuForGroup(
    number groupId,
    string name,
    table path
)
```

**Description:**  
Creates a submenu for a group. Can be nested to create multi-level hierarchies.

**Parameters:**
- `groupId` – Numeric group identifier
- `name` – Submenu display text
- `path` – Parent path table (e.g., `{"CTLD"}`) or `nil`/`{}` for root

---

### 3. missionCommands.removeItemForGroup()

```
function missionCommands.removeItemForGroup(
    number groupId,
    table/nil path
)
```

**Description:**  
Removes a menu item or entire submenu hierarchy from the F10 radio menu.

**Parameters:**
- `groupId` – Numeric group identifier
- `path` – Table path to remove, or `nil` to clear entire menu

---

## Data Structure

### Memory Structure: menuData

Each group's menu is stored in a hierarchical table structure with automatic indexing and lookup optimization.

#### Root Structure

```lua
menuData = {
    groupId = 42,                          -- Numeric group identifier
    groupName = "Alpha",                   -- Group name (stored for getMenuByGroupName)
    children = {                           -- Array of root-level menu items
        [1] = { ... },                     -- First level-1 menu
        [2] = { ... }                      -- Second level-1 menu
    },
    _lookup = {                            -- Flat lookup table for fast access
        ["CTLD"] = <reference to children[1]>,
        ["JTAC"] = <reference to children[2]>,
        ["CTLD.Troop Transport"] = <reference>,
        ["CTLD.Vehicles"] = <reference>
    }
}
```

#### Submenu Node

```lua
{
    name = "CTLD",                         -- Display name
    type = "submenu",                      -- Node type identifier
    index = 1,                             -- Position within parent (auto-assigned)
    children = {                           -- Child entries
        [1] = { ... }
    }
}
```

#### Command Node

```lua
{
    name = "Infantry",                     -- Display name
    type = "command",                      -- Node type identifier
    index = 1,                             -- Position within parent (auto-assigned)
    functionToCall = <function ref>,       -- Callback function reference
    anyArgument = {                        -- Arguments to pass to callback
        groupId = 42,                      -- Injected automatically
        userArgs = "Infantry_Deployed"
    }
}
```

#### Pagination Structure

When a submenu exceeds 10 entries, pagination is handled automatically:

```lua
-- Original children with 15 entries
children = {
    [1] to [9] = normal entries,
    [10] = {
        name = "Next Page",                -- Auto-generated pagination entry
        type = "submenu",
        index = 10,
        children = {                       -- Page 2 entries
            [1] to [6] = entries 11-16
        }
    }
}
```

---

## Public Methods

### 1. createMenuForGroup(groupId)

**Signature:**
```lua
function MenuManager:createMenuForGroup(groupId)
    -- Returns: menu object or nil
end
```

**Description:**  
Creates an initial empty menu structure for a group. Must be called before adding menu items.

**Parameters:**
- `groupId` – Numeric identifier of the group

**Returns:**
- Menu object on success
- `nil` if groupId is invalid

**Example:**
```lua
local menu = MenuManager:createMenuForGroup(42)
if menu then
    menu:addSubMenu({}, "CTLD")
end
```

---

### 2. addSubMenu(pathTable, menuName)

**Signature:**
```lua
function Menu:addSubMenu(pathTable, menuName)
    -- Returns: { success = bool, message = string, subMenuId = string }
end
```

**Description:**  
Adds a submenu at the specified path. Can be nested arbitrarily deep.

**Parameters:**
- `pathTable` – Table path to parent (e.g., `{"CTLD"}`) or `{}` for root level
- `menuName` – Display name for the submenu (string)

**Returns:**
```lua
{
    success = true,
    message = "Submenu 'Troop Transport' added successfully",
    subMenuId = "sub_123"
}
```

**Errors:**
- `success = false` if path does not exist
- `success = false` if attempting to add submenu to a command node

**Example:**
```lua
local result = menu:addSubMenu({"CTLD"}, "Troop Transport")
if not result.success then
    print("Error: " .. result.message)
end
```

---

### 3. addCommand(pathTable, commandName, functionToCall, anyArgument)

**Signature:**
```lua
function Menu:addCommand(pathTable, commandName, functionToCall, anyArgument)
    -- Returns: { success = bool, message = string, commandId = string }
end
```

**Description:**  
Adds a command (executable menu item) at the specified path.

**Parameters:**
- `pathTable` – Path to parent submenu (e.g., `{"CTLD", "Troop Transport"}`) or `{}` for root
- `commandName` – Display name (string)
- `functionToCall` – Function reference to execute when command selected
- `anyArgument` – Table or value to pass to the function. The MenuManager will automatically inject `groupId` into this table before calling the function.

**Function Signature Expected:**
```lua
function myCallback(arg)
    -- arg is the anyArgument table with injected groupId:
    -- arg.groupId = 42 (injected by MenuManager)
    -- arg.userArgs = original_value_from_caller
end
```

**Returns:**
```lua
{
    success = true,
    message = "Command 'Infantry' added successfully",
    commandId = "cmd_456"
}
```

**Errors:**
- `success = false` if path does not exist
- `success = false` if functionToCall is not a callable function
- `success = false` if anyArgument type is unsupported

**Example:**
```lua
local function infantryDeploy(arg)
    local groupId = arg.groupId                -- Injected
    local deployType = arg.userArgs            -- Original argument
    trigger.action.outText("Deploying " .. deployType, 5)
end

local result = menu:addCommand(
    {"CTLD", "Troop Transport"},
    "Infantry",
    infantryDeploy,
    "Infantry_Deployed"
)
```

---

### 4. removeMenuBranch(pathTable)

**Signature:**
```lua
function Menu:removeMenuBranch(pathTable)
    -- Returns: { success = bool, message = string, removedCount = number }
end
```

**Description:**  
Removes a menu branch and all its child items recursively. Updates the `_lookup` table automatically.

**Parameters:**
- `pathTable` – Path to branch to remove (e.g., `{"CTLD", "Vehicles"}`)

**Returns:**
```lua
{
    success = true,
    message = "Removed branch 'CTLD.Vehicles' with 5 child items",
    removedCount = 5
}
```

**Behavior:**
- Removes the node at pathTable
- Recursively removes all child nodes
- Recompiles index values for sibling nodes
- Updates `_lookup` table

**Example:**
```lua
local result = menu:removeMenuBranch({"CTLD", "Vehicles"})
if result.success then
    print("Removed " .. result.removedCount .. " items")
end
```

---

### 5. refreshMenuForGroup(groupId)

**Signature:**
```lua
function MenuManager:refreshMenuForGroup(groupId)
    -- Returns: { success = bool, message = string, refreshedCount = number }
end
```

**Description:**  
Clears the entire DCS radio menu for a group and reconstructs it from the in-memory structure. This operation is atomic (all-or-nothing).

**Algorithm:**
1. Call `missionCommands.removeItemForGroup(groupId, nil)` to clear all items
2. Verify that menu structure exists in memory for this groupId
3. Traverse memory structure depth-first and reconstruct via DCS APIs
4. Handle pagination automatically during reconstruction

**Parameters:**
- `groupId` – Numeric group identifier

**Returns:**
```lua
{
    success = true,
    message = "Menu refreshed for group 42: 15 items loaded",
    refreshedCount = 15
}
```

**Error Cases:**
- `success = false` if groupId menu does not exist in memory
- `success = false` if DCS API calls fail (group disappeared mid-refresh)

**Example:**
```lua
local result = MenuManager:refreshMenuForGroup(42)
if result.success then
    print("Refreshed " .. result.refreshedCount .. " menu items")
end
```

---

### 6. getMenuByGroupId(groupId)

**Signature:**
```lua
function MenuManager:getMenuByGroupId(groupId)
    -- Returns: menu object or nil
end
```

**Description:**  
Retrieves the menu object for a specific group by numeric ID.

**Parameters:**
- `groupId` – Numeric group identifier

**Returns:**
- Menu object if found
- `nil` if not found

**Example:**
```lua
local menu = MenuManager:getMenuByGroupId(42)
if menu then
    menu:addCommand({}, "New Command", myFunc, args)
    MenuManager:refreshMenuForGroup(42)
end
```

---

### 7. getMenuByGroupName(groupName)

**Signature:**
```lua
function MenuManager:getMenuByGroupName(groupName)
    -- Returns: menu object or nil
end
```

**Description:**  
Retrieves the menu object for a specific group by name.

**Parameters:**
- `groupName` – String name of the group (must match name stored during `createMenuForGroup`)

**Returns:**
- Menu object if found
- `nil` if not found

**Implementation Note:**  
The groupName is stored in `menuData.groupName` during menu creation and used for lookup.

---

### 8. getMenuByUnitName(unitName)

**Signature:**
```lua
function MenuManager:getMenuByUnitName(unitName)
    -- Returns: menu object or nil
end
```

**Description:**  
Retrieves the menu object for the group that contains a specific unit.

**Parameters:**
- `unitName` – String name of the unit

**Algorithm:**
1. Query DCS: `local unit = Unit.getByName(unitName)`
2. Extract group: `local group = unit:getGroup()`
3. Look up menu: `return self:getMenuByGroupId(group:getID())`

**Returns:**
- Menu object if unit found and group has menu
- `nil` if unit not found or no menu exists

**Example:**
```lua
local menu = MenuManager:getMenuByUnitName("Alpha-1-1")
if menu then
    -- Menu for the group containing "Alpha-1-1" unit
end
```

---

### 9. getMenuByUnitId(unitId)

**Signature:**
```lua
function MenuManager:getMenuByUnitId(unitId)
    -- Returns: menu object or nil
end
```

**Description:**  
Retrieves the menu object for the group containing a specific unit ID.

**Parameters:**
- `unitId` – Numeric unit identifier

**Algorithm:**
1. Query DCS: `local unit = Unit.getByID(unitId)`
2. Extract group: `local group = unit:getGroup()`
3. Look up menu: `return self:getMenuByGroupId(group:getID())`

**Returns:**
- Menu object if unit found and group has menu
- `nil` if unit not found or no menu exists

---

## Error Handling

### Return Value Convention

All methods return a table with the following structure:

```lua
{
    success = true,                        -- Boolean: operation succeeded
    message = "Descriptive message",       -- String: status or error message
    dataField = value                      -- Optional: method-specific return value
}
```

### Error Cases & Behaviors

| Scenario | Method(s) | Behavior | Return |
|----------|-----------|----------|--------|
| **GroupId invalid/expired** | All methods | Log error, return gracefully | `{success=false, message="GroupId not found: 42"}` |
| **Path does not exist** | `addCommand`, `addSubMenu`, `removeMenuBranch` | Validate path before operation | `{success=false, message="Path not found: CTLD.Invalid"}` |
| **Attempting submenu on command** | `addSubMenu` | Reject operation | `{success=false, message="Cannot add submenu to command node"}` |
| **Function callback invalid** | `addCommand` | Validate at add-time | `{success=false, message="Invalid function reference"}` |
| **Callback execution fails** | During refresh/execution | Catch and log error, continue | Log error, do not crash menu |
| **Mnemonic name collision** | `addSubMenu`, `addCommand` | Allow (multiple items same name) | Success, use index for distinction |
| **Memory exceeded (>1000 entries)** | `addCommand`, `addSubMenu` | Reject if total exceeds limit | `{success=false, message="Menu capacity exceeded"}` |
| **Special characters in names** | `addSubMenu`, `addCommand` | Escape/filter automatically | Success, name sanitized |

### Logging Strategy

Three logging levels:

- **INFO** – Successful operations (addSubMenu, addCommand, refresh completed)
- **WARN** – Recoverable errors (path invalid, capacity warnings, deprecated usage)
- **ERROR** – Critical failures (callback errors, refresh rollback, API failures)

All logs include timestamp and context:
```lua
[INFO] 2026-01-09 14:23:45 | MenuManager | addSubMenu: Added 'Troop Transport' under 'CTLD' for group 42
[WARN] 2026-01-09 14:24:12 | MenuManager | Path 'CTLD.Invalid' not found in group 42
[ERROR] 2026-01-09 14:24:33 | MenuManager | Callback execution failed in command 'Infantry': ...
```

---

## Pagination Logic

### Automatic Pagination

When a submenu contains more than 10 entries, pagination is triggered automatically during `refresh()`:

**Algorithm:**

1. **Count entries:** Evaluate `#children` at each submenu node
2. **Threshold check:** If `#children > 10`, pagination required
3. **Page creation:**
   - Show entries 1-9 on Page 1
   - Create "Next Page" as entry 10 (special submenu)
   - Place entries 10+ on Page 2 (in "Next Page" submenu)
   - Recurse: If Page 2 has >10 items, create "Next Page 2", etc.
4. **Rebuild:** Apply to DCS via `missionCommands.addSubMenuForGroup()`

### Example: 15 Vehicles

**Memory structure (before refresh):**
```lua
{
    name = "Vehicles",
    children = {
        [1] = { name = "vehicle_1", type = "command", ... },
        [2] = { name = "vehicle_2", type = "command", ... },
        ...
        [15] = { name = "vehicle_15", type = "command", ... }
    }
}
```

**After pagination (during refresh):**
```lua
-- Page 1 (displayed in DCS F10 menu)
children = {
    [1] = vehicle_1,
    [2] = vehicle_2,
    ...
    [9] = vehicle_9,
    [10] = {
        name = "Next Page",
        type = "submenu",
        index = 10,
        children = {
            [1] = vehicle_10,
            [2] = vehicle_11,
            ...
            [6] = vehicle_15
        }
    }
}
```

**DCS Display:**
- **Page 1:** vehicle_1, vehicle_2, ..., vehicle_9, **Next Page**
- **Page 2 (F11 -> Next Page):** vehicle_10, vehicle_11, ..., vehicle_15

### Key Points

- **DCS handles "F11 - Previous Page" automatically** – No code required
- **Pagination reconstructed on every refresh** – Dynamic entries supported
- **No user code needed** – Class handles automatically
- **Bidirectional navigation:** Forward via "Next Page", backward via DCS's "F11"

---

## Manager (Singleton Pattern)

The MenuManager is a singleton that maintains all group menus throughout the mission.

### Architecture

```lua
MenuManager = {
    _instance = nil,              -- Singleton instance
    menus = {},                   -- { [groupId] = menuData }
    nextMenuId = 1                -- Counter for unique menu IDs
}
```

### Instantiation

**getInstance() – Get or create singleton:**
```lua
function MenuManager:getInstance()
    if not self._instance then
        self._instance = self:new()
    end
    return self._instance
end
```

**new() – Create new manager instance:**
```lua
function MenuManager:new()
    local obj = {
        menus = {},
        nextMenuId = 1
    }
    setmetatable(obj, { __index = MenuManager })
    return obj
end
```

### Usage Pattern

```lua
-- Get the singleton instance
local mgr = MenuManager:getInstance()

-- Create menu for a group
local menu = mgr:createMenuForGroup(42)

-- Add items
menu:addSubMenu({}, "CTLD")
menu:addCommand({"CTLD"}, "Deploy", myFunc, args)

-- Refresh
mgr:refreshMenuForGroup(42)
```

### Lifecycle

- **Creation:** First call to `getInstance()` creates the singleton
- **Persistence:** Singleton persists for entire mission duration
- **Cleanup:** Reset at mission end (mission-specific behavior)
- **Thread Safety:** DCS is single-threaded, no synchronization needed

---

## Usage Examples

### Basic Example: CTLD Menu Structure

```lua
-- ============================================================================
-- Example: Create a complete CTLD menu with pagination
-- ============================================================================

local function deployInfantry(arg)
    local groupId = arg.groupId
    local deployType = arg.userArgs
    trigger.action.outText(
        "Infantry deployed for group " .. groupId .. ": " .. deployType,
        5
    )
end

local function deployVehicle(arg)
    local groupId = arg.groupId
    local vehicleId = arg.userArgs
    trigger.action.outText(
        "Vehicle " .. vehicleId .. " deployed for group " .. groupId,
        5
    )
end

-- Initialize
local mgr = MenuManager:getInstance()

-- Get unit and group
if Unit.getByName("h1-1") then
    local unit = Unit.getByName("h1-1")
    local group = unit:getGroup()
    local groupId = group:getID()
    local groupName = group:getName()
    
    -- Create menu
    local menu = mgr:createMenuForGroup(groupId)
    
    if menu then
        -- Level 1 menus
        menu:addSubMenu({}, "CTLD")
        menu:addSubMenu({}, "JTAC")
        menu:addSubMenu({}, "BEACON")
        
        -- Level 2 under CTLD
        menu:addSubMenu({"CTLD"}, "Troop Transport")
        menu:addSubMenu({"CTLD"}, "Vehicles")
        menu:addSubMenu({"CTLD"}, "Drone")
        
        -- Level 3: Infantry & Anti-Air under Troop Transport
        menu:addCommand(
            {"CTLD", "Troop Transport"},
            "Infantry",
            deployInfantry,
            "Infantry_Deployed"
        )
        menu:addCommand(
            {"CTLD", "Troop Transport"},
            "Anti Air",
            deployInfantry,
            "AA_Deployed"
        )
        
        -- Level 3: 15 vehicles (pagination test)
        for i = 1, 15 do
            menu:addCommand(
                {"CTLD", "Vehicles"},
                "vehicle_" .. i,
                deployVehicle,
                "Vehicle_ID_" .. i
            )
        end
        
        -- Apply to DCS UI (handles pagination automatically)
        local result = mgr:refreshMenuForGroup(groupId)
        if result.success then
            trigger.action.outText(
                "Menu created: " .. result.refreshedCount .. " items",
                5
            )
        end
    end
end
```

### Advanced Example: Dynamic Menu Updates

```lua
-- ============================================================================
-- Example: Modify menu based on detected vehicles during mission
-- ============================================================================

local function detectNearbyVehicles(groupId)
    -- Pseudo-code: Query DCS for nearby units
    local detectedVehicles = {
        { id = "tank_01", name = "M1 Abrams" },
        { id = "hmmwv_01", name = "HMMWV" },
        { id = "truck_01", name = "Transport Truck" }
    }
    return detectedVehicles
end

local function callInVehicle(arg)
    local groupId = arg.groupId
    local vehicleId = arg.userArgs
    trigger.action.outText(
        "Calling in vehicle: " .. vehicleId .. " for group " .. groupId,
        5
    )
end

-- Get menu
local mgr = MenuManager:getInstance()
local menu = mgr:getMenuByGroupId(42)

if menu then
    -- Clear previous vehicle list
    local removeResult = menu:removeMenuBranch({"CTLD", "Vehicles"})
    
    -- Re-add submenu
    menu:addSubMenu({"CTLD"}, "Vehicles")
    
    -- Add detected vehicles dynamically
    local vehicles = detectNearbyVehicles(42)
    for _, vehicle in ipairs(vehicles) do
        menu:addCommand(
            {"CTLD", "Vehicles"},
            vehicle.name,
            callInVehicle,
            vehicle.id
        )
    end
    
    -- Refresh to apply changes (handles pagination automatically)
    mgr:refreshMenuForGroup(42)
end
```

### Lookup Example: Retrieve Menu by Unit

```lua
-- ============================================================================
-- Example: Get menu from unit name and modify it
-- ============================================================================

local mgr = MenuManager:getInstance()

-- Method 1: By unit name
local menu = mgr:getMenuByUnitName("Alpha-1-1")

if menu then
    -- Add a new command
    menu:addCommand({}, "Test Command", function(arg) end, "test")
    
    -- Get the group ID from the menu
    local groupId = menu.groupId
    
    -- Refresh
    mgr:refreshMenuForGroup(groupId)
end

-- Method 2: By group name
local menu2 = mgr:getMenuByGroupName("Alpha")

if menu2 then
    -- Modify menu...
    mgr:refreshMenuForGroup(menu2.groupId)
end
```

---

## Implementation Notes

### Design Patterns

1. **Singleton Pattern for MenuManager**
   - One global instance managing all group menus
   - Accessed via `getInstance()`
   - Thread-safe (DCS is single-threaded)

2. **Hierarchical Tree Structure**
   - Each menu is a tree of nodes (submenu or command)
   - `_lookup` table provides O(1) path lookups
   - Pagination handled transparently in tree structure

3. **Atomic Refresh**
   - All modifications are accumulated in memory
   - Only applied to DCS via single `refresh()` call
   - Ensures menu consistency

4. **GroupId Injection via Wrapper**
   - User provides function reference
   - MenuManager wraps it with GroupId injection
   - Wrapper signature: `function(anyArgument)` → `originalFunc(groupId, anyArgument)`

### Performance Considerations

- **Refresh Performance:** O(n) where n = total menu items
  - Typical: 15 items = <10ms
  - Large: 100 items = <50ms
  - Extreme: 1000 items = <100ms (acceptable in DCS)

- **Lookup Performance:** O(1) via `_lookup` table
  - Path searches are flat lookup, not tree traversal

- **Memory:** ~100 bytes per menu item
  - 1000 items ≈ 100KB (negligible)

- **Recommendation:** Avoid refresh() more than once per second per menu

### Constraints

- **No circular references:** Tree must remain acyclic
- **Single path per item:** Each item has unique path string
- **Max nesting:** No explicit limit, but >5 levels not recommended
- **Max items per menu:** No explicit limit, but pagination at 10 visible items

### Known Limitations

1. **Cannot get unit reference from unitId** – DCS API limitation
   - Workaround: Use `Unit.getByName()` instead
   
2. **DCS API cannot list existing menu items** – Cannot validate path before operation
   - Workaround: Maintain path list in code or documentation

3. **Function signature validation** – Cannot introspect Lua functions
   - Workaround: Document expected signature and validate at runtime if needed

4. **Menu order depends on call order** – Not based on name alphabetically
   - Workaround: Call `addSubMenu()`/`addCommand()` in desired order

---

## Glossary

- **GroupId** – Numeric identifier for a DCS group (squadron, flight, etc.)
- **Node** – Single menu item (either submenu or command)
- **Path** – Table describing route to a menu node, e.g., `{"CTLD", "Vehicles"}`
- **Pagination** – Automatic splitting of >10 items across multiple pages
- **Refresh** – Operation to synchronize in-memory menu with DCS UI
- **Singleton** – Design pattern ensuring single global instance
- **_lookup** – Optimization table mapping path strings to node references
- **Wrapper** – Function that encapsulates another function with additional logic

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 9, 2026 | Initial complete specification |

---

**End of Document**
