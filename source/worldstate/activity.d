

module worldstate.activity;

import std.algorithm;

import graphics.debugging;

import cgy.util.pos;
import cgy.util.rangefromto;
import cgy.util.util; 

import cgy.util.sizes;
import worldstate.time;

//debug {
    auto activitySize = vec3i(3,3,3);
//} else {
//    auto activitySize = vec3i(5,5,5);
//}

immutable SectorTimeoutTicks = TICKS_PER_SECOND * 15;


mixin template ActivityHandlerMethods() {

    int[SectorNum] activeSectors; //Number of clans active in sector X.

    ulong[SectorNum] sectorTimeout; //Tick when sector X is scheduled for serializing to harddisk

    bool isActiveSector(SectorNum sectorNum) {
        return (sectorNum in activeSectors) !is null;
    }

    //Called after every unit movement, otherwise floodfill errors.
    void updateActivity(UnitPos from, UnitPos pos) {


        auto centerSectorNum = pos.getSectorNum();
        auto sector = getSector(centerSectorNum);
        if(sector is null) {
            sector = loadSector(centerSectorNum);
        }
        if(centerSectorNum in activeSectors) {
            enforce(activeSectors[centerSectorNum] > 0, "error of derpy magnitude somewhere");
        }

        bool[SectorNum] relevantSectors;
        foreach(sectorNum ; activityRange(centerSectorNum)) {
            relevantSectors[sectorNum] = true;
        }
        foreach(sectorNum ; activityRange(from.getSectorNum())) {
            relevantSectors[sectorNum] = true;
        }



        int[SectorNum] changeMap;
        foreach(sectorNum, unrelevant ; relevantSectors) {
            int count = 0;
            int oldCount = sectorNum in activeSectors ? activeSectors[sectorNum] : 0;
            foreach(clan ; Clans().getClans()) {
                count += cast(int)clan.activeSector(sectorNum);
            }

            if(count) {
                activeSectors[sectorNum] = count;
            } else if(oldCount) {
                activeSectors.remove(sectorNum);
            }
            if(count && !oldCount) {
                changeMap[sectorNum] = 1;
            }
            if(oldCount && !count) {
                changeMap[sectorNum] = -1;
            }
        }

        //Get / load / allocate 'this' sector?

        foreach(sectorNum, value ; changeMap) {
            if(value == 1) {
                //Added sector
                //Check if lies in TimeOut-queueueue, then readd?

                if(sectorNum in sectorTimeout) {
                    //msg("Removeing sector from offload queueuue");
                    sectorTimeout.remove(sectorNum);
                    continue;
                }

                auto sector = getSector(sectorNum);
                if(sector is null) {
                    sector = loadSector(sectorNum);
                }
            } else {
                sectorTimeout[sectorNum] = worldTime + SectorTimeoutTicks;
                //msg("Queueing sector for offload");
                //addAABB(sectorNum.getAABB);
                //Removed sector

            }
        }

    }

    void handleSectorTimeout() {
        SectorNum[] removed;
        foreach(sectorNum, timeout; sectorTimeout) {
            if(timeout < worldTime) {
                msg("Removing sector");

                notifySectorUnload(sectorNum);

                SectorXY* sectorXY;
                auto sector = getSector(sectorNum, &sectorXY);
                enforce(sector !is null, "Trying to remove a non-existent sector derp!");
                sector.serialize();
                sector = null;
                auto xy = SectorXYNum(sectorNum);
                if(removeSector(sectorNum)) {
                    serializeHeightmap(xy, sectorXY);
                    sectorsXY.remove(xy);
                }

                removed ~= sectorNum;

            }
        }
        foreach(sectorNum ; removed) {
            sectorTimeout.remove(sectorNum);
        }
    }

}

auto activityRange(SectorNum base) {
    SectorNum a(vec3i d){
        return SectorNum(d);
    }
    return map!a(RangeFromTo (
                              base.value - activitySize/2,
                              base.value + activitySize/2));
}


struct WallBetweenSectors {
    SectorNum inactive, active;

    this(SectorNum _inactive, SectorNum _active) {
        inactive = _inactive;
        active = _active;
    }

    int opApply(scope int delegate(ref BlockNum inact, ref BlockNum act) y) {
        auto delta = inactive.value - active.value;
        assert (delta.getLengthSQ() == 1);

        auto bb = active.toBlockNum.value;

        auto start = vec3i(
                           delta.x == 0 ? 0
                           : (delta.x == 1 ? BlocksPerSector.x - 1 : 0),
                           delta.y == 0 ? 0
                           : (delta.y == 1 ? BlocksPerSector.y - 1 : 0),
                           delta.z == 0 ? 0
                           : (delta.z == 1 ? BlocksPerSector.z - 1 : 0));
        auto end = vec3i( 
                         delta.x == 0 ? BlocksPerSector.x
                         : (delta.x == 1 ? BlocksPerSector.x-1 : 0),
                         delta.y == 0 ? BlocksPerSector.y
                         : (delta.y == 1 ? BlocksPerSector.y-1 : 0),
                         delta.z == 0 ? BlocksPerSector.z
                         : (delta.z == 1 ? BlocksPerSector.z-1 : 0));
        BlockNum b(vec3i v) {
            return BlockNum(v);
        }
        auto wall = map!(b)(RangeFromTo (bb+start, bb+end));

        foreach (bn; wall) {
            auto derp = BlockNum(bn.value+delta);
            if (y(derp, bn)) return 1;
        }

        return 0;
    }
}

WallBetweenSectors getWallBetween(SectorNum inactive, SectorNum active) {
    return WallBetweenSectors(inactive, active);
}


