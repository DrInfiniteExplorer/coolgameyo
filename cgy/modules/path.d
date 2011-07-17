module modules.path;

import std.container;
import std.algorithm;
import std.math;
import std.stdio;
import std.conv;

import modules.module_;
import scheduler;
import util;


import graphics.debugging;

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
                                         //msg("finishing state ", i);
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

    int[TilePos] boxes;

    RedBlackTree!(TilePos, q{a.value < b.value}) openSet;
    RedBlackTree!(TilePos, q{a.value < b.value}) closedSet;

    this(PathID id_, UnitPos from_, UnitPos goal_) {

        id = id_;
        from = from_;
        goal = goal_;
        
        msg("goal = ", goal.tilePos);

        closedSet = new typeof(closedSet);
        openSet = new typeof(openSet);
        openSet.insert(from);
        g_score[from] = 0;
        f_score[from] = estimateBetween(from, goal);
        boxes[from] = addAABB(from.getAABB(), vec3f(1,0,0));
    }

    bool tick(World world) {
        assert (!finished);
        foreach (i; 0 .. stateTickCount) {
            tickety(world);
            if (finished) {
                return true;
            }
        }
        return false;
    }

    void tickety(World world) {
        if (openSet.empty) { // we failed to find a path
            finished = true;
            return;
        }

        auto x = findSmallest();

        assert (x !in closedSet);
        assert (x in g_score);
        assert (x in f_score);
 
        // this is retarded, cannot use goal.tilePos as rhs because it is
        // an rvalue, but using it as lhs is fine, wtf!
        if (goal.tilePos == x) { // woohoo!
            completePath(world, x);
            finished = true;
            return;
        }

        openSet.removeKey(x);

        closedSet.insert(x);

        removeAABB(boxes[x]);
        boxes[x] = addAABB(x.getAABB(), vec3f(0,1,0));

        f_score.remove(x);

        assert (x !in openSet);
        assert (x !in f_score);

        //msg("from = ", from);
        //msg("goal = ", goal);
        //msg("x = ", x);

        foreach (y; availibleNeighbors(world, x)) {
            // msg("y = ", y);
            if (y in closedSet) continue;

            assert (y !in closedSet);

            auto new_g = g_score[x] + costBetween(world, x, y);
            bool is_new = y !in g_score;

            if (is_new) {
                openSet.insert(y);
                boxes[y] = addAABB(y.getAABB(), vec3f(1,0,0));
            }
            if (is_new || new_g < g_score[y]) {
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
            //msg(g_score);
            //msg(f_score);
            assert (t in g_score);
            assert (t in f_score);
            assert (t in openSet, "WTFFFFFFFFFFFF!!!!!!!!!");
            assert (t !in closedSet, text("DIED ON ", t));
            if (f_score[t] < f) {
                x = t;
                f = f_score[t];
            }
        }
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
        enum estimateFactor = 0.99;
        auto xx = (a.value.X - b.value.X) ^^ 2;
        auto yy = (a.value.Y - b.value.Y) ^^ 2;
        auto zz = (a.value.Z - b.value.Z) ^^ 2;
        return estimateFactor * sqrt(xx + yy + zz);
    }

    void completePath(World world, TilePos x) {
        UnitPos[] p = [goal];
        while (from.tilePos != x) {
            p ~= x.toUnitPos();
            if (world.getTile(x).halfstep) {
                p[$-1].value.Z += 0.5;
            }
            x = cameFrom[x];
        }
        //p ~= from;
        result = Path(p);


        foreach (tp, i; boxes) {
            removeAABB(i);
        }

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
            Tile tile(TilePos tp) { return world.getTile(tp, false, false); }
            bool clear(TilePos tp) { return tile(tp).transparent; }
            bool pathable(TilePos tp) { return tile(tp).pathable; }
            bool solid(TilePos tp) { return !clear(tp) && !half(tp); }
            bool avail(TilePos tp) { return pathable(tp) && clear(above(tp)); }
            bool half(TilePos tp) { return tile(tp).halfstep; }

            bool test(TilePos tp) {
                if (!avail(tp)) return false;

                if (tp.value.Z == around.value.Z) {
                    return true;
                } else if (tp.value.Z > around.value.Z) {
                    assert (tp.value.X != around.value.X
                            || tp.value.Y != around.value.Y);
                    return half(around) || !half(tp);
                } else {
                    assert (tp.value.X != around.value.X
                            || tp.value.Y != around.value.Y);
                    return half(tp) || !half(around);
                }
            }
        }

        // this turned retarded;
        int opApply(scope int delegate(ref TilePos) y) {
            //msg("around = ", around);
            if (!avail(around)) {
                debug msg(around, " not availible, skipping");
                return 0;
            }

            auto w = TilePos(around.value + vec3i(-1, 0, 0));
            auto e = TilePos(around.value + vec3i( 1, 0, 0));
            auto n = TilePos(around.value + vec3i( 0, 1, 0));
            auto s = TilePos(around.value + vec3i( 0,-1, 0));

            if (test(w)) if (y(w)) return 1;
            if (test(e)) if (y(e)) return 1;
            if (test(n)) if (y(n)) return 1;
            if (test(s)) if (y(s)) return 1;

            w = above(w);
            e = above(e);
            n = above(n);
            s = above(s);

            if (test(w)) if (y(w)) return 1;
            if (test(e)) if (y(e)) return 1;
            if (test(n)) if (y(n)) return 1;
            if (test(s)) if (y(s)) return 1;

            w = below(below(w));
            e = below(below(e));
            n = below(below(n));
            s = below(below(s));

            if (test(w)) if (y(w)) return 1;
            if (test(e)) if (y(e)) return 1;
            if (test(n)) if (y(n)) return 1;
            if (test(s)) if (y(s)) return 1;

            return 0;
        }
    }

    AvailibleNeighbors availibleNeighbors(World world, TilePos tp) {
        return AvailibleNeighbors(world, tp);
    }
}
