module cgy.util.pos;


import std.conv;

import cgy.json;
//import cgy.stolen.aabbox3d;

import cgy.math.math : negDiv, posMod;
import cgy.math.aabb : aabb3d;
import cgy.math.vector;

//import worldstate.sector;
import cgy.util.sizes;
//import cgy.util.util;
import cgy.debug_.debug_ : BREAK_IF;



mixin template ToStringMethod3D() {
    string toString() {
        return typeof(this).stringof ~
            " (" ~ to!string(value.x)
            ~ ", " ~ to!string(value.y)
            ~ ", " ~ to!string(value.z) ~ ")";
    }
}

mixin template ToStringMethod2D() {
    string toString(){
        return typeof(this).stringof ~
            " (" ~ to!string(value.x)
            ~ ", " ~ to!string(value.y) ~ ")";
    }
}

mixin template SerializeValue() {
    Value toJSON() {
        return encode(value);
    }
    void fromJSON(Value v) {
        v.read(value);
    }
}

// We no longer handle tileposes etc below 0
// So a simple cast to int will suffice
vec3i getTilePos(T)(vector3!T v){
    return vec3i( cast(int)v.x, cast(int)v.y, cast(int)v.z);
}


struct UnitPos {
    vec3d value;

    TilePos tilePos() const @property {
        return TilePos(
            getTilePos(value.convert!int)
        );
    }
    alias tilePos this;

    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct EntityPos {
    vec3d value;
    // ToDo: fix so that the hoalls reada pao the side of the tile.
    
    TilePos    tilePos() const @property {
        return TilePos(
            getTilePos(value)
        );
    }
    alias tilePos this;

    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct SectorNum {
    vec3i value;

    BlockNum toBlockNum() const {
        return BlockNum(vec3i(
                    value.x * BlocksPerSector.x,
                    value.y * BlocksPerSector.y,
                    value.z * BlocksPerSector.z));
    }
    TilePos toTilePos() const {
        return TilePos(vec3i(
                    value.x * SectorSize.x,
                    value.y * SectorSize.y,
                    value.z * SectorSize.z));
    }

    TileXYPos toTileXYPos() const{
        return TileXYPos(vec2i(
                             value.x * SectorSize.x,
                             value.y * SectorSize.y));
    }
    aabb3d getAABB(){
        auto minPos = toTilePos().value.convert!double();
        auto maxPos = minPos + vec3d(SectorSize.x, SectorSize.y, SectorSize.z);
        return aabb3d(minPos, maxPos);
    }

    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct BlockNum {
    vec3i value = vec3i(0,0,0);

    invariant() {
        BREAK_IF(value.x < 0 || value.y < 0);
    }

    SectorNum getSectorNum() const {
        return SectorNum(vec3i(
                    negDiv(value.x, BlocksPerSector.x),
                    negDiv(value.y, BlocksPerSector.y),
                    negDiv(value.z, BlocksPerSector.z)));
    }
    TilePos toTilePos() const {
        return TilePos(vec3i(
                    value.x * BlockSize.x,
                    value.y * BlockSize.y,
                    value.z * BlockSize.z));
    }

    aabb3d getAABB(){
        auto minPos = toTilePos().value.convert!double();
        auto maxPos = minPos + vec3d(BlockSize.x, BlockSize.y, BlockSize.z);
        return aabb3d(minPos, maxPos);
    }

    // Relative index
    vec3i rel() const
    out(x){
        assert(0 <= x.x);
        assert(0 <= x.y);
        assert(0 <= x.z);
        assert(x.x < BlocksPerSector.x);
        assert(x.y < BlocksPerSector.y);
        assert(x.z < BlocksPerSector.z);
    }
    body{
        return vec3i(
            posMod(value.x, BlocksPerSector.x),
            posMod(value.y, BlocksPerSector.y),
            posMod(value.z, BlocksPerSector.z)
          );
    }

    mixin ToStringMethod3D;
    mixin SerializeValue;

}
struct TilePos {
    vec3i value;

    SectorNum getSectorNum() const {
        return SectorNum(vec3i(
                    negDiv(value.x, SectorSize.x),
                    negDiv(value.y, SectorSize.y),
                    negDiv(value.z, SectorSize.z)));
    }
    BlockNum getBlockNum() const {
        return BlockNum(vec3i(
                    negDiv(value.x, BlockSize.x),
                    negDiv(value.y, BlockSize.y),
                    negDiv(value.z, BlockSize.z)));
    }
    BlockNum[] getNeighboringBlockNums() const {
        BlockNum[] ret;
        auto thisNum = getBlockNum();
        auto rel = vec3i(
                         posMod(value.x, BlockSize.x),
                         posMod(value.y, BlockSize.y),
                         posMod(value.z, BlockSize.z),
                         );
        if (rel.x == 0) {
            auto tmp = thisNum; tmp.value.x -= 1; ret ~= tmp;
        }
        else if (rel.x == BlockSize.x-1) {
            auto tmp = thisNum; tmp.value.x += 1; ret ~= tmp;
        }
        if (rel.y == 0) {
            auto tmp = thisNum; tmp.value.y -= 1; ret ~= tmp;
        }
        else if (rel.y == BlockSize.y-1) {
            auto tmp = thisNum; tmp.value.y += 1; ret ~= tmp;
        }
        if (rel.z == 0) {
            auto tmp = thisNum; tmp.value.z -= 1; ret ~= tmp;
        }
        else if (rel.z == BlockSize.z-1) {
            auto tmp = thisNum; tmp.value.z += 1; ret ~= tmp;
        }
        return ret;
    }

    GraphRegionNum getGraphRegionNum() const{
        return GraphRegionNum(vec3i(
                    negDiv(value.x, GraphRegionSize.x),
                    negDiv(value.y, GraphRegionSize.y),
                    negDiv(value.z, GraphRegionSize.z),
                    ));
    }
    GraphRegionNum[] getNeighboringGraphRegionNums() const {
        GraphRegionNum[] ret;
        auto thisNum = getGraphRegionNum();
        auto rel = vec3i(
                    posMod(value.x, GraphRegionSize.x),
                    posMod(value.y, GraphRegionSize.y),
                    posMod(value.z, GraphRegionSize.z),
                    );
        if (rel.x == 0) {
            auto tmp = thisNum; tmp.value.x -= 1; ret ~= tmp;
        }
        else if (rel.x == GraphRegionSize.x-1) {
            auto tmp = thisNum; tmp.value.x += 1; ret ~= tmp;
        }
        if (rel.y == 0) {
            auto tmp = thisNum; tmp.value.y -= 1; ret ~= tmp;
        }
        else if (rel.y == GraphRegionSize.y-1) {
            auto tmp = thisNum; tmp.value.y += 1; ret ~= tmp;
        }
        if (rel.z == 0) {
            auto tmp = thisNum; tmp.value.z -= 1; ret ~= tmp;
        }
        else if (rel.z == GraphRegionSize.z-1) {
            auto tmp = thisNum; tmp.value.z += 1; ret ~= tmp;
        }
        return ret;
    }

    UnitPos toUnitPos() const{
        return UnitPos(vec3d(value.x + 0.5,
                             value.y + 0.5,
                             value.z + 0.5));
    }
    
    EntityPos toEntityPos() const{
        return EntityPos(vec3d(value.x + 0.5,
                             value.y + 0.5,
                             value.z + 0.5));
    }

    TileXYPos toTileXYPos() const{
        return TileXYPos(vec2i(value.x, value.y));
    }

    aabb3d getAABB(){
        auto minPos = value.convert!double();
        auto maxPos = minPos + vec3d(1.0, 1.0, 1.0);
        return aabb3d(minPos, maxPos);
    }


    // Relative index
    vec3i rel() const
    out(x){
        assert(x.x >= 0, "rel.x < 0!!! :(");
        assert(x.y >= 0, "rel.y < 0!!! :(");
        assert(x.z >= 0, "rel.z < 0!!! :(");
        assert(x.x < TilesPerBlock.x, "rel.x > TilesPerBlock.x!!! :(");
        assert(x.y < TilesPerBlock.y, "rel.y > TilesPerBlock.y!!! :(");
        assert(x.z < TilesPerBlock.z, "rel.z > TilesPerBlock.z!!! :(");
    }
    body{
        return vec3i(
            posMod(value.x, TilesPerBlock.x),
            posMod(value.y, TilesPerBlock.y),
            posMod(value.z, TilesPerBlock.z)
            );
    }

    vec3i sectorRel() const
    out(x){
        assert(x.x >= 0, "rel.x < 0!!! :(");
        assert(x.y >= 0, "rel.y < 0!!! :(");
        assert(x.z >= 0, "rel.z < 0!!! :(");
        assert(x.x < SectorSize.x, "rel.x > SectorSize.x!!! :(");
        assert(x.y < SectorSize.y, "rel.y > SectorSize.y!!! :(");
        assert(x.z < SectorSize.z, "rel.z > SectorSize.z!!! :(");
    }
    body{
        return vec3i(
            posMod(value.x, SectorSize.x),
            posMod(value.y, SectorSize.y),
            posMod(value.z, SectorSize.z)
            );
    }
    
    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct GraphRegionNum{
    vec3i value;

    SectorNum getSectorNum() const {
        immutable divX = SectorSize.x / GraphRegionSize.x;
        immutable divY = SectorSize.y / GraphRegionSize.y;
        immutable divZ = SectorSize.z / GraphRegionSize.z;
        return SectorNum(vec3i(
                           negDiv(value.x, divX),
                           negDiv(value.y, divY),
                           negDiv(value.z, divZ)));
    }

    TilePos max() const {
        auto ret = min();
        ret.value += vec3i(
                    GraphRegionSize.x-1,
                    GraphRegionSize.y-1,
                    GraphRegionSize.z-1);
        return ret;
    }
    TilePos min() const {
        return TilePos(vec3i(
                             GraphRegionSize.x * value.x,
                             GraphRegionSize.y * value.y,
                             GraphRegionSize.z * value.z
                             ));
    }
    alias min toTilePos;
    aabb3d getAABB() const {
        auto minPos = min().value.convert!double();
        auto maxPos = max().value.convert!double();
        return aabb3d(minPos, maxPos);
    }

    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct SectorXYNum {
    vec2i value;

    this(vec2i v) {
        value = v;
    }
    this(SectorNum num) {
        value.set(num.value.x, num.value.y);
    }

    SectorNum getSectorNum(int z) const {
        return SectorNum(vec3i( value.x, value.y, z));
    }

    TileXYPos getTileXYPos() const {
        return TileXYPos(vec2i(
                    value.x * SectorSize.x,
                    value.y * SectorSize.y));
    }

    bool inside(TileXYPos tp) {
        auto val = tp.value;
        auto me = getTileXYPos().value;
        return
            (val.x >= me.x) &&
            (val.x < me.x + SectorSize.x) &&
            (val.y >= me.y) &&
            (val.y < me.y + SectorSize.y);
    }

    mixin ToStringMethod2D;
}

struct TileXYPos {
    vec2i value;

    this(vec2i pos) {
        value = pos;
    }
    this(TilePos pos) {
        value.set(pos.value.x, pos.value.y);
    }

    SectorXYNum getSectorXYNum() const {
        return SectorXYNum(vec2i(
                    negDiv(value.x, SectorSize.x),
                    negDiv(value.y, SectorSize.y)));
    }

    vec2i sectorRel() const{
        return vec2i(posMod(value.x, SectorSize.x),
                     posMod(value.y, SectorSize.y));
    }
    TilePos toTilePos(int z) const {
        return TilePos(vec3i(value.x, value.y, z));
    }
    mixin ToStringMethod2D;
    mixin SerializeValue;
}


