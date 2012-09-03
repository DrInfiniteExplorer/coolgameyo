module worldgen.heightmap;

mixin template Heightmap() {

    int heightSeed; //generated in initSeed, no need to serialize.

    ValueMap heightMap;

    double worldHeight = 8_848/0.7; //Twice half mt everest, then some. ( /0.7 ???? :S ) ah, to make worldMax = that.
    double worldMin;
    double worldMax;

    RandSourceUniform randSource;

    void heightmapInit() {
        worldMin = -0.3*worldHeight;
        worldMax =  0.7*worldHeight;
        heightMap = new ValueMap(Dim, Dim);
        randSource = new RandSourceUniform(heightSeed);
    }

    string heightmapJSONPath() const @property {
        return worldPath ~ "/height.json";
    }
    string heightmapImagePath() const @property {
        return worldPath ~ "/height.bin";
    }

    void saveHeightmap() {
        makeJSONObject(
                       "worldHeight", worldHeight,
                       "worldMin", worldMin,
                       "worldMax", worldMax).saveJSON(heightmapJSONPath);
        heightMap.saveBin(heightmapImagePath);
    }

    void loadHeightmap() {
        loadJSON(heightmapJSONPath).readJSONObject(
                                "worldHeight", &worldHeight,
                                "worldMin", &worldMin,
                                "worldMax", &worldMax);
        heightMap.loadBin(heightmapImagePath);
    }

    void generateHeightMap() {

        auto randomField = new ValueMap;
        auto gradient = new GradientNoise01!()(Dim, randSource);
        auto hybrid = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        hybrid.setBaseWaveLength(120);

        auto test = new DelegateSource((double x, double y, double z) {
            auto height = hybrid.getValue(x, y);
            auto xDist =  abs(200 - x);
            auto xBorderDistance = 200 - xDist;
            auto yDist =  abs(200 - y);
            auto yBorderDistance = 200 - yDist;

            immutable limit = 25.0;
            immutable limitSQ = limit ^^ 2.0;
            if(xBorderDistance < limit) {
                auto xLimitDistance = limit - xBorderDistance;
                auto ratio = (limitSQ - xLimitDistance^^2.0) / limitSQ;
                height *= ratio;
            }
            if(yBorderDistance < limit) {
                auto yLimitDistance = limit - yBorderDistance;
                auto ratio = (limitSQ - yLimitDistance^^2.0) / limitSQ;
                height *= ratio;
            }
            return height;
        });

        heightMap.fill(test, Dim, Dim);
        heightMap.normalize(worldMin * 0.1 , worldMax * 0.1); 

        auto hybrid2 = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        hybrid2.setBaseWaveLength(40);
        auto heightMap2 = new typeof(heightMap)(Dim, Dim);
        heightMap2.fill(hybrid2, Dim, Dim);
        heightMap2.normalize(worldMin * 0.2 , worldMax * 0.2); 

        heightMap.data[] += heightMap2.data[];

        //heightMap.data = array(map!(a => a > 0 ? 10.0 : -10.0)(heightMap.data));
    }

    
    TileXYPos getRandomPointOnLand() {
        auto x = randSource.get!int(0, worldSize-1);
        auto y = randSource.get!int(0, worldSize-1);
        auto X = x * Dim / worldSize;
        auto Y = y * Dim / worldSize;
        if(heightMap.get(X, Y) > 0) return TileXYPos(vec2i(x, y));
        return getRandomPointOnLand();

    }

}
