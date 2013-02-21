module clan;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import clans;
import json;
import unit;

import game;
import mission;
import scheduler;

import util.filesystem;
import util.array;
import util.util;

import worldstate.worldstate;
import worldstate.activity;

//Clan id 0 is always reserved for GAIA.
shared int g_ClanCount = 1; //Unique clan id.

Clan newClan(WorldState world) {
    Clan clan = new NormalClan();
    clan.init(world);
    clan._clanId = g_ClanCount++;
    return clan;
}

class Clan : WorldStateListener {

    protected uint _clanId;
    uint clanId() const @property {
        return _clanId;
    }

    protected Array!TilePos toMine;

    protected Unit[int] clanMembers;
    protected Entity[int] clanEntities;

    protected WorldState world;

    void init(WorldState _world) {
        world = _world;
        Clans().addClan(this);

        //toMine = new Array!TilePos;
    }

    abstract Mission unsafeGetMission();
    abstract void unsafeDesignateMinePos(TilePos pos);

    abstract void addUnit(Unit unit);
    abstract void addEntity(Entity entity);

    abstract bool activeSector(SectorNum sectorNum);

    abstract bool unitMoveActivity(UnitPos from, UnitPos to);

    Unit getUnitById(int unitId) {
        Unit* unitPtr = unitId in clanMembers;
        if(unitPtr is null) return null;
        return *unitPtr;
    }

    abstract void serialize();
    abstract void deserialize(int _clanId);


    void onAddUnit(SectorNum sectorNum, Unit unit) {}
    void onAddEntity(SectorNum sectorNum, Entity entity) {}
    void onSectorLoad(SectorNum sectorNum) {}
    void onSectorUnload(SectorNum sectorNum) {}
    void onTileChange(TilePos tilePos) {}

    void onUpdateGeometry(TilePos tilePos) {}
    void onBuildGeometry(SectorNum sectorNum) {}

    void update(WorldState world, Scheduler scheduler) {
        foreach(entity ; clanEntities) {
            import changes.worldproxy;
            scheduler.push(syncTask((WorldProxy worldProxy) {
                //msg(&entity);
                entity.tick(worldProxy);
            }));
        }
    }
}

final class NormalClan : Clan {

    int[SectorNum] activityMap;

    this() {
    }
    
    override void init(WorldState _world) {
        super.init(_world);
    }


    override Mission unsafeGetMission() {
        if (toMine.empty) return Mission.none;
        auto ret = Mission(Mission.Type.mine, target(toMine.removeAny()));
        return ret;
    }
    override void unsafeDesignateMinePos(TilePos pos) {
        toMine ~= pos;
    }

    override void addUnit(Unit unit) {
        unit.clan = this;
        clanMembers[unit.id] = unit;
        auto centerSectorNum = unit.pos.getSectorNum();
        increaseActivity(centerSectorNum);
        world.addUnit(unit);
    }
    override void addEntity(Entity entity) {
        BREAKPOINT;
        entity.clan = this;
        clanEntities[entity.entityId] = entity;
        auto centerSectorNum = entity.pos.getSectorNum();
        world.addEntity(entity);
    }

    override bool activeSector(SectorNum sectorNum) {
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

    override bool unitMoveActivity(UnitPos from, UnitPos to) {
        auto a = from.getSectorNum();
        auto b = to.getSectorNum();
        if (a == b) {
            return false;
        }

        increaseActivity(b);
        decreaseActivity(a);
        return true;
    }

    override void serialize() {
        auto folder = g_worldPath ~ "/world/clans/" ~ to!string(clanId) ~"/";
        util.filesystem.mkdir(folder);

        Value darp(Unit unit) {
            return encode(unit);
        }
        auto clanMembers = Value(array(map!darp(array(clanMembers))));
        auto jsonString = json.prettifyJSON(clanMembers);
        std.file.write(folder ~ "members.json", jsonString);

    }

    override void deserialize(int clanId) {
        _clanId = clanId;
        auto folder = g_worldPath ~ "/world/clans/" ~ to!string(clanId) ~"/";
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
