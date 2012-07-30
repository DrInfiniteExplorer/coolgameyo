module gui.newgame.page2;



mixin template Page2() {

    GuiElement page2;
    GuiElementImage bigWorldImage;
    GuiElementImage smallWorldImage;
    WorldMap worldMap;
    WorldMap.MapVisualizer mapViz;
    vec2i startPos;

    void initPage2(string worldName) {
        page2 = new GuiElement(this);
        page2.setRelativeRect(Rectd(0, 0, 1, 1));
        page2.setVisible(true);
        page2.bringToFront();

        worldMap = new WorldMap(worldName);
        mapViz = worldMap.getVisualizer();

        bigWorldImage = new GuiElementImage(page2, Rectd(0.1, 0.1, 0.3, 0.3 * renderSettings.widthHeightRatio));
        smallWorldImage = new GuiElementImage(page2, Rectd(bigWorldImage.rightOf+0.05, bigWorldImage.topOf,
                                                           bigWorldImage.widthOf, bigWorldImage.heightOf));

        auto backButton = new PushButton(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.bottomOf + 0.05, 0.2, 0.1), "Back", &onBack);

        new TabBar(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.topOf - 0.07, bigWorldImage.widthOf * 2, 0.05),
                   "Heightmap", { show!"Heightmap"(); },
                   "Shaded", { show!"ShadedHeightmap"(); }
        );


        bigWorldImage.setMouseClickCallback((GuiElement element, GuiEvent.MouseClick e) {
            auto r = element.getAbsoluteRect();
            auto p = e.pos;
            auto nP = p - r.start;
            auto relative = nP.convert!double / r.size.convert!double;
            
            updatePos((relative * vec2d(mapScale[5])).convert!int);
            return true;
        });

        /*
        auto nextButton = new PushButton(page2, Rectd(backButton.rightOf, backButton.topOf, backButton.widthOf, backButton.heightOf), "Next", &newWorld);
        continueButton = new PushButton(page1, Rectd(newWorldButton.rightOf, newWorldButton.topOf, newWorldButton.widthOf, newWorldButton.heightOf), "Next", &onNext);
        continueButton.setEnabled(false);
        */
    }

    void show(string which)() {
        bigWorldImage.setImage( mixin(q{mapViz.get} ~ which ~ q{Image()}));
    }

    //Show about 12² kilometers on small map
    // Each pixel on the big map is ~8 kilometers big
    // If we show 12² kilometers on the small map,
    //  then each pixel there is about 30 meters,
    //  ie. 4 pixels make a sector.
    //  NEED EVEN BIGGER MAP??

    void updatePos(vec2i tilePos) {
        smallWorldImage.setImage(mapViz.generateMap!"Shaded"(TileXYPos(tilePos), 4*4*4*12_000));
        msg(tilePos);
    }

}
