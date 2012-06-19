module gui.random.ridgedfractal;


mixin template RandomRidged() {

    GuiElementImage heightImg;

    float H = 0.5;
    float lacuna = 2;
    float octaves = 6;
    float offset = 1;
    float gain = 1;

    void initRidged() {
        heightImg = new GuiElementImage(container, Rectd(0, 0, 0.6, 0.6));

        auto a = new GuiElementLabeledEdit(container, Rectd(0.1, 0.7, 0.2, 0.05), "H(dimension)", to!string(H));
        with(a){
            setOnEnter((string value) {
                H = to!float(value);
                renderRidged();
            });
        }
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "lacunarity", to!string(lacuna));
        with(a) {
            setOnEnter((string value) {
                lacuna = to!float(value);
                renderRidged();
            });
        }
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "octaves", to!string(octaves));
        with(a) {
                setOnEnter((string value) {
                octaves = to!float(value);
                renderRidged();
            });
        }
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "offset", to!string(offset));
        with(a) {
            setOnEnter((string value) {
                offset = to!float(value);
                renderRidged();
            });
        }
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "gain", to!string(gain));
        with(a) {
            setOnEnter((string value) {
                gain = to!float(value);
                renderRidged();
            });
        }
        redraw = &renderRidged;
        renderRidged();
    }

    void renderRidged() {
        auto randomField = new ValueMap;
        auto heightMap = new ValueMap(400, 400);
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(seed));
        auto ridged = new RidgedMultiFractal(gradient, H, lacuna, octaves, offset, gain);
        ridged.setBaseWaveLength(50);
        heightMap.fill(ridged, 400, 400);
        heightMap.normalize(0, 1.0);
        heightImg.setImage(heightMap.toImage(0, 1, true, colorMode));
    }

    void destroyRidged() {
        container.destroy();
    }



}

