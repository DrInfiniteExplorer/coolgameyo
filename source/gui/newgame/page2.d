module gui.newgame.page2;



mixin template Page2() {

    GuiElement page2;
    GuiElementImage bigWorldImage;
    GuiElementImage smallWorldImage;
    WorldMap worldMap;
    vec2i startPos = HalfWorldSize_xy;



    void initPage2() {
        page2 = new GuiElement(this);
        page2.setRelativeRect(Rectd(0, 0, 1, 1));
        page2.setVisible(true);
        page2.bringToFront();

        worldMap = new WorldMap();
        worldMap.loadWorld("worlds/" ~ worldName);

        if(exists("worlds/" ~ worldName ~ "/start.json")) {
            loadJSON("worlds/" ~ worldName ~ "/start.json").readJSONObject("startPos", &startPos);
        }

        double _400Pixels = 400.0 / renderSettings.windowWidth;

        bigWorldImage = new GuiElementImage(page2, Rectd(0.1, 0.1, _400Pixels, _400Pixels * renderSettings.widthHeightRatio));
        smallWorldImage = new GuiElementImage(page2, Rectd(bigWorldImage.rightOf+0.05, bigWorldImage.topOf,
                                                           bigWorldImage.widthOf, bigWorldImage.heightOf));

        auto backButton = new PushButton(page2, Rectd(bigWorldImage.leftOf, bigWorldImage.bottomOf + 0.05, 0.2, 0.1), "Back", &onBack);

        auto StartButton = new PushButton(page2, Rectd(backButton.leftOf, backButton.bottomOf + 0.05, 0.2, 0.1), "Start", {
            worldMap.destroy();
            makeJSONObject("startPos", startPos).saveJSON("worlds/" ~ worldName ~ "/start.json");
            if(exists(g_worldPath)) {
                msg("WARNING: " ~ g_worldPath ~ " exists. Terminating the previous existance!");
                rmdir(g_worldPath ~ "");
            }
            if(exists("saves/" ~ worldName)) {
                msg("WARNING: saves/" ~ worldName~ " exists. Terminating the previous existance!");
                rmdir("saves/" ~ worldName);
            }
            copy("worlds/" ~ worldName, "saves/" ~ worldName);
            gameName = worldName;
            onResumeGame();
        });

    }


}
