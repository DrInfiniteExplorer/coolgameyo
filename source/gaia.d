module gaia;

import std.algorithm;

import cgy.debug_.debug_ : BREAKPOINT;

import clan;
import mission;
import cgy.util.pos;
import cgy.util.util : msg;
import cgy.util.rangefromto;

import worldstate.worldstate;

auto gaiaSize = vec2i(10, 10);

auto gaiaRange(SectorXYNum base) {
    SectorXYNum a(vec2i d){
        return SectorXYNum(d);
    }
    return map!(a)(Range2D (
                              base.value - gaiaSize/2,
                              base.value + gaiaSize/2));
}

class Gaia : Clan {

    import cgy.util.singleton;
    mixin Singleton;

    int[SectorXYNum] activityMap;

    this() {
        super(0);
        msg(this);
    }

    override void init(WorldState _world) {
        _clanId = 0;
        super.init(_world);
    }

    override Mission unsafeGetMission() {
        return Mission.init;
    }
    override void unsafeDesignateMinePos(TilePos pos, bool set) {
        toMine ~= pos;
    }

    override void addUnit(Unit unit) {
        BREAKPOINT;
        unit.clan = this;
        clanMembers[unit.id] = unit;
        auto centerSectorNum = unit.pos.getSectorNum();
        world.addUnit(unit);
    }

    override void addEntity(Entity entity) {
        entity.clan = this;
        clanEntities[entity.entityId] = entity;
        auto centerSectorNum = entity.pos.getSectorNum();
        world.addEntity(entity);
    }

    override bool activeSector(SectorNum sectorNum) {
        return 0;
    }

    private void increaseActivity(SectorNum centralSectorNum) {
        foreach (sectorNum; gaiaRange(SectorXYNum(centralSectorNum))) {
            if(sectorNum in activityMap) {
                activityMap[sectorNum] += 1;
            } else {
                activityMap[sectorNum] = 1;
            }

        }
    }

    private void decreaseActivity(SectorNum centralSectorNum) {
        foreach(sectorNum ; gaiaRange(SectorXYNum(centralSectorNum))) {
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
        //Derp herp serialize all things ever.
    }

    override void deserialize() {
        //Herp derp deserialize all things ever.
    }

    override void onSectorLoad(SectorNum sectorNum) {
    }
}
