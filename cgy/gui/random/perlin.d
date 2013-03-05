module gui.random.perlin;

mixin template RandomPerlin() {

    GuiElementImage perlinImg;

    void initPerlin() {

        perlinImg = new GuiElementImage(container, Rectd(0, 0, 0.6, 0.6));

        redraw = &renderPerlin;
        renderPerlin();
    }


    void renderPerlin() {
        auto randomField = new ValueMap2Dd;
        auto heightMap = new ValueMap2Dd(400, 400);
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(seed));
        import random.modscaleoffset;
        auto derp = new ModScaleOffset(gradient, vec3d(1.0/40.0), vec3d(0));
        heightMap.fill(&derp.getValue2, 400, 400);
        heightMap.normalize(0, 1.0);
        perlinImg.setImage(heightMap.toImage(0, 1, true, colorMode));
    }

    void destroyPerlin() {
        container.destroy();
    }



}

mixin template RandomSimplex() {

    GuiElementImage simplexImg;

    void initSimplex() {

        simplexImg = new GuiElementImage(container, Rectd(0, 0, 0.6, 0.6));

        redraw = &renderSimplex;
        renderSimplex();
    }


    void renderSimplex() {
        auto randomField = new ValueMap2Dd;
        auto heightMap = new ValueMap2Dd(400, 400);
        auto gradient = new SimplexNoise(seed);
        import random.modscaleoffset;
        auto derp = new ModScaleOffset(gradient, vec3d(1.0/40.0), vec3d(0));
        heightMap.fill(&derp.getValue2, 400, 400);
        heightMap.normalize(0, 1.0);
        simplexImg.setImage(heightMap.toImage(0, 1, true, colorMode));
    }

    void destroySimplex() {
        container.destroy();
    }



}

