module world.floodfill;

import util.array;

mixin template FloodFill2() {
    SectorNum[] floodingSectors;
    size_t current;
    RangeFromTo r;

    private void reset_r() {
        r = RangeFromTo(
                0, BlocksPerSector.x - 1,
                0, BlocksPerSector.y - 1,
                0, BlocksPerSector.z - 1);
    }
    void initFloodfill() {
        reset_r();
    }
    void serializeFloodfill(Value v) {
        v["toFlood"] = encode(floodingSectors[]);
        v["floodcur"] = encode(current);
        v["floodr"] = encode(r);
    }
    void deserializeFloodfill(Value v) {
        json.read(floodingSectors, v["toFlood"]);
        json.read(current, v["floodcur"]);
        json.read(r, v["floodr"]);
    }

    void floodFillSome(int max=100) {
        int i = 0;
        while (i < max && current < floodingSectors.length) {
            i += fillOneBlock();
        }
    }
    private int fillOneBlock() {
        assert (!r.empty);

        scope (success) {
            r.popFront();
            if (r.empty) {
                reset_r();
                notifySectorLoad(floodingSectors[current]);

                current += 1;
                if (current >= floodingSectors.length) {
                    floodingSectors.length = 0;
                    floodingSectors.assumeSafeAppend();
                    current = 0;
                    g_Statistics.FloodFillNew(0);
                }
            }
        }

        auto abs = floodingSectors[current].toBlockNum();
        abs.value += r.front;

        auto block = getBlock(abs, true);
        assert (block.valid);

        g_Statistics.FloodFillProgress(1);

        if (block.seen) { return 1; }

        bool anything_seen = false;

        scope (exit) {
            if (anything_seen) {
                block.seen = true;
            }
        }

        if (block.sparse) {
            anything_seen = true;
            return 1;
        }

        foreach (rel; RangeFromTo(
                    0, BlockSize.x - 1,
                    0, BlockSize.y - 1,
                    0, BlockSize.z - 1)) {
            auto tp = TilePos(abs.toTilePos().value + rel);
            auto tile = block.getTile(tp);
            scope (exit) {
                if (tile.seen) {
                    block.setTile(tp, tile);
                }
            }
            //if (tile.isAir) {
                tile.seen = true;
                anything_seen = true;
            //} else {
            //    foreach (npos; neighbors(tp)) {
            //        auto neighbor = getTile(npos, true);
            //        if (neighbor.valid && neighbor.isAir) {
            //            tile.seen = true;
            //            anything_seen = true;
            //            break;
            //        }
            //    }
            //}
        }
        return 45;
    }
    void addFloodFillPos(TilePos pos) {
        floodingSectors ~= pos.getSectorNum();
        g_Statistics.FloodFillNew(BlocksPerSector.total);
    }
    void addFloodFillWall(SectorNum inactive, SectorNum active) {
        floodingSectors ~= inactive;
        g_Statistics.FloodFillNew(BlocksPerSector.total);
    }
}

mixin template FloodFill() {

    // redblacktree on plols computer: 25783
    //private alias RedBlackTree!(BlockNum, q{a.value < b.value}) WorkSet;

    // array on plols computer: 25670
    // clearly prettiest loading screen with this
    private alias util.array.Array!BlockNum WorkSet;

    WorkSet toFloodFill;
    SectorNum[] floodingSectors;

    void initFloodfill() {
        toFloodFill = new WorkSet;
        heightmapTasks = new HeightmapTasks;
    }

    void serializeFloodfill(Value v) {
        v["toFlood"] = encode(toFloodFill[]);
        v["floodSect"] = encode(floodingSectors);
    }
    void deserializeFloodfill(Value v) {
        toFloodFill = new WorkSet;
        json.read(toFloodFill, v["toFlood"]);
        json.read(floodingSectors, v["floodSect"]);
    }


    void floodFillSome(int max=100) {
        max *= 30;
        int i = 0;
        while (i < max && !toFloodFill.empty) {
            auto blockNum = toFloodFill.removeAny();
            g_Statistics.FloodFillProgress(1);

            auto block = getBlock(blockNum, true);

            i += 1;
            if (block.seen) { continue; }
            if (!block.valid) { continue; }
            i += 1;

            auto blockPos = blockNum.toTilePos();

            block.seen = true;

            if (block.sparse) {
                if (block.sparseTileTransparent) {
                    foreach (neighbor; neighbors(blockNum)) {
                        toFloodFill.insert(neighbor);
                    }
                    g_Statistics.FloodFillNew(6);
                }
                continue;
            }
            
            i += 28;

            foreach (rel; RangeFromTo(
                        0, BlockSize.x - 1,
                        0, BlockSize.y - 1,
                        0, BlockSize.z - 1)) {
                auto tp = TilePos(blockPos.value + rel);
                auto tile = block.getTile(tp);

                scope (exit) block.setTile(tp, tile);

                if (tile.isAir) {
                    tile.seen = true;
                    if (rel.X == 0) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    - vec3i(1,0,0)));
                        g_Statistics.FloodFillNew(1);
                    } else if (rel.X == BlockSize.x - 1) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    + vec3i(1,0,0)));
                        g_Statistics.FloodFillNew(1);
                    }
                    if (rel.Y == 0) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    - vec3i(0,1,0)));
                        g_Statistics.FloodFillNew(1);
                    } else if (rel.Y == BlockSize.y - 1) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    + vec3i(0,1,0)));
                        g_Statistics.FloodFillNew(1);
                    }
                    if (rel.Z == 0) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    - vec3i(0,0,1)));
                        g_Statistics.FloodFillNew(1);
                    } else if (rel.Z == BlockSize.z - 1) {
                        toFloodFill.insert(BlockNum(blockNum.value
                                    + vec3i(0,0,1)));
                        g_Statistics.FloodFillNew(1);
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
    void addFloodFillPos(TilePos pos) {
        toFloodFill.insert(pos.getBlockNum());
        g_Statistics.FloodFillNew(1);
        //Also clear seen-flag from neighbors.
        //Dont add them to floodfill; If we're unlucky we'll process these blocks
        //before the one which pos belongs to; and as such, if pos is a new air
        //tile, the air-visibility wont propagate to this tile.
        //Nevermind 3 lines above, solid tiles check for any nearby airtiles; they need not be seen themselves.... >.<
        foreach(num ; pos.getNeighboringBlockNums()) {
            auto block = getBlock(num, true); //Create block if not exist
            block.seen = false;
        }

    }
    void addFloodFillWall(SectorNum inactive, SectorNum active) {
        foreach (inact, act; getWallBetween(inactive, active)) {
            auto block = getBlock(act, false); //Dont create blocks when expanding floodfill
            if(!block.valid) continue; //Skip invalid blocks; They cant be seen anyway.
            if (block.seen) {
                block.seen = false;
                toFloodFill.insert(inact);
                g_Statistics.FloodFillNew(1);
            }
        }
    }
}

