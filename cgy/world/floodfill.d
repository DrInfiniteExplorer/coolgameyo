module world.floodfill;

import util.array;

mixin template FloodFill() {

    // redblacktree on plols computer: 25783
    //private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;

    // array on plols computer: 25670
    // clearly prettiest loading screen with this
    private alias util.array.Array!BlockNum WorkSet;

    WorkSet toFloodFill;
    SectorNum[] floodingSectors;

    void floodFillSome(int max=100) {
        max *= 15;
        int i = 0;
        while (i < max && !toFloodFill.empty) {
            auto blockNum = toFloodFill.removeAny();
            g_Statistics.FloodFillProgress(1);

            auto block = getBlock(blockNum, true);

            i += 1;
            if (block.seen) { continue; }
            if (!block.valid) { continue; }
            i += 14;

            auto blockPos = blockNum.toTilePos();

            block.seen = true;

            if (block.sparse) {
                i -= 14;
                if (block.sparseTileTransparent) {
                    foreach (neighbor; neighbors(blockNum)) {
                        toFloodFill.insert(neighbor);
                    }
                    g_Statistics.FloodFillNew(6);
                }
                continue;
            }

            foreach (rel; RangeFromTo(
                        0, BlockSize.x - 1,
                        0, BlockSize.y - 1,
                        0, BlockSize.z - 1)) {
                auto tp = TilePos(blockPos.value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.isAir) {
                    tile.seen = true;
                    g_Statistics.FloodFillNew(1);
                    if (rel.X == 0) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    - vec3i(1,0,0)));
                    } else if (rel.X == BlockSize.x - 1) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    + vec3i(1,0,0)));
                    }
                    if (rel.Y == 0) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    - vec3i(0,1,0)));
                    } else if (rel.Y == BlockSize.y - 1) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    + vec3i(0,1,0)));
                    }
                    if (rel.Z == 0) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    - vec3i(0,0,1)));
                    } else if (rel.Z == BlockSize.z - 1) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    + vec3i(0,0,1)));
                    }
                } else {
                    foreach (npos; neighbors(tp)) {
                        auto neighbor = getTile(npos, true);
                        if (neighbor.valid && neighbor.isAir) {
                            tile.seen = true;
                            break;
                        }
                    }
                }
            }
        }
        if (toFloodFill.empty) {
            g_Statistics.FloodFillNew(0);
            foreach (sectorNum; floodingSectors) {
                notifySectorLoad(sectorNum);
            }
            floodingSectors = null;
        }
    }
}

