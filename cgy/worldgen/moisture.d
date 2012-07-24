module worldgen.moisture;

mixin template Moisture() {
    ValueMap moistureMap;


    void moistureInit() {
        moistureMap = new ValueMap(Dim, Dim);
    }

    string moistureImagePath() const @property {
        return worldPath ~ "/moisture.bin";
    }

    void saveMoistureMap() {
        moistureMap.saveBin(moistureImagePath);
    }
    void loadMoistureMap() {
        moistureMap.loadBin(moistureImagePath);
    }

    void generateMoistureMap() {
        moistureMap.fill((double x, double y) {
            double grad = 0.0;
            if(heightMap.get(cast(int)x, cast(int) y) <= 0.0 ) {
                return 10;
            }
            auto wind = windMap.get(cast(int)x, cast(int)y);
            grad = wind.dotProduct(heightMap.upwindGradient(x, y, wind.X, wind.Y)) * 0.05;
            return 4 + grad;

        }, Dim, Dim);

    }
}
