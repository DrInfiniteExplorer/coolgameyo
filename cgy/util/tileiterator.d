
module util.tileiterator;

import std.algorithm;
import std.conv;
import std.math;

import pos;
import util.util;

struct TileIterator{

    TilePos tile;
    vec3i dir; //Just contains values that are -1 or 1
    vec3d tMax;//The lowest value is how long time it took to travel to our next intersection.
               //The values are how long it'll take to travel to the next intersewction along those axises
    double *tPrevIntersection; //Time traveled to collide with current tile
    vec3d tDelta; //Time to travel along one tile in each axis
    vec3d startPos;
    vec3d travelDir; //The dir that we initialized the range with, nor nexxesarry normalixed
    int cnt;
    int maxIter;
    this(vec3d start, vec3d _dir, int limit = 1000, double* pCollideTime = null) {
        tPrevIntersection = pCollideTime;
        if (tPrevIntersection !is null) {
            *tPrevIntersection = 0.0;
        }
        maxIter = limit;
        tile.value = getTilePos(start);
        travelDir = _dir;
        startPos = start;
        dir.X = travelDir.X >= 0 ? 1 : -1;
        dir.Y = travelDir.Y >= 0 ? 1 : -1;
        dir.Z = travelDir.Z >= 0 ? 1 : -1;
                
        tDelta.X = abs(1.f / travelDir.X);
        tDelta.Y = abs(1.f / travelDir.Y);
        tDelta.Z = abs(1.f / travelDir.Z);
        
        //How long 'time' until next collision
        double inter(double start, int dir, double vel, double delta){
            if(cast(int)start == start) return vel > 0 ? delta : 0;
            auto func = vel > 0 ? &floor : &ceil;
            float stop = func(start+to!double(dir));
            float dist = stop-start;
            return dist/vel;
        }
        
        tMax.X = inter(start.X, dir.X, travelDir.X, tDelta.X);
        tMax.Y = inter(start.Y, dir.Y, travelDir.Y, tDelta.Y);
        tMax.Z = inter(start.Z, dir.Z, travelDir.Z, tDelta.Z);
    }

    TilePos front() @property {
        return tile;
    }
    void popFront() {
        if (tPrevIntersection !is null) {
            *tPrevIntersection = min(tMax.X, tMax.Y, tMax.Z);
        }
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
