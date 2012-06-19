module gui.random.perlin;

mixin template RandomPerlin() {

    GuiElementImage perlinImg;

    void initPerlin() {

        perlinImg = new GuiElementImage(container, Rectd(0, 0, 0.6, 0.6));

        redraw = &renderPerlin;
        renderPerlin();
    }


    void renderPerlin() {
        auto randomField = new ValueMap;
        auto heightMap = new ValueMap(400, 400);
        auto gradient = new GradientNoise01!()(400, new RandSourceUniform(seed));
        heightMap.fill(gradient, 400, 400);
        heightMap.normalize(0, 1.0);
        perlinImg.setImage(heightMap.toImage(0, 1, true, colorMode));
    }

    void destroyPerlin() {
        container.destroy();
    }



}

