module clan;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import json;
import unit;
import util.filesystem;
import world.world;
import world.activity;

shared int g_ClanCount = 0; //Unique clan id.

// replace with struct if we decide we need type safety? :P
static union Target {
    UnitPos pos;
    TilePos tilePos;
    Unit unit;
    void* obj;    //TODO: Replace with proper type :D
}
Target target(UnitPos t) { Target ret; ret.pos = t; return ret; }
Target target(TilePos t) { Target ret; ret.tilePos = t; return ret; }
Target target(Unit t) { Target ret; ret.unit = t; return ret; }

struct Mission {
    /*
       here's how you use this thing:

       Mission myMission = clan.getMission(); // or from wherever you want

       if (myMission.type == Mission.Type.mine) {
           auto pos = myMission.tilePos;
       } else if (myMission.type == Mission.Type.haulSpSp) {
           auto from = myMission.from.stockpile;
           auto to = myMission.to.stockpile;
       } // ETC

     */

    enum Type { // Everything you can do
        nothing, // no mission availible :-(
        mine,
        attack,
        haulSpSp, // Stockpile to Stockpile
        haulWSp,  // World to Stockpile
    }


    Type type;

    Target from;
    Target to;

    alias to target;
    alias to this;


    this(Type mt) { type = mt; }
    this(Type mt, Target target) {
        type = mt;
        to = target;
    }
    this(Type mt, Target from_, Target to_) {
        type = mt;
        from = from_;
        to = to_;
    }
}

Clan newClan() {
    Clan clan = new Clan;
    clan.clanId = g_ClanCount++;
    return clan;
}

class Clan {
    uint clanId;
    
    TilePos[] toMine;

    Mission getMission() {
        if (toMine.empty) return Mission(Mission.Type.nothing);
        auto ret = Mission(Mission.Type.mine, target(toMine.back));
        toMine.popBack;
        toMine.assumeSafeAppend();
        return ret;
    }
    void insertMinePos(TilePos pos) {
        toMine ~= pos;
    }

    Unit[int] clanMembers;

    int[SectorNum] activityMap;


    void addUnit(Unit unit) {
        unit.clan = this;
        clanMembers[unit.unitId] = unit;
        auto centerSectorNum = unit.pos.getSectorNum();
        increaseActivity(centerSectorNum);
    }

    bool activeSector(SectorNum sectorNum) {
        return sectorNum in activityMap ? activityMap[sectorNum] != 0 : 0;
    }

    private void increaseActivity(SectorNum centralSectorNum) {
        foreach(sectorNum ; activityRange(centralSectorNum)) {
            if(sectorNum in activityMap) {
                activityMap[sectorNum] += 1;
            } else {
                activityMap[sectorNum] = 1;
            }
            
        }
    }

    private void decreaseActivity(SectorNum centralSectorNum) {
        foreach(sectorNum ; activityRange(centralSectorNum)) {
            activityMap[sectorNum] -= 1;
            if(activityMap[sectorNum] < 1) {
                activityMap.remove(sectorNum);
            }
        }
    }

    bool unitMoveActivity(UnitPos from, UnitPos to) {
        auto a = from.getSectorNum();
        auto b = to.getSectorNum();
        if (a == b) {
            return false;
        }

        increaseActivity(b);
        decreaseActivity(a);
        return true;
    }

    Unit getUnitById(int unitId) {
        Unit* unitPtr = unitId in clanMembers;
        if(unitPtr is null) return null;
        return *unitPtr;
    }

    void serialize() {
        auto folder = "saves/current/world/clans/" ~ to!string(clanId) ~"/";
        util.filesystem.mkdir(folder);

        Value darp(Unit unit) {
            return encode(unit);
        }
        auto clanMembers = Value(array(map!darp(array(clanMembers))));
	    auto jsonString = json.prettifyJSON(clanMembers);
        std.file.write(folder ~ "members.json", jsonString);

    }

    void deserialize(int _clanId) {
        clanId = _clanId;
        auto folder = "saves/current/world/clans/" ~ to!string(clanId) ~"/";
        enforce(exists(folder), "Folder does not exist!" ~ folder);

        auto content = readText(folder ~ "members.json");
        auto members = json.parse(content);

        foreach (unitVal ; members.elements) {
            Unit unit = new Unit;
            unit.fromJSON(unitVal);
            addUnit(unit);
        }

    }


}
