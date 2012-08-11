module worldstate.heightmap;

import pos;
import worldstate.sizes;


final class SectorHeightmap {
    int[SectorSize.y][SectorSize.x] heightmap;

    void opIndexAssign(int val, size_t x, size_t y) {
        heightmap[x][y] = val;
    }
    ref int opIndex(size_t x, size_t y) {
        return heightmap[x][y];
    }
    this() {};
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
    immutable compileHeightmaps = true;
    immutable parallelHeightmaps = true;


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
                /*synchronized(heightmapTasks)*/ { // How could it not be? :)
                    auto tasks = heightmapTasks;
                    heightmapTasks = null;
                    foreach(task ; parallel(tasks.list)) {
                        mixin(MeasureTime!"heightmap ");
                        //scope(exit) msg(task.pos);
                        generateHeightmapTaskFunc!(int.max)(task);
                    }
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

    void generateHeightmapTaskFunc(int iterationLimit = 10_000)(HeightmapTaskState state) {
        static if(compileHeightmaps) {
            auto xy = state.pos;
            auto p = xy.getTileXYPos();
            int iterations = 0;
            int done = 0;
            int yStart = state.y;
            foreach (y ; yStart .. SectorSize.y) {
                foreach (x ; state.x .. SectorSize.x) {
                    
                    yStart = 0;
                    auto tmp = p.value + vec2i(x, y);
                    int z;
                    auto posXY = TileXYPos(tmp);

                    z = worldMap.getRealTopTilePos(posXY);

                    /*
                    if(worldMap.isInsideWorld(TilePos(vec3i(posXY.value.X, posXY.value.Y, z)))) {
                        while (worldMap.getTile(TilePos(vec3i(
                                                              posXY.value.X, posXY.value.Y, z))).type
                               is TileTypeAir) {
                                   z -= 1;
                               }
                    }
                    */
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
                    bool pred(HeightmapTaskState a) {
                        return a == state;
                    }
                    heightmapTasks.list = remove!pred(heightmapTasks.list);
                    if (heightmapTasks.list.empty) {
                        g_Statistics.HeightmapsNew(0);
                    }
                }
            }
            getSectorXY(xy).heightmap = state.heightmap;
            static if(iterationLimit != int.max) {
                g_Statistics.HeightmapsProgress(done);        
            }
        }
    }

    void pushHeightmapTasks(Scheduler scheduler) {
        static if(compileHeightmaps) {
            synchronized (heightmapTasks) { //Not needed, since only thread working now. Anyway.. :)
                foreach (state; heightmapTasks.list) {
                    //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
                    (HeightmapTaskState state){

                                    scheduler.push(
                                       asyncTask(
                                                 (WorldProxy world){
                                                     generateHeightmapTaskFunc(state);
                                                 }));
                    }(state);

                }
            }
        }
    }

};
