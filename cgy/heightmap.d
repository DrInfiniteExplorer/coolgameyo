module heightmap;

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

    void createWorld() {

        import strata;
        import materials;
        loadStrataInfo();
        loadMaterials();
        auto stratas = generateStratas();

        float depth = 0;
        int layerNum = 0;
        import graphics.image;
        int height = 3000;
        Image img = Image(null, 1280, height);
        vec3f color;
        int oldy=-1;
        string prevMat;
        foreach(x,y, ref r, ref g, ref b, ref a ; img) {
            a = 255;
            if(y != oldy) {
                oldy = y;
                if(depth < y) {
                    msg(depth);
                    depth += stratas[layerNum].thickness;
                    layerNum++;
                    color.set(0,0,0);
                } else {
                    if(layerNum == stratas.length) layerNum--;
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

        {
            import statistics;
        mixin(MeasureTime!("Time to generate "));
        foreach(x,y, ref r, ref g, ref b, ref a ; img) {
            a = 255;

            depth = 0.0f;
            layerNum = 0;
            while(y > depth) {
                depth += stratas[layerNum].getHeight(vec2f(1232+1.01728379*x+0.2f));
                layerNum++;
                if(layerNum == stratas.length) {
                    layerNum--;
                    break;
                }
            }
            auto materialName = stratas[layerNum].materialName;
            color = g_Materials[materialName].color.convert!float;
            color.toColor(r, g, b);
        }
        }
        img.save("strata.bmp");



        mkdir("world");
        auto memfile = new MmFile("world/map1", MmFile.Mode.readWriteNew, mapSizeBytes, null, 0);
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

        import random.gradientnoise;
        auto noise = new GradientNoise!()(1023, 1023);

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
            float frequency = baseFrequency;
            auto pos = vec2f(i / mapSize, i % mapSize);
            pos *= frequency;

            float amplitude = startAmplitude;

            for(int iter = 0; iter < octaves; iter++) {
                value += amplitude * noise.getValue(pos.X, pos.Y);
                amplitude *= 0.5;
                pos *= 2;
                frequency *= 2;
            }

            mapPtr[i] = value;
        }

        //auto data = memfile[];
        //data[] = mapPtr[];
        msg("Time to make heightmap: ", (utime() - startTime) / 1_000_000.0);



    }
}






