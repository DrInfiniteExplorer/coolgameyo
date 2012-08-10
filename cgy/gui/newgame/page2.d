module gui.newgame.page2;



mixin template Page2() {

    GuiElement page2;
    GuiElementImage bigWorldImage;
    GuiElementImage smallWorldImage;
    WorldMap worldMap;
    WorldMap.MapVisualizer mapViz;
    vec2i startPos;


    enum smallLevel = 3;
    enum smallSize = mapScale[smallLevel];


    void initPage2(string worldName) {
        page2 = new GuiElement(this);
        page2.setRelativeRect(Rectd(0, 0, 1, 1));
        page2.setVisible(true);
        page2.bringToFront();

        worldMap = new WorldMap(worldName);
        mapViz = worldMap.getVisualizer();

        double _400Pixels = 400.0 / renderSettings.windowWidth;

        bigWorldImage = new GuiElementImage(page2, Rectd(0.1, 0.1, _400Pixels, _400Pixels * renderSettings.widthHeightRatio));
        smallWorldImage = new GuiElementImage(page2, Rectd(bigWorldImage.rightOf+0.05, bigWorldImage.topOf,
                                                           bigWorldImage.widthOf, bigWorldImage.heightOf));

        auto backButton = new PushButton(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.bottomOf + 0.05, 0.2, 0.1), "Back", &onBack);

        new TabBar(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.topOf - 0.07, bigWorldImage.widthOf * 2, 0.05),
                   "Heightmap", { show!"Heightmap"(); },
                   "Shaded", { show!"ShadedHeightmap"(); }
        );

        auto StartButton = new PushButton(page2, Rectd(backButton.leftOf, backButton.bottomOf + 0.05, 0.2, 0.1), "Start", { worldMap.destroy(); onStartGame(); });



        bigWorldImage.setMouseClickCallback((GuiElement element, GuiEvent.MouseClick e) {
            if(e.down) return false;
            auto r = element.getAbsoluteRect();
            auto p = e.pos;
            auto nP = p - r.start;
            auto relative = nP.convert!double / r.size.convert!double;

            updatePos((relative * vec2d(mapScale[5])).convert!int);
            return true;
        });
        smallWorldImage.setMouseClickCallback((GuiElement element, GuiEvent.MouseClick e) {
            if(e.down || !e.left) return false;
            auto r = element.getAbsoluteRect();
            auto p = e.pos;
            auto nP = p - r.start;
            auto relative = nP.convert!double / r.size.convert!double;
            relative -= vec2d(0.5);

            auto pos = startPos + (relative * vec2d(smallSize)).convert!int;

            updatePos(pos);
            return true;
        });


        /*
        auto nextButton = new PushButton(page2, Rectd(backButton.rightOf, backButton.topOf, backButton.widthOf, backButton.heightOf), "Next", &newWorld);
        continueButton = new PushButton(page1, Rectd(newWorldButton.rightOf, newWorldButton.topOf, newWorldButton.widthOf, newWorldButton.heightOf), "Next", &onNext);
        continueButton.setEnabled(false);
        */
    }


    void delegate(vec2i) updatePos;
    void show(string which)() {
        bigWorldImage.setImage( mixin(q{mapViz.get} ~ which ~ q{Image()}));
        updatePos = (vec2i tilePos) {
            mixin(MeasureTime!"updatePos:");
            startPos = tilePos;
            auto img = mapViz.generateMap!(which)(TileXYPos(tilePos), smallSize);
            smallWorldImage.setImage(img);
            //smallWorldImage.setImageSource(Rectf(0.4, 0.4, 0.2, 0.2));
            msg(tilePos);
        };
        updatePos(startPos);
    }

    //Show about 12² kilometers on small map
    // Each pixel on the big map is ~8 kilometers big
    // If we show 12² kilometers on the small map,
    //  then each pixel there is about 30 meters,
    //  ie. 4 pixels make a sector.
    //  NEED EVEN BIGGER MAP??


}
