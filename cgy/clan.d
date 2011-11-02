module clan;

import std.array;


import unit;
import world.world;

// replace with struct if we decide we need type safety? :P
static union Target {
    UnitPos pos;
    TilePos tilePos;
    Unit* unit;
    void* obj;    //TODO: Replace with proper type :D
}
Target target(UnitPos t) { Target ret; ret.pos = t; return ret; }
Target target(TilePos t) { Target ret; ret.tilePos = t; return ret; }
Target target(Unit* t) { Target ret; ret.unit = t; return ret; }

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
}
