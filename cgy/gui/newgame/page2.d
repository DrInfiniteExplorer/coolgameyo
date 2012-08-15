module gui.newgame.page2;



mixin template Page2() {

    GuiElement page2;
    GuiElementImage bigWorldImage;
    GuiElementImage smallWorldImage;
    WorldMap worldMap;
    WorldMap.MapVisualizer mapViz;
    vec2i startPos;


    immutable smallLevel = 3;
    immutable smallSize = mapScale[smallLevel];


    void initPage2() {
        page2 = new GuiElement(this);
        page2.setRelativeRect(Rectd(0, 0, 1, 1));
        page2.setVisible(true);
        page2.bringToFront();

        worldMap = new WorldMap(worldName);
        mapViz = worldMap.getVisualizer();

        try {
            loadJSON("worlds/" ~ worldName ~ "/start.json").readJSONObject("startPos", &startPos);
        }catch(Throwable o) {}

        double _400Pixels = 400.0 / renderSettings.windowWidth;

        bigWorldImage = new GuiElementImage(page2, Rectd(0.1, 0.1, _400Pixels, _400Pixels * renderSettings.widthHeightRatio));
        smallWorldImage = new GuiElementImage(page2, Rectd(bigWorldImage.rightOf+0.05, bigWorldImage.topOf,
                                                           bigWorldImage.widthOf, bigWorldImage.heightOf));

        auto backButton = new PushButton(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.bottomOf + 0.05, 0.2, 0.1), "Back", &onBack);

        auto tabBar = new TabBar(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.topOf - 0.07, bigWorldImage.widthOf * 2, 0.05),
                   "Heightmap", { show!"Heightmap"(); },
                   "Shaded", { show!"ShadedHeightmap"(); },
                   "Climate", { show!"Climate"(); }
        );
        tabBar.select(2);


        auto StartButton = new PushButton(page2, Rectd(backButton.leftOf, backButton.bottomOf + 0.05, 0.2, 0.1), "Start", {
            worldMap.destroy();
            onStartGame();
        });



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
        mixin(MeasureTime!"show: ");
        auto img = mixin(q{mapViz.get} ~ which ~ q{Image()});


        auto pixPos = ((startPos.convert!double / vec2d(worldSize)) * vec2d(400)).convert!int;
        img.setPixel(pixPos.X, pixPos.Y, 255, 0, 0, 0);
        bigWorldImage.setImage( img );
        
        img = mapViz.generateMap!(which)(TileXYPos(startPos), smallSize);
        smallWorldImage.setImage(img);

        updatePos = (vec2i tilePos) {
            startPos = tilePos;
            makeJSONObject("startPos", startPos).saveJSON("worlds/" ~ worldName ~ "/start.json");
            show!which();

        };
        //updatePos(startPos);
    }

    //Show about 12² kilometers on small map
    // Each pixel on the big map is ~8 kilometers big
    // If we show 12² kilometers on the small map,
    //  then each pixel there is about 30 meters,
    //  ie. 4 pixels make a sector.
    //  NEED EVEN BIGGER MAP??


}
