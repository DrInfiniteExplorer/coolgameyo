module world.floodfill;

import util.array;

mixin template FloodFill() {
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

        return block.sparse ? 1 : 45;
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

