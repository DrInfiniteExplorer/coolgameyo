
import util;
import world : BlockSize, BlocksPerSector, SectorSize , GraphRegionSize;

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
    vec3i rel() const {
        return vec3i(
            posMod(value.X, SectorSize.x),
            posMod(value.Y, SectorSize.y),
            posMod(value.Z, SectorSize.z)
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
    
    vec3i rel() const {
        return vec3i(
            posMod(value.X, BlockSize.x),
            posMod(value.Y, BlockSize.y),
            posMod(value.Z, BlockSize.z)
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

TileXYPos tileXYPos(vec2i v) {
    return TileXYPos(v);
}
