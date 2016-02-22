module worldgen.heightmap;

import std.parallelism;
import std.mmfile;
import std.math;
import util.filesystem;
import util.util;

enum sampleIntervall = 10; //10 meters between each sample

class Heightmaps {
    int worldSize; //In meters
    int mapSize; //In samples
    long mapSizeBytes;
    this(int size) {
        worldSize = size;
        mapSize = worldSize / sampleIntervall;
        mapSizeBytes = mapSize * mapSize * float.sizeof;
        msg("mapSize(kilo)Bytes: ", mapSizeBytes / 1024);
        auto create = true;
        if(existsDir("world")) {
            auto ret = NativeDialogBox("World exists! Recreate?", "Multiverse not supported", NDBAnswer.Yes_No);
            if(ret == 2) {
                create = false;
            } else {
                rmdir("world");
            }
        }
        if(create) createWorld();
    }

    import strata;

    //Assumes z=0 == surface of world and Z+ is upwards
    // May have to offset with world contour first.
    int getStrataNum(int x, int y, int z) {
        int num = 0;
        auto xyPos = vec2f(x, y);
        float depth = stratas[0].getHeight(xyPos);
        int zDepth = -z;
        while(zDepth > depth) {
            num++;
            depth += stratas[num].getHeight(xyPos);
        }
        return num;
    }

    void heightOnHeight(MaterialStratum[] stratas) {
        import graphics.image;
        import materials;
        import statistics;

        mixin(MeasureTime!("Time to generate "));
        int layerNum = 0;
        float depth = stratas[layerNum].thickness;
        int height = 3500;
        Image img = Image(null, 1280, height);
        vec3f color;
        int oldy=-1;
        string prevMat;
        color.set(0.5,1.0,1.0);
        color *= 255;
        foreach(x,Y, ref r, ref g, ref b, ref a ; img) {
            auto y = Y - 500;
            if(y < 0) {
                color.toColor(r, g, b);
                continue;
            }
            a = 255;
            auto layerNum = getStrataNum(x, x, -y);
            auto materialName = stratas[layerNum].materialName;
            color = g_Materials[materialName].color.convert!float;
            color.toColor(r, g, b);
        }
        img.save("strata_height_on_height.bmp");
    }

    MaterialStratum[] stratas;

    void createWorld() {

        import materials;
        import graphics.image;
        loadStrataInfo();
        loadMaterials();
        stratas = generateStratas();

        int layerNum = 0;
        float depth = stratas[layerNum].thickness;
        int height = 3500;
        Image img = Image(null, 1280, height);
        vec3f color;
        int oldy=-1;
        string prevMat;
        color.set(0.5,1.0,1.0);
        color *= 255;
        foreach(x,Y, ref r, ref g, ref b, ref a ; img) {
            auto y = Y - 500;
            if(y < 0) {
                color.toColor(r, g, b);
                continue;
            }
            a = 255;
            if(y != oldy) {
                oldy = y;
                if(depth < y) {
                    layerNum++;
                    if(layerNum == stratas.length) layerNum--;
                    msg(depth, " ", stratas[layerNum].thickness);
                    depth += stratas[layerNum].thickness;
                    color.set(0,0,0);
                } else {
                    auto materialName = stratas[layerNum].materialName;
                    if(prevMat != materialName)
                        msg(depth, " Material: ", materialName);
                    prevMat = materialName;
                    color = g_Materials[materialName].color.convert!float;
                }
            }
            color.toColor(r, g, b);
            a = 255;
        }
        img.save("strata_no_noise.bmp");

        //heightOnHeight(stratas);
        heightOnHeight(stratas);


        mkdir("world");
        auto memfile = new MmFile("world/map1", MmFile.Mode.readWriteNew, mapSizeBytes, null, 0);
        scope(exit) delete memfile;
        auto mapPtr = cast(float[])memfile[];
        //float mapPtr[] = new float[cast(uint)mapSizeBytes / float.sizeof];

        auto startTime = utime();

        float maxHeight = 10_000;
        float startAmplitude = maxHeight / 2;
        float endAmplitude = 0.5;
        int octaves = cast(int)logb(startAmplitude / endAmplitude);

        float endIntervall = 3;
        float startIntervall = endIntervall * 2^^octaves;

        float baseFrequency = 1.0f / startIntervall;


        msg("Octaves: ", octaves);
        msg("Start amplitude: ", startAmplitude);
        msg("Start intervall: ", 1.0f / baseFrequency, " | ", startIntervall);
        msg("End amplitude: ", startAmplitude * 0.5^^octaves, " | ", endAmplitude);
        msg("End intervall: ", 0.5^^octaves / baseFrequency, " | ", endIntervall);

        import random.simplex;
        auto noise = new SimplexNoise(1023);

        uint LIMIT = mapSize * mapSize;
        uint LIMIT_STEP = LIMIT / 2500;
        //for(uint i = 0; i < LIMIT; i++) {
        uint progress = 0;
        foreach(uint i, ref value ; parallel(mapPtr)) {
            if( (i % LIMIT_STEP) == 0) {
                progress += LIMIT_STEP;
                msg("Progress: ", 100.0f * cast(float)progress / LIMIT);
            }

            float value = 0;
            auto pos = vec2f(i / mapSize, i % mapSize);
            pos *= baseFrequency;

            float amplitude = startAmplitude;

            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * noise.getValue(pos.X, pos.Y);
                amplitude *= 0.5;
                pos *= 2;
            }

            mapPtr[i] = value;
        }

        //auto data = memfile[];
        //data[] = mapPtr[];
        msg("Time to make heightmap: ", (utime() - startTime) / 1_000_000.0);
    }
}






