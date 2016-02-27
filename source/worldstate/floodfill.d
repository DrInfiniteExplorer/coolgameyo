module worldstate.floodfill;


import cgy.util.pos;
import cgy.util.array;

static final class FillingTaskState {
    SectorNum sectorNum;
    this(SectorNum p) {
        sectorNum = p;
    }            
}

mixin template FloodFill() {

    static final class FillingTasks {
        FillingTaskState[] list;
        alias list this;
    };
    FillingTasks fillingTasks;

    SectorNum[] _floodingSectors;
    size_t current;
    RangeFromTo r;

    ulong startTime;
    ulong startTimeCPU;

    private void reset_r() {
        r = RangeFromTo(
                0, BlocksPerSector.x - 1,
                0, BlocksPerSector.y - 1,
                0, BlocksPerSector.z - 1);
    }
    void initFloodfill() {
        fillingTasks = new FillingTasks;
        reset_r();
    }
    void serializeFloodfill(Value v) {
        v.populateJSONObject("toFlood", _floodingSectors,
                             "floodcur", current,
                             "floodr", r);
    }
    void deserializeFloodfill(Value v) {
        v.readJSONObject("toFlood", &_floodingSectors,
                         "floodcur", &current,
                         "floodr", &r);
    }


    void initialFloodFill() {

        auto startPageFaults = getMemoryPageFaults();
        auto startMemory = getMemoryUsage();
        if(fillingTasks.length == 0) {
            g_Statistics.FloodFillNew(0);
        }

        auto range = fillingTasks.list;
        foreach(task ; parallel(range)) {
            workerID = taskPool.workerIndex;
        //foreach(task ; fillingTasks) {
                fillingTaskFunc(task);
            /*
            auto abs = sectorNum.toBlockNum().value;
            foreach(rel ; RangeFromTo( 0, BlocksPerSector.x - 1, 0, BlocksPerSector.y - 1, 0, BlocksPerSector.z - 1)) {
                auto blockNum = BlockNum(abs + rel);
                auto block = getBlock(blockNum, true);
                g_Statistics.FloodFillProgress(1);
            }
            */
        }
        taskPool().finish();

        /*
        foreach(task ; fillingTasks) {
            //Are apparently notified in the fillingTaskFunc
            notifySectorLoad(task.sectorNum);
        }
        */
        fillingTasks.length = 0;
        assumeSafeAppend(fillingTasks);
        msg("Page fault count in initialFloodFill: ", getMemoryPageFaults() - startPageFaults);
        msg("Memory increase in initialFloodFill: ", getMemoryUsage() - startMemory);

    }

    void pushFloodFillTasks() {
        synchronized (fillingTasks) {
            foreach (state; fillingTasks.list) {
                //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
                (FillingTaskState state){
                    scheduler.push(
                                   task(
                                             (WorldProxy world){
                                                 fillingTaskFunc(state);
                                             }));
                }(state);

            }
        }
        fillingTasks.length = 0;
    }

    void fillingTaskFunc(FillingTaskState state) {
        mixin(MeasureTime!"fillingTaskFunc: ");
        SectorXY* xy;
        auto sectorNum = state.sectorNum;
        auto sector = getSector(sectorNum, &xy);
        auto heightmap = xy.heightmap;
        if(heightmap is null) {
            addFloodFillSector(state.sectorNum);
            return;
        }
        msg("Will fill sector ", sectorNum.value);
        worldMap.fillSector(sector, heightmap);
        g_Statistics.FloodFillProgress(BlocksPerSector.total);
        notifySectorLoad(state.sectorNum);
        if(startTime > 0) {
            msg("Possible end time: ", (mstime() - startTime) / 1000.0f, "\t", (getCpuTimeMs() - startTimeCPU) / 1000.0f);
            import globals;
            msg("avg layer index: ", cast(double)g_derp1 / cast(double)g_derp2);

        }

    }

    void addFloodFillSector(SectorNum num) {
        if(fillingTasks.list.length == 0) {
            startTime = mstime();
            startTimeCPU = getCpuTimeMs();
        }
        //_floodingSectors ~= num;
        BREAK_IF(num.value.getLengthSQ() == 0);
        msg("Adding sector to filling queueue: ", num.value);
        synchronized(fillingTasks) {
            fillingTasks.list ~= new FillingTaskState(num);
        }

        g_Statistics.FloodFillNew(BlocksPerSector.total);
    }
}

