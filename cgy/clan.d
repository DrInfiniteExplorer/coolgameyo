module clan;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import json;
import unit;

import mission;

import util.filesystem;
import util.array;
import util.util;

import worldstate.worldstate;
import worldstate.activity;

shared int g_ClanCount = 0; //Unique clan id.


Clan newClan(WorldState world) {
    Clan clan = new Clan(world);
    clan.clanId = g_ClanCount++;
    return clan;
}

final class Clan {

    uint clanId;

    Array!TilePos toMine;

    Unit[int] clanMembers;

    int[SectorNum] activityMap;
    WorldState world;

    this(WorldState _world) {
        world = _world;
        world.addClan(this);

        toMine = new Array!TilePos;
    }

    Mission unsafeGetMission() {
        if (toMine.empty) return Mission.none;
        auto ret = Mission(Mission.Type.mine, target(toMine.removeAny()));
        return ret;
    }
    void unsafeDesignateMinePos(TilePos pos) {
        toMine ~= pos;
    }

    void addUnit(Unit unit) {
        unit.clan = this;
        clanMembers[unit.id] = unit;
        auto centerSectorNum = unit.pos.getSectorNum();
        increaseActivity(centerSectorNum);
        world.addUnit(unit);
    }

    bool activeSector(SectorNum sectorNum) {
        return sectorNum in activityMap ? activityMap[sectorNum] != 0 : 0;
    }

    private void increaseActivity(SectorNum centralSectorNum) {
        foreach (sectorNum; activityRange(centralSectorNum)) {
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
