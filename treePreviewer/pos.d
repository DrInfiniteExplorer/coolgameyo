module pos;

pragma(msg, "> pos.d");

import std.conv;

import json;
import stolen.aabbox3d;
pragma(msg, "! pos.d");
//import world.sector;
import world.sizes;
import util.util;
import util.math;



mixin template ToStringMethod3D() {
    string toString() {
        return typeof(this).stringof ~
            " (" ~ to!string(value.X)
            ~ ", " ~ to!string(value.Y)
            ~ ", " ~ to!string(value.Z) ~ ")";
    }
}

mixin template ToStringMethod2D() {
    string toString(){
        return typeof(this).stringof ~
            " (" ~ to!string(value.X)
            ~ ", " ~ to!string(value.Y) ~ ")";
    }
}

mixin template SerializeValue() {
    Value toJSON() {
        return encode(value);
    }
    void fromJSON(Value v) {
        read(value, v);
    }
}



struct UnitPos {
    vec3d value;

    TilePos tilePos() const @property {
        return TilePos(
            getTilePos(value)
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
                    value.X * BlocksPerSector.x,
                    value.Y * BlocksPerSector.y,
                    value.Z * BlocksPerSector.z));
    }
    TilePos toTilePos() const {
        return TilePos(vec3i(
                    value.X * SectorSize.x,
                    value.Y * SectorSize.y,
                    value.Z * SectorSize.z));
    }
    aabbox3d!double getAABB(){
        auto minPos = toTilePos().value.convert!double();
        auto maxPos = minPos + vec3d(SectorSize.x, SectorSize.y, SectorSize.z);
        return aabbox3d!double(minPos, maxPos);
    }

    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct BlockNum {
    vec3i value;

    SectorNum getSectorNum() const {
        return SectorNum(vec3i(
                    negDiv(value.X, BlocksPerSector.x),
                    negDiv(value.Y, BlocksPerSector.y),
                    negDiv(value.Z, BlocksPerSector.z)));
    }
    TilePos toTilePos() const {
        return TilePos(vec3i(
                    value.X * BlockSize.x,
                    value.Y * BlockSize.y,
                    value.Z * BlockSize.z));
    }

    aabbox3d!double getAABB(){
        auto minPos = toTilePos().value.convert!double();
        auto maxPos = minPos + vec3d(BlockSize.x, BlockSize.y, BlockSize.z);
        return aabbox3d!double(minPos, maxPos);
    }

    // Relative index
    vec3i rel() const
    out(x){
        assert(0 <= x.X);
        assert(0 <= x.Y);
        assert(0 <= x.Z);
        assert(x.X < BlocksPerSector.x);
        assert(x.Y < BlocksPerSector.y);
        assert(x.Z < BlocksPerSector.z);
    }
    body{
        return vec3i(
            posMod(value.X, BlocksPerSector.x),
            posMod(value.Y, BlocksPerSector.y),
            posMod(value.Z, BlocksPerSector.z)
          );
    }

    mixin ToStringMethod3D;
    mixin SerializeValue;

}
struct TilePos {
    vec3i value;

    SectorNum getSectorNum() const {
        return SectorNum(vec3i(
                    negDiv(value.X, SectorSize.x),
                    negDiv(value.Y, SectorSize.y),
                    negDiv(value.Z, SectorSize.z)));
    }
    BlockNum getBlockNum() const {
        return BlockNum(vec3i(
                    negDiv(value.X, BlockSize.x),
                    negDiv(value.Y, BlockSize.y),
                    negDiv(value.Z, BlockSize.z)));
    }
    BlockNum[] getNeighboringBlockNums() const {
        BlockNum[] ret;
        auto thisNum = getBlockNum();
        auto rel = vec3i(
                         posMod(value.X, BlockSize.x),
                         posMod(value.Y, BlockSize.y),
                         posMod(value.Z, BlockSize.z),
                         );
        if (rel.X == 0) {
            auto tmp = thisNum; tmp.value.X -= 1; ret ~= tmp;
        }
        else if (rel.X == BlockSize.x-1) {
            auto tmp = thisNum; tmp.value.X += 1; ret ~= tmp;
        }
        if (rel.Y == 0) {
            auto tmp = thisNum; tmp.value.Y -= 1; ret ~= tmp;
        }
        else if (rel.Y == BlockSize.y-1) {
            auto tmp = thisNum; tmp.value.Y += 1; ret ~= tmp;
        }
        if (rel.Z == 0) {
            auto tmp = thisNum; tmp.value.Z -= 1; ret ~= tmp;
        }
        else if (rel.Z == BlockSize.z-1) {
            auto tmp = thisNum; tmp.value.Z += 1; ret ~= tmp;
        }
        return ret;
    }

