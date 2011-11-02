

module world.activity;

import std.algorithm;



import pos;
import util.rangefromto;
import util.util;

import world.sizes;


debug{
    auto activitySize = vec3i(1,1,1);
} else {
    auto activitySize = vec3i(3,3,3);
}



private mixin template ActivityHandlerMethods() {

    void increaseActivity(UnitPos activityLoc) {
        auto sectorNum = activityLoc.getSectorNum();
        auto sector = getSector(sectorNum);
        if (sector is null) {
            sector = loadSector(sectorNum);
        }
        if (sector is null) {
            sector = allocateSector(sectorNum);
        }

        if (sector.activity == 0) {
            addFloodFillPos(activityLoc);
        }

        foreach (p; activityRange(sectorNum)) {
            auto s = getSector(p);
            if (s is null) {
                s = loadSector(p);
            }
            s.increaseActivity();
        }

        foreach (p; activityRange(sectorNum)) {
            if (getSector(p).activity == 1) {
                floodingSectors ~= p;
                foreach (n; neighbors(p)) {
                    auto s = getSector(n);

                    if (s && s.activity > 1) {
                        addFloodFillWall(p, n);
                    }
                }
            }
        }
    }
    void moveActivity(UnitPos from, UnitPos to) {
        auto a = from.getSectorNum();
        auto b = to.getSectorNum();
        if (a == b) {
            return;
        }

        increaseActivity(to);

        foreach (p; activityRange(from.getSectorNum())) {
            //TODO: Make this work and stuff. Yeah!
            //It now triggers the invariant that says that sectors need to have activity.
            //Should be fixed with activity-linger-timer, which when ending should be handled by
            //serializing sector to disk.
            //getSector(p).decreaseActivity();
        }
    }

    void decreaseActivity(UnitPos activityLoc) {
        assert (0);
    }


    void addFloodFillPos(TilePos pos) {
        if( toFloodFill.insert(pos.getBlockNum())) {
            g_Statistics.FloodFillNew(1);
        }
        //Also clear seen-flag from neighbors.
        //Dont add them to floodfill; If we're unlucky we'll process these blocks
        //before the one which pos belongs to; and as such, if pos is a new air
        //tile, the air-visibility wont propagate to this tile.
        //Nevermind 3 lines above, solid tiles check for any nearby airtiles; they need not be seen themselves.... >.<
        foreach(num ; pos.getNeighboringBlockNums()) {
            auto block = getBlock(num);
            block.seen = false;
            setBlock(num, block);
        }

    }
    void addFloodFillWall(SectorNum inactive, SectorNum active) {
        foreach (inact, act; getWallBetween(inactive, active)) {
            if (getBlock(act).seen) {
                if( toFloodFill.insert(inact) ){
                    g_Statistics.FloodFillNew(1);
                }
            }
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
                           delta.X == 0 ? 0
                           : (delta.X == 1 ? BlocksPerSector.x - 1 : 0),
                           delta.Y == 0 ? 0
                           : (delta.Y == 1 ? BlocksPerSector.y - 1 : 0),
                           delta.Z == 0 ? 0
                           : (delta.Z == 1 ? BlocksPerSector.z - 1 : 0));
        auto end = vec3i( 
                         delta.X == 0 ? BlocksPerSector.x
                         : (delta.X == 1 ? BlocksPerSector.x-1 : 0),
                         delta.Y == 0 ? BlocksPerSector.y
                         : (delta.Y == 1 ? BlocksPerSector.y-1 : 0),
                         delta.Z == 0 ? BlocksPerSector.z
                         : (delta.Z == 1 ? BlocksPerSector.z-1 : 0));
        BlockNum b(vec3i v) {
            return BlockNum(v);
        }
        auto wall = map!(b)(RangeFromTo (bb+start, bb+end));

        foreach (bn; wall) {
            if (y(BlockNum(bn.value+delta), bn)) return 1;
        }

        return 0;
    }
}

WallBetweenSectors getWallBetween(SectorNum inactive, SectorNum active) {
    return WallBetweenSectors(inactive, active);
}


