module gui.newgame.page1;






mixin template Page1() {
    GuiElement page1;

    PushButton continueButton;
    GuiElementText worldListLabel;
    GuiElementListBox worldList;
    GuiElementImage worldImage;
    int worldSelected = -1;

    void initPage1() {

        page1 = new GuiElement(this);
        page1.setRelativeRect(Rectd(0, 0, 1, 1));

        auto worlds = WorldMap.enumerateSavedWorlds();
        if(worlds.length == 0) {
            noWorldsAvailable();
            return;
        }
        page1.setVisible(true);
        page1.bringToFront();
        worldListLabel = new GuiElementText(page1, vec2d(0.1, 0.1), "List of generated worlds");
        worldList = new GuiElementListBox(page1, Rectd(worldListLabel.leftOf, worldListLabel.bottomOf + 0.5 * worldListLabel.heightOf, 0.3, 0.5), 18, &onSelectWorld);
        foreach(world ; worlds) {
            worldList.addItem(world);
        }
        worldList.setDoubleClickCallback((int i) { onNext(); });

        worldImage = new GuiElementImage(page1, Rectd(worldList.rightOf, worldList.topOf, worldList.widthOf, worldList.widthOf * renderSettings.widthHeightRatio));

        auto backButton = new PushButton(page1, Rectd(worldList.leftOf, worldList.bottomOf + 0.05, 0.2, 0.1), "Back", &onBack);
        auto newWorldButton = new PushButton(page1, Rectd(backButton.rightOf, backButton.topOf, backButton.widthOf, backButton.heightOf), "New World", &newWorld);
        continueButton = new PushButton(page1, Rectd(newWorldButton.rightOf, newWorldButton.topOf, newWorldButton.widthOf, newWorldButton.heightOf), "Next", &onNext);
        continueButton.setEnabled(false);
    }

    void noWorldsAvailable() {
        setEnabled(false);
        new DialogBox(this, "No worlds avaiable", "Sorry, there are no worlds avaiable. Create one or cancel?",
                      "yes", &newWorld,
                      "no", { onBack(); },
                          "wtf?", { noWorldsAvailable(); }
                      );
        /*
        new DialogBox(this, "No worlds avaiable", "Sorry, there are no worlds avaiable. Create one or cancel?", "yes|no|wtf?", (string choice) {
        setEnabled(true);
        if(choice == "yes") {
        setVisible(false);
        new WorldMenu(this);
        }else if(choice == "no") {
        onBack();
        } else {
        noWorldsAvailable();
        }
        });
        */
    }

    void newWorld() {
        setVisible(false);
        new WorldMenu(this);
    }

    void onSelectWorld(int idx) {
        worldSelected = idx;
        if(idx == -1) {
            continueButton.setEnabled(false);            
        } else {
            continueButton.setEnabled(true);
            auto name = worldList.getItemText(worldSelected);
            worldImage.setImage(WorldMap.getWorldImage(name));
        }
    }

}
