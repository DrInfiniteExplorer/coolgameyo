module gui.random.hybridfractal;


mixin template RandomHybrid() {

    GuiElementImage heightImg;

    float H = 0.5;
    float lacuna = 2;
    float octaves = 6;
    float offset = 0.7;
    float wavelength = 40;

    void initHybrid() {
        heightImg = new GuiElementImage(container, Rectd(0, 0, 0.6, 0.6));

        auto a = new GuiElementLabeledEdit(container, Rectd(0.1, 0.7, 0.2, 0.05), "H(dimension)", to!string(H));
        a.setOnEnter((string value) {
                H = to!float(value);
                renderHybrid();
            });
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "lacunarity", to!string(lacuna));
        a.setOnEnter((string value) {
                lacuna = to!float(value);
                renderHybrid();
            });
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "octaves", to!string(octaves));
        a.setOnEnter((string value) {
                octaves = to!float(value);
                renderHybrid();
            });
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "offset", to!string(offset));
        
        a.setOnEnter((string value) {
                offset = to!float(value);
                renderHybrid();
            });
        a = new GuiElementLabeledEdit(container, Rectd(0.1, a.bottomOf, 0.2, 0.05), "wavelength", to!string(wavelength));
        a.setOnEnter((string value) {
            wavelength = to!float(value);
            renderHybrid();
        });
        redraw = &renderHybrid;
        renderHybrid();
    }

    void renderHybrid() {
        auto randomField = new ValueMap2Dd;
        auto heightMap = new ValueMap2Dd(400, 400);
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(seed));

        auto hybrid = new HybridMultiFractal(gradient, H, lacuna, octaves, offset);
        hybrid.setBaseWaveLength(wavelength);

        auto source = new DelegateSource((double x, double y, double z){
            x -= 200;
            y -= 200;
            auto len = sqrt(x^^2 + y^^2) / 10;
            auto dir = (atan2(y, x)) * 50;
            return -(hybrid.getValue(len, dir) * len / 10 + hybrid.getValue(x, y) * 0.5);
        });

        auto sourceA = (double x, double y, double z) { return source.getValue(x,y,z); };

        auto sourceB = new DelegateSource((double x, double y, double z){
            auto fix(string Op, T...)(T t) {
                alias typeof(t[0]) B;
                B ret = -B.infinity;
                foreach(val ; t) {
                    ret = mixin(Op);
                }
                return ret;
            }
            return fix!"max(val, ret)"(
                                       sourceA(x, y, z) * 1.0,
                                       sourceA(x+145, y-23, z) * 1.3,
                                       sourceA(x-78, y+54, z) * 1.4,
                                       sourceA(x+2, y+189, z) * 1.2);
        });

        heightMap.fill(hybrid, 400, 400);
        heightMap.normalize(0, 1.0);
        heightImg.setImage(heightMap.toImage(0, 1, true, colorMode));
    }

    void destroyHybrid() {
        container.destroy();
    }



}




