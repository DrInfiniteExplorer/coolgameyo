module feature.feature;

import std.exception;
import std.math;
import std.random;
import std.stdio;
import std.traits;

import json;

import pos;
import random.gradientnoise;
import random.hybridfractal;
import random.randsource;
import random.valuemap;
import random.valuesource;

import worldgen.layers;
import worldgen.maps;
import util.math;
import util.rangefromto;
import util.util;

class Feature {
    abstract void affectHeightmap(LayerMap map, int level);
    abstract void init(LayerMap map);

    abstract Value save();
    abstract void load(Value jsonValue);

    static Feature create(Value json) {
        auto className = json["featureName"].str;
        auto obj = factory(className);
        enforce(obj !is null, "Could not create class of type " ~ className);
        auto feature = cast(Feature) obj;
        feature.load(json);
        return feature;
    }

    void* ptr;
    T rand(T)(T min, T max) {
        BREAK_IF(ownerMap is null);
        BREAK_IF(ownerMap.randomField is null);
        if(ptr is null) {
            ptr = ownerMap.randomField.data.ptr;
        }
        uint* tPtr = cast(uint*) ptr;
        uint ret = *tPtr;
        tPtr++;
        uint* endPtr = cast(uint*)&ownerMap.randomField.data[$-1];
        if(cast(uint)tPtr > cast(uint)endPtr) {
            ptr = ownerMap.randomField.data.ptr;
        }

        static if(isFloatingPoint!T) {
            double tmp = cast(double)ret;
            return min + (max-min) * (tmp / uint.max);
        } else {
            return min + (ret % (max - min));
        }
    }



    LayerMap ownerMap;
}

class ConeMountainFeature : public Feature {

    TileXYPos tp;
    int height;
    double radius;

    ValueMap2Dd heightMap;

    this() { //For factory.
    }

    this(TileXYPos tp, int height) {
        create(tp, height);
    }

    void create(TileXYPos _tp, int _height) {
        tp = _tp;
        height = _height;
        radius = height / 2.0;

        //Somehow use tp as randomseed.
        // Use something else as seed as well?
        //Probably want a link-back of sorts to the top-layer this feature is part of,
        // so we can use that place's random-field for things of awesomeness.
    }

    override void init(LayerMap map) {
        ownerMap = map;

        heightMap = new ValueMap2Dd(400, 400);
        int seed = rand(int.min, int.max) + tp.value.X + tp.value.Y;
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(seed));

        immutable H = 0.5;
        immutable lacuna = 2;
        immutable octaves = 4;
        immutable offset = 0.7;
        immutable wavelength = 40;
        auto hybrid = new HybridMultiFractal(gradient, H, lacuna, octaves, offset);
        hybrid.setBaseWaveLength(wavelength);

        auto source = new DelegateSource((double x, double y, double z){
            x -= 200;
            y -= 200;
            auto len = sqrt(x^^2 + y^^2) / 10;
            auto dir = atan2(y, x) * 50;
            return -(hybrid.getValue(len, dir) * len / 10 + hybrid.getValue(x, y) * 0.5);
        });

        //heightMap.fill(source, 400, 400);
        //heightMap.normalize(-1.0, 1.0);
    }

    override void affectHeightmap(LayerMap map, int level) {
        //Maybe figure out if mountains shouldn't be on level3 really? or? something?
        if(level == 4) {
            auto heightMap = map.heightMap;
            immutable int level = 4;
            immutable int mapSize = mapScale[level];
            immutable int ptScale = ptScale[level];

            vec2i centerIdx = tp.value / ptScale;

            int radiusInMeters = cast(int)this.radius;
            int radius = radiusInMeters / ptScale;
            foreach(x, y ; Range2D(centerIdx - vec2i(radius), centerIdx + vec2i(radius))) {
                x = clamp(x, 0, Dim-1);
                y = clamp(y, 0, Dim-1);
                int dist = vec2i(x, y).getDistanceFrom(centerIdx) * ptScale;
                auto tmp = height - dist*2.0;
                double height = heightMap.get(x, y) + clamp(tmp, 0.0, 323123123.0);
                heightMap.set(x, y, height);
            }
        } else if(level == 3) {
            /*
            auto mapNum = map.mapNum;
            immutable int mapSize = mapScale[level];
            immutable int ptScale = ptScale[level];

            auto startTp = tp.value - vec2i(cast(int)radius);
            auto endTp = tp.value + vec2i(cast(int)radius);
            auto rangeTp = endTp - startTp;

            auto mapStartTp = mapNum * mapSize;
            auto mapEndTp = mapStartTp + mapSize;
            auto mapRange = mapEndTp - mapStartTp;

            auto mapStart = mapStartTp / rangeTp;
            auto mapEnd = mapEndTp / rangeTp;
            writeln(mapStart, ":", mapEnd);
            */

        }
    }

    override Value save() {
        return makeJSONObject("className", this.classinfo.name,
                              "tp", tp,
                              "height", height,
                              "radius", radius);
    }

    override void load(Value json) {
        json.readJSONObject("tp", &tp,
                            "height", &height,
                            "radius", &radius);
    }
}