    GraphRegionNum getGraphRegionNum() const{
        return GraphRegionNum(vec3i(
                    negDiv(value.X, GraphRegionSize.x),
                    negDiv(value.Y, GraphRegionSize.y),
                    negDiv(value.Z, GraphRegionSize.z),
                    ));
    }
    GraphRegionNum[] getNeighboringGraphRegionNums() const {
        GraphRegionNum[] ret;
        auto thisNum = getGraphRegionNum();
        auto rel = vec3i(
                    posMod(value.X, GraphRegionSize.x),
                    posMod(value.Y, GraphRegionSize.y),
                    posMod(value.Z, GraphRegionSize.z),
                    );
        if (rel.X == 0) {
            auto tmp = thisNum; tmp.value.X -= 1; ret ~= tmp;
        }
        else if (rel.X == GraphRegionSize.x-1) {
            auto tmp = thisNum; tmp.value.X += 1; ret ~= tmp;
        }
        if (rel.Y == 0) {
            auto tmp = thisNum; tmp.value.Y -= 1; ret ~= tmp;
        }
        else if (rel.Y == GraphRegionSize.y-1) {
            auto tmp = thisNum; tmp.value.Y += 1; ret ~= tmp;
        }
        if (rel.Z == 0) {
            auto tmp = thisNum; tmp.value.Z -= 1; ret ~= tmp;
        }
        else if (rel.Z == GraphRegionSize.z-1) {
            auto tmp = thisNum; tmp.value.Z += 1; ret ~= tmp;
        }
        return ret;
    }

    UnitPos toUnitPos() const{
        return UnitPos(vec3d(value.X + 0.5,
                             value.Y + 0.5,
                             value.Z + 0.5));
    }
    
    EntityPos toEntityPos() const{
        return EntityPos(vec3d(value.X + 0.5,
                             value.Y + 0.5,
                             value.Z + 0.5));
    }

    TileXYPos toTileXYPos() const{
        return TileXYPos(vec2i(value.X, value.Y));
    }

    aabbox3d!double getAABB(){
        auto minPos = value.convert!double();
        auto maxPos = minPos + vec3d(1.0, 1.0, 1.0);
        return aabbox3d!double(minPos, maxPos);
    }


    // Relative index
    vec3i rel() const
    out(x){
        assert(x.X >= 0, "rel.X < 0!!! :(");
        assert(x.Y >= 0, "rel.Y < 0!!! :(");
        assert(x.Z >= 0, "rel.Z < 0!!! :(");
        assert(x.X < TilesPerBlock.x, "rel.X > TilesPerBlock.x!!! :(");
        assert(x.Y < TilesPerBlock.y, "rel.Y > TilesPerBlock.y!!! :(");
        assert(x.Z < TilesPerBlock.z, "rel.Z > TilesPerBlock.z!!! :(");
    }
    body{
        return vec3i(
            posMod(value.X, TilesPerBlock.x),
            posMod(value.Y, TilesPerBlock.y),
            posMod(value.Z, TilesPerBlock.z)
            );
    }

    vec3i sectorRel() const
    out(x){
        assert(x.X >= 0, "rel.X < 0!!! :(");
        assert(x.Y >= 0, "rel.Y < 0!!! :(");
        assert(x.Z >= 0, "rel.Z < 0!!! :(");
        assert(x.X < SectorSize.x, "rel.X > SectorSize.x!!! :(");
        assert(x.Y < SectorSize.y, "rel.Y > SectorSize.y!!! :(");
        assert(x.Z < SectorSize.z, "rel.Z > SectorSize.z!!! :(");
    }
    body{
        return vec3i(
            posMod(value.X, SectorSize.x),
            posMod(value.Y, SectorSize.y),
            posMod(value.Z, SectorSize.z)
            );
    }
    
    mixin ToStringMethod3D;
    mixin SerializeValue;
}

struct GraphRegionNum{
    vec3i value;

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
                             GraphRegionSize.x * value.X,
                             GraphRegionSize.y * value.Y,
                             GraphRegionSize.z * value.Z
                             ));
    }
    alias min toTilePos;
    aabbox3d!double getAABB() const {
        auto minPos = min().value.convert!double();
        auto maxPos = max().value.convert!double();
        return aabbox3d!double(minPos, maxPos);
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
        value.set(num.value.X, num.value.Y);
    }

    TileXYPos getTileXYPos() const {
        return TileXYPos(vec2i(
                    value.X * SectorSize.x,
                    value.Y * SectorSize.y));
    }
    mixin ToStringMethod2D;
}

struct TileXYPos {
    vec2i value;

    this(vec2i pos) {
        value = pos;
    }
    this(TilePos pos) {
        value.set(pos.value.X, pos.value.Y);
    }

    SectorXYNum getSectorXYNum() const {
        return SectorXYNum(vec2i(
                    negDiv(value.X, SectorSize.x),
                    negDiv(value.Y, SectorSize.y)));
    }

    vec2i sectorRel() const{
        return vec2i(posMod(value.X, SectorSize.x),
                     posMod(value.Y, SectorSize.y));
    }
    TilePos toTilePos(int z) const {
        return TilePos(vec3i(value.X, value.Y, z));
    }
    mixin ToStringMethod2D;
    mixin SerializeValue;
}

pragma(msg, "< pos.d");
