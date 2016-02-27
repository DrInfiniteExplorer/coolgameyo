module gui.joinmenu;

import std.algorithm;
import std.array;

import game: game;
import globals;
import gui.all;
import main;
import settings;
import cgy.util.filesystem : exists, rmdir;
import cgy.util.rect;
import cgy.util.util;
import gui.ingame;
import gui.guisystem.dialogbox;

class JoinMenu : GuiElementWindow {
    PushButton joinButt;
    GuiElementEditbox nameEdit;
    GuiElementEditbox servEdit;
    GuiElementListBox serverList;
    bool done;
    bool back;
    string server;

    this(GuiSystem g) {
        super(g, Rectd(0.1, 0.1 , 0.8, 0.8), "Join game", false, false);

        auto startX = 0.1;
        auto width = 0.3;
        auto height = 0.025;

        if(g_serverList.length) {
            server = g_serverList[0];
        } else {
            server = "localhost";
        }

        nameEdit = new GuiElementLabeledEdit(this, Rectd(startX, 0.1, width, height), "Nick:", g_playerName);
        servEdit = new GuiElementLabeledEdit(this, Rectd(startX, 0.15, width, height), "Server:", server);
        joinButt = new PushButton(this, Rectd(nameEdit.rightOf + 0.05, 0.1, width, 0.05), "Join", &onJoinGame);

        serverList = new GuiElementListBox(this, Rectd(servEdit.leftOf, servEdit.bottomOf + 0.05, 0.2, 0.6), 18, &onServerSelect);
        foreach(addr ; g_serverList) {
            serverList.addItem(addr);
        }

        auto backButt = new PushButton(this, Rectd(0.1, serverList.bottomOf + 0.05, width, 0.05), "Back", &onBack);
    }

    override void destroy() {
        super.destroy();
        saveSettings();
        done = true;
    }    

    void onServerSelect(int idx) {
        if(idx == -1) return;

        auto selected = serverList.getItemText(idx);
        servEdit.setText(selected);
    }


    void onJoinGame() {
        server = servEdit.getText();
        size_t oldIdx = countUntil(g_serverList, server);
        while(oldIdx != -1) {
            g_serverList = g_serverList.remove(oldIdx);
            oldIdx = countUntil(g_serverList, server);
        }
        g_serverList.insertInPlace(0, server);
        g_playerName = nameEdit.getText();
        destroy();
    }

    void onBack() {
        back = true;
        destroy();
    }
}


string joinMenu() {
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
    scope(exit) {
        if(guiSystem) {
            guiSystem.destroy();
        }
    }

    auto menu = new JoinMenu(guiSystem);

    EventAndDrawLoop!true(guiSystem, null, { return menu.done; } );
    guiSystem.destroy();
    delete guiSystem;
    guiSystem = null;

    if(menu.back) {
        return "main";
    }

    if(startClient(menu.server)) {
        return "join";
    }

    return "main";
}

//Return true to return to main menu.
bool startClient(string host) {
    msg("Starting client connecting to ", host);
    if(exists(g_worldPath)) {
        msg("Alert! Old client stuff lingering; EXTERMINATING");
        rmdir(g_worldPath);
    }

    //Yes yes...
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;    

    bool error = false;

    game.client.initModule(host);
    game.init(false);

    try {
        game.connect(host);
    } catch(Exception e) {
        new DialogBox(guiSystem, "An error occured", e.msg,
                      "Ok", { error = true; });
    }

    auto ingameGui = new InGameGui(guiSystem);

    scope (exit) {
        game.destroy();
        guiSystem.destroy();
    }

    EventAndDrawLoop!false(guiSystem,
                     (float deltaT){ game.render(deltaT);},
                     { return error; });
    return error;
}
