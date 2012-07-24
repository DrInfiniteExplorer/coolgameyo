module worldgen.temperature;

mixin template Temperature() {
    ValueMap temperatureMap;

    double temperatureMin;
    double temperatureMax;
    double temperatureRange;

    void temperatureInit() {
        temperatureMin = -20;
        temperatureMax = 40;
        temperatureRange = temperatureMax - temperatureMin;

        temperatureMap = new ValueMap(Dim, Dim);
    }

    string temperatureJSONPath() const @property {
        return worldPath ~ "/temperature.json";
    }
    string temperatureImagePath() const @property {
        return worldPath ~ "/temperature.bin";
    }

    void saveTemperatureMap() {
        makeJSONObject(
                       "tempMin", temperatureMin,
                       "tempMax", temperatureMax).saveJSON(temperatureJSONPath);
        temperatureMap.saveBin(temperatureImagePath);
    }
    void loadTemperatureMap() {
        loadJSON(temperatureJSONPath).readJSONObject(
                                                   "tempMin", &temperatureMin,
                                                   "tempMax", &temperatureMax);
        temperatureRange = temperatureMax - temperatureMin;
        temperatureMap.loadBin(temperatureImagePath);
    }

    void generateTemperatureMap() {
        auto equatorDistanceField = new PlanarDistanceField(vec3d(0, 200, 0), vec3d(0, 1, 0));
        auto equatorChillField = new Map(equatorDistanceField, d => temperatureMax - (d<0?-d:d)*temperatureRange/200 );

        //Every 1000 meter gets about 10 degree colder
        // http://www.marietta.edu/~biol/biomes/biome_main.htm
        auto heightChillField = new Map(heightMap, d => d < 0 ? -10 : -d/100);

        double combine(double x, double y) {
            double grad = 0.0;
            if(heightMap.get(cast(int)x, cast(int) y) > 0.0 ) {
                auto wind = windMap.get(cast(int)x, cast(int)y);
                grad = wind.dotProduct(heightMap.upwindGradient(x, y, wind.X, wind.Y)) * 0.05;
            }

            return equatorChillField.getValue(x, y) + heightChillField.getValue(x, y) - grad;
        }

        temperatureMap.fill(&combine, Dim, Dim);
    }

}
