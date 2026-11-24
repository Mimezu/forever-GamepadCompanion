-- The waters' fishing levels, known from the start (FishingLure.lua reads them;
-- what the game says and what a water does always win). Game facts, our own
-- table: the Classic-era levels the public fishing guides give ("skill to fish /
-- skill to lose no fish"), B being the second less 95: a fish lands about
-- E - B + 5 times in 100 (E: the skill with its lure). The fishable zones are the
-- ones Wowhead's Forever catch pages list (42 zones; Ironforge and Blasted Lands
-- added, there is water there).
--   zones[uiMapID] = { B, English name [, sure = false] }   (C_Map's zone maps)
--   waters[name]   = { B [, sure = false] }   a dungeon by its zone name, or a
--                    place in a zone "Zone/Place" where it differs from its zone
-- sure = false: the guides disagree or are thin; such a level is a guess that
-- never says "too low" by itself.
local _, ns = ...
local W = {}
ns.FishingWaters = W

W.zones = {
    -- the starting lands and the cities: fish from the start, none lost from 25
    [1426] = { -70, "Dun Morogh" }, [1411] = { -70, "Durotar" }, [1429] = { -70, "Elwynn Forest" },
    [1412] = { -70, "Mulgore" }, [1438] = { -70, "Teldrassil" }, [1420] = { -70, "Tirisfal Glades" },
    [1453] = { -70, "Stormwind City" }, [1454] = { -70, "Orgrimmar" }, [1455] = { -70, "Ironforge" },
    [1456] = { -70, "Thunder Bluff" }, [1457] = { -70, "Darnassus" }, [1458] = { -70, "Undercity" },
    -- none lost from 75
    [1413] = { -20, "The Barrens" }, [1439] = { -20, "Darkshore" }, [1432] = { -20, "Loch Modan" },
    [1421] = { -20, "Silverpine Forest" }, [1436] = { -20, "Westfall" },
    -- from 150
    [1440] = { 55, "Ashenvale" }, [1431] = { 55, "Duskwood" }, [1424] = { 55, "Hillsbrad Foothills" },
    [1433] = { 55, "Redridge Mountains" }, [1442] = { 55, "Stonetalon Mountains" }, [1437] = { 55, "Wetlands" },
    -- from 225
    [1416] = { 130, "Alterac Mountains" }, [1417] = { 130, "Arathi Highlands" }, [1443] = { 130, "Desolace" },
    [1445] = { 130, "Dustwallow Marsh" }, [1434] = { 130, "Stranglethorn Vale" }, [1435] = { 130, "Swamp of Sorrows" },
    [1441] = { 130, "Thousand Needles" },
    -- from 300
    [1447] = { 205, "Azshara" }, [1444] = { 205, "Feralas" }, [1425] = { 205, "The Hinterlands" },
    [1446] = { 205, "Tanaris" }, [1449] = { 205, "Un'Goro Crater" }, [1448] = { 205, "Felwood" },
    [1422] = { 205, "Western Plaguelands" },
    -- the guides disagree (205 or 330): a guess
    [1423] = { 205, "Eastern Plaguelands", sure = false }, [1452] = { 205, "Winterspring", sure = false },
    [1451] = { 205, "Silithus", sure = false }, [1450] = { 205, "Moonglade", sure = false },
    [1428] = { 205, "Burning Steppes", sure = false }, [1419] = { 205, "Blasted Lands", sure = false },
    [1430] = { 330, "Deadwind Pass", sure = false },
}

W.waters = {
    -- dungeons with water (no zone map of their own here): guesses
    ["Wailing Caverns"] = { -20, sure = false }, ["The Deadmines"] = { -20, sure = false },
    ["Blackfathom Deeps"] = { 55, sure = false }, ["The Temple of Atal'Hakkar"] = { 205, sure = false },
    ["Maraudon"] = { 205, sure = false }, ["Dire Maul"] = { 205, sure = false },
    ["Stratholme"] = { 330, sure = false }, ["Scholomance"] = { 330, sure = false },
    ["Zul'Gurub"] = { 330, sure = false },
}
