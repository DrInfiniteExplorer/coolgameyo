module gaia;

import std.algorithm;

import clan;
import json;
import mission;
import util.pos;
import treemanager;
import util.util;
import util.rangefromto;

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


class Gaia : public Clan {

    import util.singleton;
    mixin Singleton;

    int[SectorXYNum] activityMap;
    TreeManager treeManager; //Totally owned by gaia.

    this() {
        msg(this);
    }

    override void init(WorldState _world) {
        _clanId = 0;
        super.init(_world);
        treeManager = TreeManager();
        treeManager.init(world);
    }

    override Mission unsafeGetMission() {
        return Mission.init;
    }
    override void unsafeDesignateMinePos(TilePos pos) {
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

    override void deserialize(int clanId) {
        //Herp derp deserialize all things ever.
    }

    override void onSectorLoad(SectorNum sectorNum) {
        //If first time feature is actually in sector, make the feature affect the tiles.
        // For trees for example this means to grow the tree the first time.
        //  But, But..! What if we go away and the tree grows and... uääärgh!
        auto layer = world.worldMap.getMap(TileXYPos(sectorNum.toTilePos()), 1);
        foreach(feature ; layer.getFeatures()) {
            import feature.feature;
            auto tree = cast(TreeFeature) feature;
            if(tree is null) continue;
            if(tree.isPlaced) continue;
            auto xyTp = tree.pos;
            auto sectorXY = SectorXYNum(sectorNum);
            if(!sectorXY.inside(xyTp)) continue;
            tree.isPlaced = true;
            auto tp = world.getTopTilePos(xyTp);
            //msg("Got tree at ", tp);
            addTree(tp);
        }
    }

    void addTree(TilePos tilePos) {
        return;
        /*
        import entitytypemanager;
        auto treeType = EntityTypeManager().byName("tree01");
        //msg("Fix createEntity-function of awesomeness");
        //treeManager.createTreeEntity(tilePos, treeType);
        auto ent = newEntity(treeType);
        ent.pos = tilePos.toEntityPos();
        world.worldProxy.createEntity(ent, makeJSONObject("clanId", 0));
        */
    }   
}
