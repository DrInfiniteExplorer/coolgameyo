module ai.minetileai;

import ai.moveai;
import changes.worldproxy;
import modules.path;
import cgy.util.pos;
import unit;
import cgy.util.util;


struct MineTileAI {

    bool finished, failed;

    TilePos toMine;
    MoveAI move;

    this(Unit unit, TilePos tp, PathModule pm) {
        toMine = tp;
        move = MoveAI(unit, near(tp.toUnitPos), pm);
    }

    int tick(WorldProxy world, PathModule pathfinder) {
        assert (!finished, "Tried to tick mine ai state which was finished");
        if (!move.finished) {
            scope (exit) {
                if (move.failed) {
                    msg("Couldn't find path! Failing mine tile thing...");
                    finished = true;
                    failed = true;
                }
            }
            return move.tick(world, pathfinder);
        }

        if (world.getTile(toMine).isAir) {
            finished = true;
            return 0;
        } else {
            msg("damaging tile");
            world.damageTile(toMine, 2);
            return 1;
        }
    }
}
