
import stolen.aabbox3d;
import util;
import worldparts.sector;
import worldparts.block;
import std.conv;


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

struct UnitPos {
    vec3d value;
    
    TilePos tilePos() @property {
        return TilePos(convert!int(value));
    }
    
    mixin ToStringMethod3D;
}

struct SectorNum {
    vec3i value;

    BlockNum toBlockNum() const {
        return blockNum(vec3i(
                    value.X * BlocksPerSector.x,
                    value.Y * BlocksPerSector.y,
                    value.Z * BlocksPerSector.z));
    }
    TilePos toTilePos() const {
        return tilePos(vec3i(
                    value.X * SectorSize.x,
                    value.Y * SectorSize.y,
                    value.Z * SectorSize.z));
    }
    aabbox3d!double getAABB(){
        auto minPos = util.convert!double(toTilePos().value);
        auto maxPos = minPos + vec3d(SectorSize.x, SectorSize.y, SectorSize.z);
        return aabbox3d!double(minPos, maxPos);
    }

    mixin ToStringMethod3D;    
}

struct BlockNum {
    vec3i value;

    SectorNum getSectorNum() const {
        return sectorNum(vec3i(
                    negDiv(value.X, BlocksPerSector.x),
                    negDiv(value.Y, BlocksPerSector.y),
                    negDiv(value.Z, BlocksPerSector.z)));
    }
    TilePos toTilePos() const {
        return tilePos(vec3i(
                    value.X * BlockSize.x,
                    value.Y * BlockSize.y,
                    value.Z * BlockSize.z));
    }

    aabbox3d!double getAABB(){
        auto minPos = util.convert!double(toTilePos().value);
        auto maxPos = minPos + vec3d(BlockSize.x, BlockSize.y, BlockSize.z);
        return aabbox3d!double(minPos, maxPos);
    }

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
    
}
struct TilePos {
    vec3i value;

    SectorNum getSectorNum() const {
        return sectorNum(vec3i(
                    negDiv(value.X, SectorSize.x),
                    negDiv(value.Y, SectorSize.y),
                    negDiv(value.Z, SectorSize.z)));
    }
    BlockNum getBlockNum() const {
        return blockNum(vec3i(
                    negDiv(value.X, BlockSize.x),
                    negDiv(value.Y, BlockSize.y),
                    negDiv(value.Z, BlockSize.z)));
    }
    
    GraphRegionNum getGraphRegionNum() const{
        return graphRegionNum(vec3i(
                    negDiv(value.X, GraphRegionSize.x),
                    negDiv(value.Y, GraphRegionSize.y),
                    negDiv(value.Z, GraphRegionSize.z),
                    ));
    }
    
    UnitPos toUnitPos() const{
        return UnitPos(vec3d(value.X + 0.5,
                             value.Y + 0.5,
                             value.Z + 0.5));
                             
    }
    
    TileXYPos toTileXYPos() const{
        return tileXYPos(vec2i(value.X, value.Y));
    }
    
    aabbox3d!double getAABB(){
        auto minPos = util.convert!double(value);
        auto maxPos = minPos + vec3d(1, 1, 1);
        return aabbox3d!double(minPos, maxPos);
    }
    
    
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

    mixin ToStringMethod3D;        
}

struct GraphRegionNum{
    vec3i value;

    TilePos max() const {
        auto ret = min();
        ret.value += vec3i(
                    GraphRegionSize.x,
                    GraphRegionSize.y,
                    GraphRegionSize.z);
        return ret;
    }
    TilePos min() const {
        return tilePos(vec3i(
                             GraphRegionSize.x * value.X,
                             GraphRegionSize.y * value.Y,
                             GraphRegionSize.z * value.Z
                             ));
    }
    aabbox3d!double getAABB() const{
        auto minPos = util.convert!double(value);
        auto maxPos = minPos + vec3d(GraphRegionSize.x,GraphRegionSize.y, GraphRegionSize.z);
        return aabbox3d!double(minPos, maxPos);
    }

    mixin ToStringMethod3D;    
}

struct SectorXYNum {
    vec2i value;

    TileXYPos getTileXYPos() const {
        return TileXYPos(vec2i(
                    value.X * SectorSize.x,
                    value.Y * SectorSize.y));
    }
    mixin ToStringMethod2D;
}

struct TileXYPos {
    vec2i value;

    SectorXYNum getSectorXYNum() const {
        return SectorXYNum(vec2i(
                    negDiv(value.X, SectorSize.x),
                    negDiv(value.Y, SectorSize.y)));
    }
    
    vec2i sectorRel() const{
        return vec2i(posMod(value.X, SectorSize.x),
                     posMod(value.Y, SectorSize.y));
    }
    mixin ToStringMethod2D;
}

SectorNum sectorNum(vec3i value) {
    return SectorNum(value);
}
SectorXYNum sectorXYNum(vec2i v) {
    return SectorXYNum(v);
}

BlockNum blockNum(vec3i value) {
    return BlockNum(value);
}
TilePos tilePos(vec3i value) {
    return TilePos(value);
}
TilePos tilePos(TileXYPos xy, int z){
    return TilePos(vec3i(xy.value.X, xy.value.Y, z));
}
GraphRegionNum graphRegionNum(vec3i v){
    return GraphRegionNum(v);
}
TileXYPos tileXYPos(vec2i v) {
    return TileXYPos(v);
}

