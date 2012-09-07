module gaia;

import clan;
import mission;
import pos;
import treemanager;
import util.util;

import worldstate.worldstate;

class Gaia : public Clan {

    TreeManager treeManager; //Totally owned by gaia.

    this(WorldState world) {
        _clanId = 0;
        super(world);
        treeManager = new TreeManager(world);
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
    override bool activeSector(SectorNum sectorNum) {
        return 0;
    }

    override bool unitMoveActivity(UnitPos from, UnitPos to) {
        return false;
    }

    override void serialize() {
        //Derp herp serialize all things ever.
    }

    override void deserialize(int clanId) {
        //Herp derp deserialize all things ever.
    }

    void addTree(TilePos tilePos) {
        
    }   
}
