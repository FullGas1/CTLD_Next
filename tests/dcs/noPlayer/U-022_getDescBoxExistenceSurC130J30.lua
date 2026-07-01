---@diagnostic disable
-- ============================================================
-- U-22 : getDesc().box existence sur C-130J-30
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier via l'API DCS réelle que desc.box existe
--           et a des dimensions cohérentes sur le C-130J-30.
--
-- DEPENDENCY mission martyr :
--   - Un slot ou unité AI de type C-130J-30 nommé "c130_test"
--     OU n'importe quelle unité de type "C-130J-30" dans la mission
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("U-22", "getDesc().box — existence sur C-130J-30")

-- Chercher un C-130J-30 dans la mission (par nom ou dans les coalitions)
local transport = nil

-- Tentative par nom explicite
transport = Unit.getByName("c130_test")

-- Si absent, scanner BLUE et RED pour un C-130J-30
if not transport then
    for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        local groups = coalition.getGroups(side, Group.Category.AIRPLANE) or {}
        for _, grp in ipairs(groups) do
            for _, u in ipairs(grp:getUnits() or {}) do
                if u:isExist() and string.find(string.lower(u:getTypeName()), "c%-130", 1, false) then
                    transport = u
                    break
                end
            end
            if transport then break end
        end
        if transport then break end
    end
end

if not transport then
    ctld_test.assert(true,
        "INFO: aucun C-130J-30 trouvé — test ignoré (ajouter unité 'c130_test' à la mission)")
    ctld_test.finish()
    return
end

ctld_test.assertNotNil(transport, string.format(
    "C-130J-30 trouvé : '%s'", transport:getName()))

-- ---- Vérification getDesc().box ----
local ok, desc = pcall(function() return transport:getDesc() end)
ctld_test.assert(ok,    "getDesc() ne crash pas")
ctld_test.assertNotNil(desc, "getDesc() retourne une table non-nil")

if desc then
    ctld_test.assertNotNil(desc.box,     "desc.box non-nil")

    if desc.box then
        ctld_test.assertNotNil(desc.box.min, "desc.box.min non-nil")
        ctld_test.assertNotNil(desc.box.max, "desc.box.max non-nil")

        if desc.box.min and desc.box.max then
            ctld_test.assert(desc.box.min.x < desc.box.max.x,
                string.format("box.min.x(%.2f) < box.max.x(%.2f)",
                    desc.box.min.x, desc.box.max.x))
            ctld_test.assert(desc.box.min.y < desc.box.max.y,
                string.format("box.min.y(%.2f) < box.max.y(%.2f)",
                    desc.box.min.y, desc.box.max.y))
            ctld_test.assert(desc.box.min.z < desc.box.max.z,
                string.format("box.min.z(%.2f) < box.max.z(%.2f)",
                    desc.box.min.z, desc.box.max.z))

            -- Dimensions plausibles pour un C-130 (~30m de long, ~9m de large)
            local lenX = desc.box.max.x - desc.box.min.x
            local lenZ = desc.box.max.z - desc.box.min.z
            ctld_test.assert(lenX > 10,
                string.format("longueur X = %.2f m > 10 m (plausible)", lenX))
            ctld_test.assert(lenZ > 2,
                string.format("largeur Z = %.2f m > 2 m (plausible)", lenZ))

            -- getTransformation() doit aussi fonctionner (requis par _checkNativeLoading)
            local okT, tf = pcall(function() return transport:getTransformation() end)
            ctld_test.assert(okT, "getTransformation() ne crash pas")
            if okT and tf then
                ctld_test.assertNotNil(tf.p, "transform.p (position) non-nil")
                ctld_test.assertNotNil(tf.x, "transform.x (axe forward) non-nil")
                ctld_test.assertNotNil(tf.z, "transform.z (axe latéral) non-nil")
            end
        end
    end
end

ctld_test.finish()
