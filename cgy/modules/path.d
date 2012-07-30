module modules.path;

import std.container;
import std.algorithm;
import std.math;
import std.range;
import std.stdio;
import std.conv;

import json;
import modules.module_;
import scheduler;
import util.util;
import util.filesystem;
import util.array;

alias util.array.Array Array;


import graphics.debugging;

template CondAlias(bool cond, alias a, alias b) {
    static if (cond) {
        alias a CondAlias;
    } else {
        alias b CondAlias;
    }
}



struct PathID {
    ulong id;
}
struct Path {
    // WorldState w;
    // TODO: add path smoothing here? D:
    UnitPos[] path;

    double pathLength() @property {
        auto m = map!q{a.value}(path);
        auto p = m.front;
        m.popFront();

        double ret = 0;
        foreach (x; m) {
            ret += x.getDistanceFrom(p);
            p = x;
        }
        return ret;
    }
    Value serialize() {
        Value derp(UnitPos a) {
            return encode(a.value);
        }
        //auto a = array(map!(derp)(path));
        return Value(array(map!derp(path)));
    }

    bool empty() const @property {
        return path.empty;
    }
}

enum maxPathTicks = 35;

final class PathModule : Module {

    ulong nextIDNum;

    Path[PathID] finishedPaths;

    PathFindState[PathID] activeStates;

    this() {
    }

    void finishPath(PathID id) {
        synchronized(this) {
            assert (activeStates[id].finished, "finished");
            auto s = activeStates[id].result;
            activeStates.remove(id);
            finishedPaths[id] = s;
        }
    }

    PathID findPath(UnitPos[] from, UnitPos[] to) {
        synchronized(this) {
            auto ret = PathID(nextIDNum++);
            activeStates[ret] = PathFindState(from, to);
            return ret;
        }
    }

    bool pollPath(PathID id, out Path path) {
        synchronized (this) {
            if (id !in finishedPaths) return false;

            path = finishedPaths[id];
            finishedPaths.remove(id);
            return true;
        }
    }

     //Module interface
    override void serializeModule() {
        
        Value serializeFinishedPaths() {
            Value[string] values;
            foreach(key, value ; finishedPaths) {
                values[to!string(key.id)] = value.serialize();
            }
            return Value(values);
        }
        Value serializeActiveStates() {
            Value derp(PathFindState state) {
                return Value([
                    "from" : encode(array(map!(a => a.value)(state.from))),
                    "goal" : encode(array(map!(a => a.value)(state.goal))),
                    ]);
            }
            return Value(array(map!derp(activeStates.values[])));            
        }
        
        Value[string] values;
        values["nextIdNum"] = Value(nextIDNum);
        values["finishedPaths"] = serializeFinishedPaths();
        values["activeStates"] = serializeActiveStates();
        Value jsonRoot = Value(values);
	    auto jsonString = json.prettifyJSON(jsonRoot);
        
        mkdir("saves/current/modules/path");
        std.file.write("saves/current/modules/path/states.json", jsonString);
        
    }
    override void deserializeModule() {
        BREAKPOINT;
    }

    override void update(WorldState world, Scheduler scheduler) { //Module interface
        synchronized(this) {
            size_t i = 0;
            foreach (id, ref state; activeStates) {

                i += 1;
                if (i >= maxPathTicks) { break; }

                scheduler.push(
                        asyncTask(
                            ((id, state) => {
                                 if (state.tick(world)) {
                                     assert(state.finished);
                                     finishPath(id);
                                 }
                             })(id, &state)));
            }
        }
    }
}


enum stateTickCount = 10;


static struct PathFindState {
    alias RedBlackTree!(TilePos, q{a.value < b.value}) Set; 

    bool finished;
    Path result;

    UnitPos[] from;
    UnitPos[] goal;

    TilePos[TilePos] cameFrom;
    TilePos[TilePos] wentTo;
    double[TilePos] g_score;
    double[TilePos] f_score;

    int[TilePos] boxes;

    Set openf;
    Set openb;

    Set closed;

    int tick_count;

    this(UnitPos[] from_, UnitPos[] goal_) {

        from = from_.dup;
        goal = goal_.dup;
        
        closed = new Set;
        openf = new Set;
        openb = new Set;

        openf.insert(from);
        openb.insert(goal);

        foreach (p; chain(from, goal)) {
            g_score[p] = 0;
        }

        // NOT GOOD:
        foreach (f; from) {
            f_score[f] = estimateBetween(f, goal[0]);
        }
        foreach (g; goal) {
            f_score[g] = estimateBetween(from[0], g);
        }

        foreach (p; chain(from, goal)) {
            boxes[p] = addAABB(p.getAABB(), vec3f(1,0,0));
            boxes[p] = addAABB(p.getAABB(), vec3f(1,0,0));
        }
    }

    bool tick(WorldState world) {
        assert (!finished);
        foreach (i; 0 .. stateTickCount) {

            // Working one way only:
            //  948, 54.5623
            //  781, 54.0623

            // Working both ways:
            //  681, 53.4443
            //  595, 54.2984

            // It's good that the tick count is lower, not so good that the
            // distance is different. However, they are so close that we don't
            // really care, I guess? (-:

            tickety!true(world);
            if (finished) { return true; }
            tickety!false(world);
            if (finished) { return true; }
        }
        return false;
    }

