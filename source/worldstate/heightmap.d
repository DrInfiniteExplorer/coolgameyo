module worldstate.heightmap;

import std.algorithm;

import cgy.util.rangefromto;

import cgy.util.pos;
import cgy.util.sizes;


final class SectorHeightmap {
    int[SectorSize.x][SectorSize.y] heightmap;

    void opIndexAssign(int val, size_t x, size_t y) {
        heightmap[y][x] = val;
    }
    ref int opIndex(size_t x, size_t y) {
        return heightmap[y][x];
    }
    this() {};

    int[BlocksPerSector.x][BlocksPerSector.y] getMaxPerBlock() {
        typeof(return) ret;
        //This always feels like magic. D should have a property of multidimensional static-sized arrays to
        // cast them into a single-dimensional array for operations like this.
        (cast(int*)ret.ptr)[0.. BlocksPerSector.y * BlocksPerSector.x] = int.min;
        foreach(int x, int y ; Range2D(0, SectorSize.x, 0, SectorSize.y)) {
            int* v = &ret[y/BlockSize.y][x/BlockSize.x];
            *v = max(*v, heightmap[y][x]);
        }
        return ret;
    }
}

static final class HeightmapTaskState {
    SectorXYNum pos;
    SectorHeightmap heightmap;
    int x, y, z;
    this(SectorXYNum p) {
        pos = p;
        heightmap = new SectorHeightmap;
        x = 0;
        y = 0;
        z = int.max;
    }            
}


mixin template Heightmap() {

    //Someday in the future, version'ize this and make automatic performance testing scripts where we
    // measure performance with and without this feature compiled to do anything.
    enum compileHeightmaps = true;
    enum parallelHeightmaps = true;


    static final class HeightmapTasks {
        HeightmapTaskState[] list;
    };
    HeightmapTasks heightmapTasks;

    void initHeightmap() {
        static if(compileHeightmaps) {
            heightmapTasks = new HeightmapTasks;
        }
    }

    void generateAllHeightmaps() {
        static if(compileHeightmaps) {
            static if(parallelHeightmaps) {
                //synchronized(heightmapTasks)
                { // How could it not be? :)
                    auto tasks = heightmapTasks;
                    heightmapTasks = null;
                    auto range = tasks.list;
                    foreach(task ; parallel(range)) {
                        workerID = taskPool.workerIndex;
                        mixin(MeasureTime!"heightmap ");
                        //scope(exit) msg(task.pos);
                        generateHeightmapTaskFunc!(int.max)(task);
                    }
                    taskPool().finish();
                    tasks.list.length = 0;
                    assumeSafeAppend(tasks.list);
                    heightmapTasks = tasks;
                    g_Statistics.HeightmapsNew(0);
                }
            } else { //Not parallel heightmaps
                synchronized(heightmapTasks) {
                    while (!heightmapTasks.list.empty) {
                        generateHeightmapTaskFunc(heightmapTasks.list[0]);
                    }
                }
            }
        }
    }

    void addHeightmapTask(SectorXYNum xy) {
        static if(compileHeightmaps) {
            synchronized(heightmapTasks) {
                heightmapTasks.list ~= new HeightmapTaskState(xy);
                g_Statistics.HeightmapsNew(SectorSize.x * SectorSize.y);
            }
        }
    }

    void generateHeightmapTaskFunc(int iterationLimit = 1000_000)(HeightmapTaskState state) {
        static if(compileHeightmaps) {
            auto xy = state.pos;
            auto p = xy.getTileXYPos();
            int iterations = 0;
            int done = 0;
            int yStart = state.y;
            int yEnd = SectorSize.y;
            foreach (y ; yStart .. yEnd) {
                int xStart= state.x;
                int xEnd =SectorSize.x;
                foreach (x ; xStart .. xEnd) {
                    
                    yStart = 0;
                    auto tmp = p.value + vec2i(x, y);
                    int z;
                    auto posXY = TileXYPos(tmp); 

                    z = worldMap.getRealTopTilePos(posXY);
                    static if(iterationLimit != int.max) {
                        iterations++;
                        if (iterations >= iterationLimit) {
                            state.x = x;
                            state.y = y;
                            state.z = z;
                            g_Statistics.HeightmapsProgress(done);
                            return;
                        }
                    }

                    //state.z = int.max;
                    state.heightmap[x, y] = z;
                    //done++;
                    static if(iterationLimit == int.max) {
                        //g_Statistics.HeightmapsProgress(1);
                    }
                }
            }
            if(heightmapTasks !is null) {
                synchronized(heightmapTasks) {
                    auto idx = heightmapTasks.list.countUntil(state);
                    if(idx != -1) {
                        BREAK_IF(idx == -1);
                        heightmapTasks.list = heightmapTasks.list.remove(idx);

                        if (heightmapTasks.list.empty) {
                            g_Statistics.HeightmapsNew(0);
                        }
                    }
                }
            }
            getSectorXY(xy).heightmap = state.heightmap;
            static if(iterationLimit != int.max) {
                g_Statistics.HeightmapsProgress(done);        
            }
        }
    }

    void pushHeightmapTasks() {
        static if(compileHeightmaps) {
            synchronized (heightmapTasks) { //Not needed, since only thread working now. Anyway.. :)
                foreach (state; heightmapTasks.list) {
                    //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
                    (HeightmapTaskState state){

                                    scheduler.push(
                                       task(
                                                 (WorldProxy world){
                                                     generateHeightmapTaskFunc(state);
                                                 }));
                    }(state);

                }
            }
        }
    }

};
