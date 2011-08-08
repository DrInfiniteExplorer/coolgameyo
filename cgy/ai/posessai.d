

module ai.posessai;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import changelist;
import unit;
import util;
import world;

class FPSControlAI : UnitAI, CustomChange {
    Unit* unit;
    UnitAI oldAi;
    //vec3d velocity;
    float fallSpeed;
    bool onGround;
    World world;
    UnitPos oldPosition;

    this(World w) {
        world = w;
    }
    
    private bool destroyed;
    ~this() {
        enforce(destroyed, "FPSControlAI.destroy not called!");        
    }
    void destroy() {
        
    }

    void setUnit(Unit* u){
        if (u is unit) {
            return;
        }
        if (unit) {
            unit.ai = oldAi;
        }
        unit = u;
        unit.ai = this;
        fallSpeed = 0.f;
        onGround=false;
        oldPosition = unit.pos;

        //TODO: Send data to clients that this unit is possessed!!!!
        // :)
    }

    vec3d collideMove(vec3d pos, vec3d dir){
        enum epsilon = 1.0E-7;
        enum OneEps = 1.0-epsilon;
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
        enum dirs = [vec3i(1, 0, 0), vec3i(0, 1, 0), vec3i(0, 0, 1)];
        
        //+2. +1 for making sure we cover some cases, then +1 again because RangeFromTo
        auto sizes = [
            vec3i(1,                to!int(floor(unitWidth)+1),    to!int(ceil(unitHeight)+1)),
            vec3i(to!int(floor(unitWidth)+1),  1,                  to!int(ceil(unitHeight)+1)),
            vec3i(to!int(floor(unitWidth)+1),  to!int(ceil(unitWidth)+1),    1)
        ];
        foreach(idx ; 0 .. 3) {
            auto axis = dirs[idx];
            auto daxis = convert!double(axis);
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
                wallNum = to!int(floor(axisPos+size+OneEps));
                axisDistanceToWall = to!double(wallNum) - (axisPos + size);
            } else {
                //'Fails' when we are [0, epsilon] from the "last" wall;
                // If so, correct the result.
                wallNum = to!int(ceil(axisPos-size-OneEps))-1;
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
                start = vec3i(0, to!int(floor(pos.Y - unitWidth * 0.5)), to!int(floor(pos.Z - 0.5)));
                stop = vec3i(1, to!int(ceil(pos.Y + unitWidth * 0.5)), to!int(ceil(pos.Z + unitHeight - 0.5)));
            } else if (idx == 1) {
                start = vec3i(to!int(floor(pos.X - unitWidth * 0.5)), 0, to!int(floor(pos.Z - 0.5)));
                stop = vec3i(to!int(ceil(pos.X + unitWidth * 0.5)), 1, to!int(ceil(pos.Z + unitHeight - 0.5)));
            } else if (idx == 2) {
                start = vec3i(to!int(floor(pos.X - unitWidth * 0.5)), to!int(floor(pos.Y - unitWidth * 0.5)), 0);
                stop = vec3i(to!int(ceil(pos.X + unitWidth * 0.5)), to!int(ceil(pos.Y + unitWidth * 0.5)), 1);
            }
            foreach( ppp ; RangeFromTo(start, stop)) {
                auto p = (axis * wallNum) + ppp;
                auto tile = world.getTile(TilePos(p), false, false);
                if (tile.type == TileTypeAir) {
                    continue;
                }
                dir[idx] = axisDistanceToWall;
                if (idx == 2) {
                    onGround = true;
                }
                writeln(p);                
                break;
            }
        }
        return pos + dir;
    }

    //Make sure that it is sent over network, and such!! (like comment below)
    void move(float right, float fwd, float up, float deltaT) {
        immutable origo = vec3d(0, 0, 0);

        onGround = false;
        fallSpeed -= 0.15f * deltaT;
        auto dir = vec3d(fwd, -right, up + fallSpeed) * deltaT;
        dir.rotateXYBy(unit.rotation, origo);
        unit.pos.value = collideMove(unit.pos.value, dir);
        if(onGround){
            fallSpeed = 0.f;
        }
    }

    void setRotation(float rot){
        enforce(unit !is null, "FPSControlAI's unit is null!!");
        unit.rotation = rot;
    }

    vec3d getUnitPos(){
        enforce(unit !is null, "FPSControlAI's unit is null!!");
        return unit.pos.value;
    }

    //This is now mostly used to make a 'real' commit of the movement.
    //Moving the unit would like, break things, kinda, otherwise, and such.
    //How/what to do when networked? Other clients will want to know where it is positioned.
    //Probably send information like "Unit X is player-controlled" to set NetworkControlledAI
    //which'll work kina like this one, i suppose.
    override int tick(ChangeList changeList){
        changeList.addCustomChange(this);
        return 0;
    }
    
    Tile[TilePos] tilesToChange;
    void changeTile(TilePos pos, Tile newTile) {
        tilesToChange[pos] = newTile;
    }        
    
    //Hax used: oldPosition, to make the world produce a delta-pos-value and load sectors
    void apply(World world) {
        auto pos = unit.pos;
        unit.pos = oldPosition;
        oldPosition = pos;
        world.unsafeMoveUnit(unit, pos.value, 1);
        
        foreach(tilePos, tile ; tilesToChange) {
            world.unsafeSetTile(tilePos, tile);
        }
        //tilesToChange.clear(); Apparently does _not_ work
        tilesToChange = null;
        
        //TODO: Make rotate of units as well? :):):)
    }

}
