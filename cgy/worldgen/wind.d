module worldgen.wind;

mixin template Wind() {
    int windSeed;

    Vector2DMap2D!(double, true) windMap;

    void windInit() {
        windMap = new typeof(windMap)(Dim, Dim);
    }

    string windImagePath() const @property {
        return worldPath ~ "/wind.bin";
    }

    void saveWindMap() {
        windMap.saveBin(windImagePath);
    }
    void loadWindMap() {
        windMap.loadBin(windImagePath);
    }


    //So as not to take too much time, just use a prevalent wind from east with some noise.
    void generateWindMap() {
        auto randomField = new ValueMap;
        auto windRnd = new RandSourceUniform(windSeed);
        auto gradientNoise = new GradientNoise!()(Dim, windRnd);

        auto hybridCombo = new DelegateSource2D( (double x, double y, double z) {
            auto dir = vec2d(-1.0, gradientNoise.getValue(x/40.0, y/40.0));
            return dir;
        });

        windMap.fill(hybridCombo, Dim, Dim);
        windMap.normalize(0.8, 1.2); 
    }

}
