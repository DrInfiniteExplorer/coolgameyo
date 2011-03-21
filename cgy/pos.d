
import util;

struct SectorNum {
    vec3i value;

    BlockPos toBlockNum() const {
        return blockPos(vec3i(
                    value.X * BlocksPerSector.X,
                    value.Y * BlocksPerSector.Y,
                    value.Z * BlocksPerSector.Z));
    }
    TilePos toTilePos() const {
        return tilePos(vec3i(
                    value.X * SectorSize.X,
                    value.Y * SectorSize.Y,
                    value.Z * SectorSize.Z));
    }
}
struct BlockNum {
    vec3i value;

    SectorPos getSectorNum() const {
        return sectorPos(vec3i(
                    negDiv(value.X, BlocksPerSector.X),
                    negDiv(value.Y, BlocksPerSector.Y),
                    negDiv(value.Z, BlocksPerSector.Z)));
    }
    TilePos toTilePos() const {
        return tilePos(vec3i(
                    value.X * BlockSize.X,
                    value.Y * BlockSize.Y,
                    value.Z * BlockSize.Z));
    }
}
struct TilePos {
    vec3i value;

    SectorPos getSectorNum() const {
        return sectorPos(vec3i(
                    negDiv(value.X, SectorSize.X),
                    negDiv(value.Y, SectorSize.Y),
                    negDiv(value.Z, SectorSize.Z)));
    }
    BlockPos getBlockNum() const {
        return tilePos(vec3i(
                    negDiv(value.X, BlockSize.X),
                    negDiv(value.Y, BlockSize.Y),
                    negDiv(value.Z, BlockSize.Z)));
    }
}

struct SectorXYNum {
    vec2i value;

    TileXYPos getTileXYPos() const {
        return TileXYPos(vec2i(
                    value.X * SectorSize.X,
                    value.Y * SectorSize.Y));
    }
}

struct TileXYPos {
    vec2i value;

    SectorXYNum getSectorXYNum() const {
        return SectorXYNum(vec2i(
                    negDiv(value.X, SectorSize.X),
                    negDiv(value.Y, SectorSize.Y)));
    }
}

SectorPos sectorPos(vec3i value) {
    return SectorPos(value);
}
BlockPos blockPos(vec3i value) {
    return BlockPos(value);
}
TilePos tilePos(vec3i value) {
    return TilePos(value);
}
