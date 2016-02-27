

module ai.possessai;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import changes.changes;
import changes.worldproxy;
import light;
import modules.path;
import scene.scenemanager;
import unit;
import cgy.util.rangefromto;
import cgy.math.vector : vec3f;

import worldstate.worldstate;

class FPSControlAI {
    Unit unit;

    UnitAI oldAi;
    //vec3d velocity;
    float fallSpeed;
    bool onGround;
    WorldState world;
    SceneManager scene;
    vec3d unitPos;

    this(Unit unit, WorldState w , SceneManager s ) {
        world = w;
        scene = s;
        setUnit(unit);
    }
    
    private bool destroyed;
    ~this() {
        BREAK_IF(!destroyed);
    }
    void destroy() {
        destroyed = true;
    }

    void setUnit(Unit u){
        if (u is unit) {
            return;
        }
        if (unit) {
            unit.ai = oldAi;
            scene.getProxy(unit).scale = vec3f(1.0f);
        }
        if (u is null) return;
        unit = u;        
        unit.ai = null;
        fallSpeed = 0.0f;
        onGround=false;
        unitPos = unit.pos.value;
        scene.getProxy(u).scale = vec3f(0.0f);

        //LATER: Send data to clients that this unit is possessed!!!!
        // :)
    }


    static immutable dirs = [vec3i(1, 0, 0), vec3i(0, 1, 0), vec3i(0, 0, 1)];
    vec3i[3] sizes;

    vec3d collideMove(vec3d pos, vec3d dir){
        immutable NOOO = vec3d(0,0,0);
        if (dir == NOOO) {
            return pos;
        }
        immutable epsilon = 1.0E-7;
        immutable OneEps = 1.0-epsilon;
        if (dir == vec3d(0, 0, 0)) { return pos; }
        if (dir.getLength > OneEps) {
            dir.setLength(OneEps);
        }
        //TODO: The stuff below
        /*
        if (dir.getLengthSQ() >= OneEps) {
            //It will fail otherwise, because we currently only check one layer of tiles in the direction we move.
            //Could make it check many layers, but would then be better to split the movement into many
            //unit-sized movements, to handle for example fast running in a diagonal corridor.
            enforce(0, "Implement handling of dir lengths longer than 1");
        }
        */
        auto tp = UnitPos(pos).tilePos;

        auto unitWidth = unit.unitWidth;
        auto unitHeight = unit.unitHeight;
        
        sizes[0] = vec3i(1,                cast(int)floor(unitWidth)+1,    cast(int)ceil(unitHeight)+1);
        sizes[1] = vec3i(cast(int)floor(unitWidth)+1,  1,                  cast(int)ceil(unitHeight)+1);
        sizes[2] = vec3i(cast(int)floor(unitWidth)+1,  cast(int)ceil(unitWidth)+1,    1);

        foreach(idx ; 0 .. 3) {
            vec3i axis = dirs[idx];
            auto daxis = axis.convert!double();
            auto axisLength = daxis.dotProduct(dir); //The length we want to move along this axis, and direction.
            auto sign = axisLength > 0 ? 1.0 : -1.0;
            double axisPos = pos.dotProduct(daxis); //
            if (axisLength == 0) {
                continue; //No need to check directions we dont move in.
            }
            auto D = daxis * axisLength;
            double size;
            if (idx == 2) {
                if ( axisLength > 0 ) { //If moving upwards, this is how much from 'unit body middle' to top of head
                    size = unitHeight-0.5;
                } else {
                    size = 0.5; //Units body centers are 0.5 from bottom of their feet.
                }
            } else {
                size = unitWidth * 0.5;
            }
            double axisDistanceToWall; //Not absolute
            int wallNum;
            if (axisLength > 0) {
                // 'Fails' in one case; When one starts in [0, epsilon] from the "last" wall.
                // Works fine though, as long as one moves less than OneEps per movement.
                wallNum = cast(int)floor(axisPos+size+OneEps);
                axisDistanceToWall = cast(double)wallNum - (axisPos + size);
            } else {
                //'Fails' when we are [0, epsilon] from the "last" wall;
                // If so, correct the result.
                wallNum = cast(int)ceil(axisPos-size-OneEps)-1;
                auto tmp = wallNum+1.0 -(axisPos-size);
                if (0 < tmp && tmp < epsilon) {
                    wallNum --;
                }
                axisDistanceToWall = tmp;
            }
            //The sign-multiplication should make it absolute.
            // But would abs be faster / better?
            //If we move exactly up to the wall, then that's ok too.
            if (axisLength * sign <= axisDistanceToWall * sign) { //Will not collide with this wall
                continue;
            }
            vec3i start;
            vec3i stop;
            if( idx == 0 ) {
                start = vec3i(0, cast(int)floor(pos.y - unitWidth * 0.5), cast(int)floor(pos.z - 0.5));
                stop = vec3i(0, cast(int)ceil(pos.y + unitWidth * 0.5)-1, cast(int)ceil(pos.z + unitHeight - 0.5)-1);
            } else if (idx == 1) {
                start = vec3i(cast(int)floor(pos.x - unitWidth * 0.5), 0, cast(int)floor(pos.z - 0.5));
                stop = vec3i(cast(int)ceil(pos.x + unitWidth * 0.5)-1, 0, cast(int)ceil(pos.z + unitHeight - 0.5)-1);
            } else if (idx == 2) {
                start = vec3i(cast(int)floor(pos.x - unitWidth * 0.5), cast(int)floor(pos.y - unitWidth * 0.5), 0);
                stop = vec3i(cast(int)ceil(pos.x + unitWidth * 0.5)-1, cast(int)ceil(pos.y + unitWidth * 0.5)-1, 0);
            }
            foreach( ppp ; RangeFromTo(start, stop)) {
                auto p = (axis * wallNum) + ppp;
                auto tile = world.getTile(TilePos(p));
                if (tile.isAir) {
                    continue;
                }
                dir[idx] = axisDistanceToWall;
                if (idx == 2) {
                    onGround = true;
                }
                break;
            }
        }
        return pos + dir;
    }

    //Make sure that it is sent over network, and such!! (like comment below)
    void move(float right, float fwd, float up, float deltaT) {
        immutable origo = vec3d(0, 0, 0);

        onGround = false;
        fallSpeed -= 10.0f * deltaT;
        auto dir = vec3d(fwd, -right, up + fallSpeed) * deltaT;
        dir.rotateXYBy(unit.rotation, origo);
        unitPos = collideMove(unitPos, dir);
        if(onGround){
            fallSpeed = 0.0f;
        }
    }

    void setRotation(float rot){
        enforce(unit !is null, "FPSControlAI's unit is null!!");
        unit.rotation = rot;
    }

    vec3d getUnitPos(){
        enforce(unit !is null, "FPSControlAI's unit is null!!");
        return unitPos;
    }


}
