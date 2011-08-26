
module util.tileiterator;

import std.conv;
import std.math;

import pos;
import util.util;

struct TileIterator{

    TilePos tile;
    vec3i dir;
    vec3d tMax;
    vec3d tDelta;
    int cnt;
    int maxIter;
    this(vec3d start, vec3d _dir, int limit = 1000) {
        maxIter = limit;
        tile.value = getTilePos(start);
        dir.X = _dir.X >= 0 ? 1 : -1;
        dir.Y = _dir.Y >= 0 ? 1 : -1;
        dir.Z = _dir.Z >= 0 ? 1 : -1;
                
        tDelta.X = abs(1.f / _dir.X);

        tDelta.Y = abs(1.f / _dir.Y);
        tDelta.Z = abs(1.f / _dir.Z);
        
        double inter(double start, int dir, double vel, double delta){
            if(cast(int)start == start) return vel > 0 ? delta : 0;
            auto func = vel > 0 ? &floor : &ceil;
            float stop = func(start+to!double(dir));
            float dist = stop-start;
            return dist/vel;
        }
        
        tMax.X = inter(start.X, dir.X, _dir.X, tDelta.X);
        tMax.Y = inter(start.Y, dir.Y, _dir.Y, tDelta.Y);
        tMax.Z = inter(start.Z, dir.Z, _dir.Z, tDelta.Z);
    }
    TilePos front() @property {
        return tile;
    }
    void popFront() {
        if (tMax.X < tMax.Y) {
            if (tMax.X < tMax.Z) {
                //INCREMENT X WOOO
                tile.value.X += dir.X;
                tMax.X += tDelta.X;
            } else {
                //INCREMENT Z WOOO
                tile.value.Z += dir.Z;
                tMax.Z += tDelta.Z;                
            }
        } else {
            if (tMax.Y < tMax.Z) {
                //INCREMENT Y WOOO
                tile.value.Y += dir.Y;
                tMax.Y += tDelta.Y;
            } else {
                //Increment Z WOOO
                tile.value.Z += dir.Z;
                tMax.Z += tDelta.Z;                
            }
        }
        cnt++;
    }
    bool empty() @property {
        return cnt > maxIter;
    }
    
}
