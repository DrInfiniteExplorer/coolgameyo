
import engine.irrlicht;

import util;
import world : TilesPerBlock, BlockSize, BlocksPerSector, SectorSize , GraphRegionSize;

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
    aabbox3d!double getAABB(){
        auto minPos = util.convert!double(value);
        auto maxPos = minPos + vec3d(1, 1, 1);
        return aabbox3d!double(minPos, maxPos);
    }
    
    
    vec3i rel() const {
        return vec3i(
            posMod(value.X, TilesPerBlock.x),
            posMod(value.Y, TilesPerBlock.y),
            posMod(value.Z, TilesPerBlock.z)
            );
    }
}

struct SectorXYNum {
    vec2i value;

    TileXYPos getTileXYPos() const {
        return TileXYPos(vec2i(
                    value.X * SectorSize.x,
                    value.Y * SectorSize.y));
    }
}

struct TileXYPos {
    vec2i value;

    SectorXYNum getSectorXYNum() const {
        return SectorXYNum(vec2i(
                    negDiv(value.X, SectorSize.x),
                    negDiv(value.Y, SectorSize.y)));
    }
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
TileXYPos tileXYPos(vec2i v) {
    return TileXYPos(v);
}

