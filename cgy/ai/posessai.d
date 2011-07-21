

module ai.posessai;

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

    vec3d collideMove(vec3d pos, vec3d dir, int level=0){
        if (dir == vec3d(0, 0, 0)) { return pos; }
        if (level > 5) {
            msg("Penix");
            enforce(0, "DIX!");
            return pos;
        }

        auto min = UnitPos(pos).tilePos; min.value -= vec3i(1, 1, 1);
        auto max = min; max.value += vec3i(3, 3, 4);

        bool checkCollision(vec3d pos, vec3d dir, out float minTime, out vec3d minNormal){
            bool didCollide = false;
            minTime = float.max;
            auto aabb = unit.aabb(&pos);
            foreach (rel; RangeFromTo(min.value, max.value)) {
                auto tp = TilePos(rel);
                auto tile = world.getTile(tp);
                auto tileBox = tp.getAABB();
                float time;
                vec3d normal;
                if (tile.transparent
                        || !aabb.intersectsWithBox(tileBox, dir, time, normal)) {
                    continue;
                }
                if (isNaN(time)) {
                    minTime = float.nan;
                    msg("Unit is inside of something. Solve this, like, loop upwards until not collides anylonger. or something.");
                    return true;
                }
                if (time < minTime) {
                    minTime = time;
                    minNormal = normal;
                }
                didCollide = true;
            }
            return didCollide;
        }

        float time = float.max;
        vec3d normal;


        if (!checkCollision(pos, dir, time, normal)) {
            return pos + dir;
        }
        if (isNaN(time)) {
            //enforce(0, "Implement, like move dude upwards until on top, something?");
            //return pos;
            vec3d _pos = pos + vec3d(0, 0, 1);
            vec3d _dir = vec3d(0.0, 0.0, 0.0);
            //while (!checkCollision(_pos, _dir, time, normal)) {
            //    msg("gay gay gay ", UnitPos(_pos));
            //    _pos.Z += 1;
            //}
            return _pos;
        }
        // We have collided with some box
        //IF CAN STEP STEP
        if (normal.Z == 0 && fallSpeed <= 0) { //TODO: Is now a little better, but still not good.!
            auto stepStart = pos + vec3d(0, 0, unit.stepHeight);
            float stepTime;
            auto stepDir = dir * vec3d(1, 1, 0);
            vec3d stepNormal;
            bool stepCollided = checkCollision(stepStart, dir, stepTime, stepNormal);
            if (!stepCollided) {
                return stepStart + dir;
            }
            if (stepTime < time) {
                time = stepTime;
                pos = stepStart;
                normal = stepNormal;
            }
        } else{
            onGround = true;
        }
        //ELSE Slideee!! :):):)

        // move forward first
        auto newPos = pos + dir * time;
        dir = (1-time) * dir;

        assert (normal.getLengthSQ == 1);

        auto normPart = normal.dotProduct(dir) * normal;
        auto tangPart = dir - normPart;

        assert (tangPart.getLengthSQ() < dir.getLengthSQ());

        return collideMove(newPos, tangPart, level+1);
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