    void tickety(bool fwd)(WorldState world) {
        alias CondAlias!(fwd, openf, openb) open;
        alias CondAlias!(!fwd, openf, openb) other;

        tick_count += 1;

        if (open.empty) { // we failed to find a path
            finished = true;
            return;
        }

        auto x = findSmallest!fwd();

        if (x in other) {
            completePath(world, x);
            finished = true;
            return;
        }

        open.removeKey(x);

        closed.insert(x);

        removeAABB(boxes[x]);
        boxes[x] = addAABB(x.getAABB(), vec3f(0,1,0));

        f_score.remove(x);

        foreach (y; availibleNeighbors!fwd(world, x)) {
            if (y in closed) continue;

            static if (fwd) {
                auto new_g = g_score[x] + costBetween(world, x, y);
            } else {
                auto new_g = g_score[x] + costBetween(world, y, x);
            }
            bool is_new = y !in open;

            if (is_new) {
                open.insert(y);
                if (y in boxes) removeAABB(boxes[y]);
                boxes[y] = addAABB(y.getAABB(), vec3f(1,0,0));
            }
            if (is_new || new_g < g_score[y]) {
                g_score[y] = new_g;
                static if (fwd) {
                    f_score[y] = new_g + estimateBetween(y, goal[0]);
                    cameFrom[y] = x;
                } else {
                    f_score[y] = new_g + estimateBetween(from[0], y);
                    wentTo[y] = x;
                }

            }
        }
    }

    TilePos findSmallest(bool fwd)() {
        alias CondAlias!(fwd, openf, openb) open;
        TilePos x;
        double f = double.infinity;
        
        foreach (t; open[]) {
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

    double costBetween(WorldState world, TilePos a, TilePos b) {

        if (a.value.Z == b.value.Z) {
            return normalStep;
        } else if (a.value.Z > b.value.Z) {
            return moveDownRegular;
        } else {
            return moveUpRegular;
        }
    }
    double estimateBetween(TilePos a, TilePos b) {
        enum estimateFactor = 0.99;
        auto xx = (a.value.X - b.value.X) ^^ 2;
        auto yy = (a.value.Y - b.value.Y) ^^ 2;
        auto zz = (a.value.Z - b.value.Z) ^^ 2;
        return estimateFactor * sqrt(cast(real)xx + yy + zz);
    }

    void completePath(WorldState world, TilePos x) {
        UnitPos[] p;
        TilePos y = x;

        void push(TilePos tp) {
            p ~= tp.toUnitPos();
        }

        while (!canFind(map!(a=>a.tilePos)(goal), y)) {
            BREAK_IF(y !in wentTo);
            y = wentTo[y];
            push(y);
        }
        
        //p ~= goal;

        //std.algorithm.reverse(p); bug/shit/whatever
        foreach (i; 0 .. p.length / 2) {
            swap(p[i], p[$-1-i]);
        }

        while (!canFind(map!(a=>a.tilePos)(from), x)) {
            push(x);
            x = cameFrom[x];
        }

        result = Path(p);

        msg("Path completed in ", tick_count,
                " with length ", result.pathLength);

        foreach (tp, i; boxes) {
            removeAABB(i);
        }

    }

    // BUG: TODO: I have no idea if this is correct code
    // TODO: Now only walks {n,e,s,w}, should walk diagonally as well
    private static struct AvailibleNeighbors(bool fwd) {
        WorldState world;
        TilePos around;

        private {
            TilePos above(TilePos tp) {
                return TilePos(tp.value + vec3i(0,0,1));
            }
            TilePos below(TilePos tp) {
                return TilePos(tp.value - vec3i(0,0,1));
            }
            Tile tile(TilePos tp) { return world.getTile(tp, false); }
            bool clear(TilePos tp) { return tile(tp).isAir; }
            bool solid(TilePos tp) { return !clear(tp); }
            bool pathable(TilePos tp) { return clear(tp) && solid(below(tp)); }
            bool avail(TilePos tp) { return pathable(tp) && clear(above(tp)); }

            bool test_from_to(TilePos a, TilePos b)
            in{
                assert (a.value.X != b.value.X
                        || a.value.Y != b.value.Y
                        || a.value.Z != b.value.Z, "a and b are the same tile!");
            }
            body{
                if (!avail(a) || !avail(b)) return false;
                return true;
                /*
                if (a.value.Z == b.value.Z) {
                    return true;
                } else if (a.value.Z < b.value.Z) {
                    return true;
                } else {
                    return true;
                }
                */
            }
            
            bool test(TilePos tp) {
                static if (fwd) {
                    return test_from_to(around, tp);
                } else {
                    return test_from_to(tp, around);
                }
            }
        }

        // this turned retarded;
        int opApply(scope int delegate(ref TilePos) y) {
            if (!avail(around)) {
                msg(around, " not availible, skipping");
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

    auto availibleNeighbors(bool fwd)(WorldState world, TilePos tp) {
        return AvailibleNeighbors!fwd(world, tp);
    }
}
