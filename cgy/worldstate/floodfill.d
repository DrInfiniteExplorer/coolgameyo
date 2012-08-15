module worldstate.floodfill;

import pos;
import util.array;

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

        if(fillingTasks.length == 0) {
            g_Statistics.FloodFillNew(0);
        }
        foreach(task ; parallel(fillingTasks)) {
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
        foreach(task ; fillingTasks) {

            notifySectorLoad(task.sectorNum);
        }
        fillingTasks.length = 0;
        assumeSafeAppend(fillingTasks);

    }

    void pushFloodFillTasks(Scheduler scheduler) {
        synchronized (fillingTasks) {
            foreach (state; fillingTasks.list) {
                //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
                (FillingTaskState state){
                    scheduler.push(
                                   asyncTask(
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
        worldMap.fillSector(sector, heightmap);
        g_Statistics.FloodFillProgress(BlocksPerSector.total);
        notifySectorLoad(state.sectorNum);
    }

    void addFloodFillSector(SectorNum num) {
        //_floodingSectors ~= num;
        synchronized(fillingTasks) {
            fillingTasks.list ~= new FillingTaskState(num);
        }

        g_Statistics.FloodFillNew(BlocksPerSector.total);
    }
}

