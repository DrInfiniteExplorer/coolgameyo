module modules.path;

import std.container;
import std.algorithm;
import std.math;
import std.stdio;

import modules.module_;
import scheduler;
import util;

struct PathID {
    ulong id;
}
struct Path {
    // World w;
    // TODO: add path smoothing here? D:
    UnitPos[] path;
}

enum maxPathTicks = 35;

class PathModule : Module {

    ulong nextIDNum;

    Path[PathID] finishedPaths;

    PathFindState[] activeStates;
    size_t[] toRemoveIndexes;

    void finishPath(size_t activeStatesIndex) {
        synchronized {
            auto s = activeStates[activeStatesIndex];
            toRemoveIndexes ~= activeStatesIndex;

            assert (s.finished, "s.finished");
            finishedPaths[s.id] = s.result;
        }
    }

    PathID findPath(UnitPos from, UnitPos to) {
        synchronized {
            auto ret = PathID(nextIDNum++);
            activeStates ~= PathFindState(ret, from, to);
            return ret;
        }
    }

    bool pollPath(PathID id, out Path path) {
        synchronized {
            if (id !in finishedPaths) return false;

            path = finishedPaths[id];
            finishedPaths.remove(id);
            return true;
        }
    }

    override void update(World world, Scheduler scheduler) {
        synchronized {
            removeFinished();

            foreach (i, ref state; activeStates[0 .. min($, maxPathTicks)]) {
                    scheduler.push(
                            asyncTask(
                                ((size_t i, PathFindState* state) {
                                 return {
                                     if (state.tick(world)) {
                                         assert(state.finished);
                                         writeln("finishing state ", i);
                                         finishPath(i);
                                     }};
                                 })(i, &state)));
            }
        }
    }

    void removeFinished() {
        if (toRemoveIndexes.length == 0) return;

        size_t r;
        size_t i;
        foreach (j, state; activeStates) {
            if (j == toRemoveIndexes[r]) {
                r += 1;
            } else {
                activeStates[i] = state;
                i += 1;
            }
        }
        activeStates.length -= toRemoveIndexes.length;
        toRemoveIndexes.length = 0;

        activeStates.assumeSafeAppend();
        toRemoveIndexes.assumeSafeAppend();
    }
}


enum stateTickCount = 10;

static struct PathFindState {
    PathID id;

    bool finished;
    Path result;

    UnitPos from;
    UnitPos goal;

    TilePos[TilePos] cameFrom;
    double[TilePos] g_score;
    double[TilePos] f_score;

    RedBlackTree!(TilePos, q{a.value < b.value}) openSet;
    RedBlackTree!(TilePos, q{a.value < b.value}) closedSet;

    this(PathID id_, UnitPos from_, UnitPos goal_) {

        openSet = new typeof(openSet);
        closedSet = new typeof(closedSet);

        id = id_;
        from = from_;
        goal = goal_;
        openSet = new typeof(openSet);
        closedSet = new typeof(closedSet);
    }

    bool tick(World world) {
        assert (!finished);
        foreach (i; 0 .. stateTickCount) {
            tickety(world);
            if (finished) return true;
        }
        return false;
    }

    void tickety(World world) {
        if (openSet.empty) { // we failed to find a path
            finished = true;
            return;
        }

        auto x = findSmallest();
 
        // this is retarded, cannot use goal.tilePos as rhs because it is
        // an rvalue, but using it as lhs is fine, wtf!
        if (goal.tilePos == x) { // woohoo!
            completePath(world, x);
            finished = true;
            return;
        }

        closedSet.insert(x);

        foreach (y; availibleNeighbors(world, x)) {
            if (y in closedSet) continue;
            auto new_g = g_score[x] + costBetween(world, x, y);
            bool is_new = y !in g_score;

            if (is_new) {
                openSet.insert(y);
            }
            if (is_new || g_score[y] > new_g) {
                cameFrom[y] = x;
                g_score[y] = new_g;
                f_score[y] = new_g + estimateBetween(y, goal);
            }
        }
    }

