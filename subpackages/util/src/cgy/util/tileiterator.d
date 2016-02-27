
module cgy.util.tileiterator;

import std.algorithm;
import std.conv;
import std.math;

import cgy.math.vector : vec3i, vec3d;
import cgy.util.pos : TilePos, getTilePos;

//import cgy.util.util;

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
        dir.x = travelDir.x >= 0 ? 1 : -1;
        dir.y = travelDir.y >= 0 ? 1 : -1;
        dir.z = travelDir.z >= 0 ? 1 : -1;
                
        tDelta.x = abs(1.0f / travelDir.x);
        tDelta.y = abs(1.0f / travelDir.y);
        tDelta.z = abs(1.0f / travelDir.z);
        
        //How long 'time' until next collision
        double inter(double start, int dir, double vel, double delta){
            if(cast(int)start == start) return vel > 0 ? delta : 0;
            auto func = vel > 0 ? &floor : &ceil;
            float stop = func(start+to!double(dir));
            float dist = stop-start;
            return dist/vel;
        }
        
        tMax.x = inter(start.x, dir.x, travelDir.x, tDelta.x);
        tMax.y = inter(start.y, dir.y, travelDir.y, tDelta.y);
        tMax.z = inter(start.z, dir.z, travelDir.z, tDelta.z);
    }

    TilePos front() @property {
        return tile;
    }
    void popFront() {
        if (tPrevIntersection !is null) {
            *tPrevIntersection = min(tMax.x, tMax.y, tMax.z);
        }
        if (tMax.x < tMax.y) {
            if (tMax.x < tMax.z) {
                //INCREMENT X WOOO
                tile.value.x += dir.x;
                tMax.x += tDelta.x;
            } else {
                //INCREMENT Z WOOO
                tile.value.z += dir.z;
                tMax.z += tDelta.z;                
            }
        } else {
            if (tMax.y < tMax.z) {
                //INCREMENT Y WOOO
                tile.value.y += dir.y;
                tMax.y += tDelta.y;
            } else {
                //Increment Z WOOO
                tile.value.z += dir.z;
                tMax.z += tDelta.z;                
            }
        }
        cnt++;
    }
    bool empty() @property {
        return cnt > maxIter;
    }
    
}
