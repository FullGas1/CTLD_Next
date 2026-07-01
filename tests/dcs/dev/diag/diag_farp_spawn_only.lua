---@diagnostic disable
local FARP_NAME = "DIAG_TEST_FARP_1"
local batumi = Airbase.getByName("Batumi")
local refPt  = batumi and batumi:getPoint() or { x = -355000, y = 0, z = 617000 }
local sx = refPt.x
local sz = refPt.z - 1852 - 185
local ok, obj = pcall(coalition.addStaticObject, country.id.USA, {
    name = FARP_NAME, type = "SINGLE_HELIPAD",
    category = "Heliports", x = sx, y = sz, heading = 0,
    start_time = 0, dead = false, transportable = { randomTransportable = false },
})
local msg = ok and obj and "FARP spawné OK" or ("ERREUR: " .. tostring(obj))
trigger.action.outText(msg, 15)
return msg