    TilePos findSmallest() {
        TilePos x;
        double f = double.infinity;
        
        foreach (t; openSet[]) {
            if (f_score[t] < f) {
                x = t;
                f = f_score[t];
            }
        }
        openSet.removeKey(x);
        f_score.remove(x);
        return x;
    }

    // costs, lol
    enum moveUpHalfstep = 1.6;
    enum moveDownHalfstep = 1.1;
    enum moveUpRegular = 4.5;
    enum moveDownRegular = 2.7;
    enum normalStep = 1.0;

    double costBetween(World world, TilePos a, TilePos b) {

        bool halfa = world.getTile(a).halfstep;
        bool halfb = world.getTile(b).halfstep;

        if (a.value.Z == b.value.Z) {
            if (halfa == halfb) {
                return normalStep;
            } else {
                return halfa ? moveDownHalfstep : moveUpHalfstep;
            }
        } else if (a.value.Z > b.value.Z) {
            if (halfa == halfb) {
                return moveDownRegular;
            } else {
                assert (halfb);
                return moveDownHalfstep;
            }
        } else {
            if (halfa == halfb) {
                return moveUpRegular;
            } else {
                assert (halfa);
                return moveUpHalfstep;
            }
        }
    }
    double estimateBetween(TilePos a, TilePos b) {
        enum estimateFactor = 0.7;
        auto xx = (a.value.X - b.value.X) ^^ 2;
        auto yy = (a.value.Y - b.value.Y) ^^ 2;
        auto zz = (a.value.Z - b.value.Z) ^^ 2;
        return estimateFactor * sqrt(xx + yy + zz);
    }

    void completePath(World world, TilePos x) {
        UnitPos[] p = [goal];
        while (from.tilePos != x) {
            p ~= UnitPos(convert!double(x.value)
                    + (world.getTile(x).halfstep 
                        ? vec3d(0,0,0.5)
                        : vec3d(0,0,0)));
            x = cameFrom[x];
        }
        //p ~= from;
        result = Path(p);
    }

    // BUG: TODO: I have no idea if this is correct code
    // TODO: Now only walks {n,e,s,w}, should walk diagonally as well
    private static struct AvailibleNeighbors {
        World world;
        TilePos around;

        private {
            TilePos above(TilePos tp) {
                return TilePos(tp.value + vec3i(0,0,1));
            }
            TilePos below(TilePos tp) {
                return TilePos(tp.value - vec3i(0,0,1));
            }
            bool solid(TilePos tp) { return world.getTile(tp).solid; }
            bool ok(TilePos tp) { return !solid(tp); }
            bool avail(TilePos tp) { return ok(tp) && ok(above(tp)); }
            bool half(TilePos tp) { return world.getTile(tp).halfstep; }


            bool test(TilePos tp, out TilePos ret) {
                assert (around.value.Z == tp.value.Z);
                assert (solid(below(around)) || half(around));

                if (avail(tp)) {
                    if (solid(below(tp)) || half(tp)) {
                        ret = tp;
                        return true;
                    } else {
                        ret = below(tp);
                        return solid(below(below(tp)))
                            && (!half(around) || half(below(tp)));
                    }
                } else {
                    ret = above(tp);
                    return avail(above(around)) && avail(above(tp))
                        && (!half(above(tp)) || half(around));
                }
            }
        }

        int opApply(scope int delegate(ref TilePos) y) {
            assert (avail(around));

            auto w = TilePos(around.value + vec3i(-1, 0, 0));
            auto e = TilePos(around.value + vec3i( 1, 0, 0));
            auto n = TilePos(around.value + vec3i( 0, 1, 0));
            auto s = TilePos(around.value + vec3i( 0,-1, 0));

            TilePos tp;
            if (test(w, tp)) if (y(tp)) return 1;
            if (test(e, tp)) if (y(tp)) return 1;
            if (test(n, tp)) if (y(tp)) return 1;
            if (test(s, tp)) if (y(tp)) return 1;
            
            return 0;
        }
    }

    AvailibleNeighbors availibleNeighbors(World world, TilePos tp) {
        return AvailibleNeighbors(world, tp);
    }
}
