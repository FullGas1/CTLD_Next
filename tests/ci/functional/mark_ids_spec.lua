---@diagnostic disable
-- tests/functional/mark_ids_spec.lua
-- busted specs for ctld.utils mark ID counter
-- Reference: live_tests/functional/F-115
-- ============================================================

describe("Mark IDs — F-115", function()

    it("[1] ctld.utils.getNextMarkId exists", function()
        assert.equals("function", type(ctld.utils.getNextMarkId))
    end)

    it("[2a] getNextMarkId is monotonically increasing", function()
        local id1 = ctld.utils.getNextMarkId()
        local id2 = ctld.utils.getNextMarkId()
        assert.equals(id1 + 1, id2)
    end)

    it("[2b] three consecutive calls strictly increase", function()
        local id1 = ctld.utils.getNextMarkId()
        local id2 = ctld.utils.getNextMarkId()
        local id3 = ctld.utils.getNextMarkId()
        assert.equals(id2 + 1, id3)
    end)

    it("[3] CTLDReconManager._nextMark() delegates to global counter", function()
        local rmgr = CTLDReconManager.getInstance()
        local reconId    = rmgr:_nextMark()
        local nextGlobal = ctld.utils.getNextMarkId()
        assert.equals(reconId + 1, nextGlobal)
    end)

    it("[4] CTLDBeaconManager._nextMark() delegates to global counter", function()
        local bmgr = CTLDBeaconManager.getInstance()
        local beaconId   = bmgr:_nextMark()
        local nextGlobal = ctld.utils.getNextMarkId()
        assert.equals(beaconId + 1, nextGlobal)
    end)

    it("[5] 20 alternating recon/beacon calls produce no collisions", function()
        local rmgr = CTLDReconManager.getInstance()
        local bmgr = CTLDBeaconManager.getInstance()
        local ids      = {}
        local collision = false
        for _ = 1, 20 do
            local a = rmgr:_nextMark()
            local b = bmgr:_nextMark()
            if ids[a] or ids[b] or a == b then collision = true end
            ids[a] = true
            ids[b] = true
        end
        assert.is_false(collision)
    end)

    it("[6b] drawQuad increments MarkIdCounter by 1", function()
        local before = ctld._markIdCounter
        pcall(function()
            ctld.utils.drawQuad(-1, {
                {x=0,y=0,z=0}, {x=100,y=0,z=0},
                {x=100,y=0,z=100}, {x=0,y=0,z=100}
            }, "test")
        end)
        assert.equals(before + 1, ctld._markIdCounter)
    end)

    it("[6c] drawQuad does NOT increment UniqIdCounter", function()
        local before = ctld.utils.UniqIdCounter
        pcall(function()
            ctld.utils.drawQuad(-1, {
                {x=0,y=0,z=0}, {x=100,y=0,z=0},
                {x=100,y=0,z=100}, {x=0,y=0,z=100}
            }, "test")
        end)
        assert.equals(before, ctld.utils.UniqIdCounter)
    end)

    it("[7a] CTLDReconManager has no _nextMarkId local field", function()
        local rmgr = CTLDReconManager.getInstance()
        assert.is_nil(rmgr._nextMarkId)
    end)

    it("[7b] CTLDBeaconManager has no _nextMarkId local field", function()
        local bmgr = CTLDBeaconManager.getInstance()
        assert.is_nil(bmgr._nextMarkId)
    end)

end)
