module gui.newgame.page1;


public static string[] enumerateSavedWorlds() {
    import util.filesystem;
    if(!exists("worlds/")) {
        return null;
    }
    string[] ret;
    dir("worlds/", (string s) {ret ~= s;});
    return ret;
}

public static string[] enumerateSaves() {
    import util.filesystem;
    if(!exists("saves/")) {
        return null;
    }
    string[] ret;
    dir("saves/", (string s) {if(s != "current") ret ~= s;});
    return ret;
}


mixin template Page1() {
    GuiElement page1;

    GuiElementWindow CurrentGames;
    GuiElementWindow GeneratedWorlds;

    PushButton newGameButton;
    PushButton newWorldButton;
    PushButton resumeGameButton;
    GuiElementListBox savesList;
    GuiElementListBox worldList;
    int worldSelected = -1;
    int saveSelected = -1;
    string worldName;
    string gameName;

    void initPage1() {

        page1 = new GuiElement(this);
        page1.setRelativeRect(Rectd(0, 0, 1, 1));

        CurrentGames = new GuiElementWindow(page1, Rectd(0.05, 0.05, 0.4, 0.75), "Current Games", false, false);
        GeneratedWorlds = new GuiElementWindow(page1, Rectd(0.55, 0.05, 0.4, 0.75), "Generated Worlds", false, false);
        auto backButton = new PushButton(page1, Rectd(0.075, 0.85, 0.1, 0.1), "Back", &onBack);

        auto worlds = enumerateSavedWorlds();
        auto saves = enumerateSaves();
        if(worlds.length + saves.length == 0) {
            noWorldsAvailable();
            return;
        }

        worldList = new GuiElementListBox(GeneratedWorlds, Rectd(0.1, 0.1, 0.8, 0.5), 18, &onSelectWorld);
        foreach(world ; worlds) {
            worldList.addItem(world);
        }
        worldList.setDoubleClickCallback((int i) { onNewGame(); });

        savesList = new GuiElementListBox(CurrentGames, Rectd(0.1, 0.1, 0.8, 0.7), 18, &onSelectGame);
        foreach(save ; saves) {
            savesList.addItem(save);
        }
        savesList.setDoubleClickCallback((int i) { onResumeGame(); });

        page1.setVisible(true);
        page1.bringToFront();

        resumeGameButton = new PushButton(CurrentGames, Rectd(0.1, 0.85, 0.3, 0.1), "Resume game", &onResumeGame);
        resumeGameButton.setEnabled(false);

        newGameButton = new PushButton(GeneratedWorlds, Rectd(0.1, 0.85, 0.3, 0.1), "New game", &onNewGame);
        newGameButton.setEnabled(false);

        newWorldButton = new PushButton(GeneratedWorlds, Rectd(0.6, 0.85, 0.3, 0.1), "New World", &onNewWorld);

        worldList.selectAny();
        savesList.selectAny();
    }

    void noWorldsAvailable() {
        setEnabled(false);
        new DialogBox(this, "No worlds avaiable", "Sorry, there are no worlds avaiable. Create one or cancel?",
                      "yes", &onNewWorld,
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

    void onSelectWorld(int idx) {
        worldSelected = idx;
        if(idx == -1) {
            newGameButton.setEnabled(false);            
        } else {
            newGameButton.setEnabled(true);
            auto name = worldList.getItemText(worldSelected);
            //worldImage.setImage(WorldMap.getWorldImage(name));
            worldName = name;
        }
    }

    void onSelectGame(int idx) {
        saveSelected = idx;
        if(idx == -1) {
            resumeGameButton.setEnabled(false);
        } else {
            resumeGameButton.setEnabled(true);
            auto name = savesList.getItemText(saveSelected);
            gameName = name;

        }
    }
}
