import world;
import scheduler;
import pos;

abstract class Module {
    Scheduler scheduler; // design this away please
    
    void update(World world);
}

struct PathID {
    ulong id;
}
struct Path {
    TilePos[] derp;
}

class PathModule : Module {

    static struct PathFindState {
        void tick() {
            assert (false);
        }
    }

    ulong nextIDNum;

    Path[PathID] finishedPaths;

    PathFindState[] activeStates;

    PathID findPath(TilePos from, TilePos to) {
        assert (0);

        return PathID(nextIDNum++);
    }
    bool pollPath(PathID id, out Path path) {
        if (id !in finishedPaths) return false;

        path = finishedPaths[id];
        finishedPaths.remove(id);
        return true;
    }
    
    override void update(World world) {
            assert (false);
        foreach (state; activeStates) {
            scheduler.push(asyncTask({ return state.tick(); }));
        }
    }
}


class AIModule : Module {

    PathModule pathmodule;

    this(PathModule pathmodule_) {
        pathmodule = pathmodule_;
    }

    override void update(World world) {
            assert (false);
        foreach (unit; world.getUnits()) {
            scheduler.push(syncTask({ return unit.tick(pathmodule); }));
        }
    }
}



