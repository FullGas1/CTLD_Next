---@diagnostic disable
-- class.lua
-- Minimal OOP micro-framework for Lua 5.1 (DCS sandbox).
--
-- Usage:
--   MyClass = class()
--   function MyClass:init(...)  -- constructor body; receives same args as new()
--
--   local obj = MyClass:new(...)  -- factory: allocates instance, calls init()
--
-- Inheritance:
--   Child = class(Parent)        -- Child inherits all Parent methods
--
-- Singleton pattern (compatible — getInstance() bypasses new()):
--   MySingleton = class()
--   local _inst = nil
--   function MySingleton.getInstance()
--       if not _inst then
--           _inst = setmetatable({}, MySingleton)
--           _inst:init()
--       end
--       return _inst
--   end
-- ============================================================

function class(base)
    local cls = {}
    cls.__index = cls
    if base then setmetatable(cls, { __index = base }) end
    function cls:new(...)
        local instance = setmetatable({}, cls)
        if instance.init then instance:init(...) end
        return instance
    end
    return cls
end
