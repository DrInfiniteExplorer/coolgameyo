module clan;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.json : parseJSON;

import changes.worldproxy : WorldProxy;
import clans;
import unit;

import game;
import mission;
import scheduler : scheduler;

import cgy.util.filesystem;
import cgy.util.array;
import cgy.util.util;

import worldstate.worldstate;
import worldstate.activity;

//Clan id 0 is always reserved for GAIA.
shared int g_ClanCount = 0; //Unique clan id.

Clan newClan(WorldState world) {
    int id = core.atomic.atomicOp!"+="(g_ClanCount, 1);
    Clan clan = new NormalClan(id);
    //clan.init(world);
    //clan._clanId = g_ClanCount++;
    
    return clan;
}

class Clan : WorldStateListener {

    protected uint _clanId;
    uint clanId() const @property {
        return _clanId;
    }

    protected Array!TilePos toMine;
    //protected TilePos[] toMine;
    long toMineUpdated;

    protected Unit[int] clanMembers;
    protected Entity[int] clanEntities;

    protected WorldState world;

    this(uint _id) {
        _clanId = _id;
    }

    void init(WorldState _world) {
        world = _world;
        Clans().addClan(this);

        //toMine = new Array!TilePos;
    }

    abstract Mission unsafeGetMission();
    abstract void unsafeDesignateMinePos(TilePos pos, bool set);

    abstract void addUnit(Unit unit);
    abstract void addEntity(Entity entity);

    abstract bool activeSector(SectorNum sectorNum);

    abstract bool unitMoveActivity(UnitPos from, UnitPos to);

    Unit getUnitById(int unitId) {
        Unit* unitPtr = unitId in clanMembers;
        if(unitPtr is null) return null;
        return *unitPtr;
    }
    Entity getEntityById(int entityId) {
        Entity* entityPtr = entityId in clanEntities;
        if(entityPtr is null) return null;
        return *entityPtr;
    }

    abstract void serialize();
    abstract void deserialize();

    TilePos[] getMineDesignations() {
        return toMine[].dup;
    }

    void onAddUnit(SectorNum sectorNum, Unit unit) {}
    void onAddEntity(SectorNum sectorNum, Entity entity) {}
    void onSectorLoad(SectorNum sectorNum) {}
    void onSectorUnload(SectorNum sectorNum) {}
    void onTileChange(TilePos tilePos) {}

    void onUpdateGeometry(TilePos tilePos) {}
    void onBuildGeometry(SectorNum sectorNum) {}

    void update(WorldState world) {
        foreach(entity ; clanEntities) {
            scheduler.push(task(&entity.tick));
        }
    }
}

final class NormalClan : Clan {

    int[SectorNum] activityMap;

    this(uint id) {
        super(id);
    }
    
    override void init(WorldState _world) {
        super.init(_world);
    }


    override Mission unsafeGetMission() {
        if (toMine.empty) return Mission.none;
        //auto lastOne = toMine[$-1];
        //toMine.length -= 1;
        auto minePos = toMine.removeAny();
        auto ret = Mission(Mission.Type.mine, target(minePos));
        return ret;
    }

    override void unsafeDesignateMinePos(TilePos pos, bool set) {
        if(toMine.removeKey(pos) > 0) {
            if(!set) toMineUpdated = utime();
        }
        if(set) {
            toMine ~= pos;
            toMineUpdated = utime();
        }
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
        cgy.util.filesystem.mkdir(folder);

        JSONValue darp(Unit unit) {
            return unit.toJSON;
        }
        auto clanMembers = JSONValue(array(map!darp(array(clanMembers))));
        auto jsonString = clanMembers.toString;
        std.file.write(folder ~ "members.json", jsonString);

    }

    override void deserialize() {
        auto folder = g_worldPath ~ "/world/clans/" ~ to!string(clanId) ~"/";
        enforce(exists(folder), "Folder does not exist!" ~ folder);

        auto content = readText(folder ~ "members.json");
        auto members = content.parseJSON;

        foreach (size_t idx, JSONValue unitVal ; members) {
            Unit unit = new Unit(0);
            unit.fromJSON(unitVal);
            addUnit(unit);
        }

    }



}
