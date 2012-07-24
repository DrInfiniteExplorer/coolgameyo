module worldgen.heightmap;

mixin template Heightmap() {

    int heightSeed; //generated in initSeed, no need to serialize.

    ValueMap heightMap;

    double worldHeight = 10_000;
    double worldMin;
    double worldMax;

    void heightmapInit() {
        worldMin = -0.3*worldHeight;
        worldMax =  0.7*worldHeight;
        heightMap = new ValueMap(Dim, Dim);
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
        auto gradient = new GradientNoise01!()(Dim, new RandSourceUniform(heightSeed));
        auto hybrid = new HybridMultiFractal(gradient, 0.1, 2, 6, 0.1);
        hybrid.setBaseWaveLength(80);

        auto test = new DelegateSource((double x, double y, double z) {
            auto height = hybrid.getValue(x, y);
            auto xDist =  abs(200 - x);
            auto xBorderDistance = 200 - xDist;
            auto yDist =  abs(200 - y);
            auto yBorderDistance = 200 - yDist;

            enum limit = 25.0;
            enum limitSQ = limit ^^ 2.0;
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
        heightMap.normalize(worldMin, worldMax); 
    }

}
