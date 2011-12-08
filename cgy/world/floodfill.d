

module world.floodfill;

mixin template FloodFill() {

    void floodFillSome(int max=1000000) {// 10 lol
        //100 for 10 was plain slow and horrible!!
        //auto sw = StopWatch(AutoStart.yes);

        //int allBlocks = 0;
        //int blockCount = 0;
        //int sparseCount = 0;
        max *= 15;
        int i=0;
        while (i < max && !toFloodFill.empty) {
            i += 15;
            auto blockNum = toFloodFill.removeAny();
            g_Statistics.FloodFillProgress(1);

            auto block = getBlock(blockNum, true); //Create blocks during floodfill
            if(block.seen) { continue; }
            //allBlocks++;
            if (!block.valid) { continue; }

            //msg("\tFlooding block ", blockNum);

            //blockCount++;
            //msg("blockCount:", blockCount);
            auto blockPos = blockNum.toTilePos();

            block.seen = true;

            //scope (exit) setBlock(blockNum, block);

            if (block.sparse) {
                //sparseCount++;
                i -= 14;
                if (block.sparseTileTransparent) {
                    int cnt = 0;
                    cnt += toFloodFill.insert(BlockNum(blockNum.value + vec3i(1,0,0)));
                    cnt += toFloodFill.insert(BlockNum(blockNum.value - vec3i(1,0,0)));
                    cnt += toFloodFill.insert(BlockNum(blockNum.value + vec3i(0,1,0)));
                    cnt += toFloodFill.insert(BlockNum(blockNum.value - vec3i(0,1,0)));
                    cnt += toFloodFill.insert(BlockNum(blockNum.value + vec3i(0,0,1)));
                    cnt += toFloodFill.insert(BlockNum(blockNum.value - vec3i(0,0,1)));
                    if (cnt != 0) {
                        g_Statistics.FloodFillNew(cnt);
                    }
                }
                continue;
            }

            foreach (rel;
                     RangeFromTo (0,BlockSize.x-1,0,BlockSize.y-1,0,BlockSize.z-1)) {
                         auto tp = TilePos(blockPos.value + rel);
                         auto tile = block.getTile(tp); //Create block

                         scope (exit) block.setTile(tp, tile);

                         if (tile.isAir) {
                             tile.seen = true;
                             if (rel.X == 0) {
                                 if(toFloodFill.insert(
                                                       BlockNum(blockNum.value - vec3i(1,0,0)))) {
                                                           g_Statistics.FloodFillNew(1);
                                                       }
                             } else if (rel.X == BlockSize.x - 1) {
                                 if (toFloodFill.insert(
                                                        BlockNum(blockNum.value + vec3i(1,0,0)))) {
                                                            g_Statistics.FloodFillNew(1);
                                                        }
                             }
                             if (rel.Y == 0) {
                                 if( toFloodFill.insert(
                                                        BlockNum(blockNum.value - vec3i(0,1,0)))) {
                                                            g_Statistics.FloodFillNew(1);
                                                        }
                             } else if (rel.Y == BlockSize.y - 1) {
                                 if (toFloodFill.insert(
                                                        BlockNum(blockNum.value + vec3i(0,1,0)))) {
                                                            g_Statistics.FloodFillNew(1);
                                                        }
                             }
                             if (rel.Z == 0) {
                                 if (toFloodFill.insert(
                                                        BlockNum(blockNum.value - vec3i(0,0,1)))) {
                                                            g_Statistics.FloodFillNew(1);
                                                        }
                             } else if (rel.Z == BlockSize.z - 1) {
                                 if (toFloodFill.insert(
                                                        BlockNum(blockNum.value + vec3i(0,0,1)))) {
                                                            g_Statistics.FloodFillNew(1);
                                                        }
                             }
                         } else {
                             foreach (npos; neighbors(tp)) {
                                 auto neighbor = getTile(npos, true); //Create block if need
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
                writeln("spreadSunLight(sectorNum);");
            }
            floodingSectors.length = 0;
            //floodingSectors.assumeSafeAppend(); // yeaaaaahhhh~~~
        }
        //msg("allBlocks");
        //msg(allBlocks);
        //msg("blockCount");
        //msg(blockCount);
        //msg("sparseCount");
        //msg(sparseCount);

        //msg("Floodfill took ", sw.peek().msecs, " ms to complete");
    }

}

