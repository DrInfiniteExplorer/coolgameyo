module gui.serverinterface;

import std.conv : to;
import core.sync.mutex;

import game : game;
import globals : g_worldPath;
import gui.all;
import gui.debuginfo;

import cgy.logger.log;
import main : EventAndDrawLoop;
import cgy.util.filesystem;
import cgy.util.rect;
import cgy.util.traits;
import cgy.util.util;
import scheduler : scheduler;



void startServer() {

    if(!exists(g_worldPath)) {
        msg("Alert! Tried to gui.serverinterface.d:startServer() without a " ~ g_worldPath ~ "!");
        return;
    }

    GuiSystem guiSystem;
    guiSystem = new GuiSystem;

    GuiElementSimpleGraph!ulong memoryGraph;
    GuiElementSimpleGraph!float CPUGraph;

    memoryGraph = new typeof(memoryGraph)(guiSystem, Rectd(0.1, 0, 0.6, 0.25), false);
    auto memoryBlockGraph = new typeof(memoryGraph)(guiSystem, memoryGraph.getRelativeRect, true);
    memoryBlockGraph.setColor(vec3f(0, 1, 0));
    auto memoryTextMB = new GuiElementText(memoryGraph, vec2d(0, memoryGraph.topOf), "");
    auto memoryTextKB = new GuiElementText(memoryGraph, vec2d(0, memoryTextMB.bottomOf), "");
    auto memoryTextDelta = new GuiElementText(memoryGraph, vec2d(0, memoryTextKB.bottomOf), "");

    CPUGraph = new typeof(CPUGraph)(guiSystem, Rectd(memoryGraph.leftOf, memoryGraph.bottomOf, memoryGraph.widthOf, memoryGraph.heightOf), false);
    auto CPUText = new GuiElementText(CPUGraph, vec2d(0, 0), "");

    auto playerList = new GuiElementListBox(guiSystem, Rectd(memoryGraph.rightOf, memoryGraph.topOf, 1.0 - memoryGraph.rightOf, CPUGraph.bottomOf),
                                            guiSystem.getFont.glyphHeight, null);

    auto gameLog = new GuiElementListBox(guiSystem, Rectd(CPUGraph.leftOf, CPUGraph.bottomOf, CPUGraph.widthOf, 0.2),
                                         guiSystem.getFont.glyphHeight+15, null);

    auto buttonBar = new PushButton(guiSystem, Rectd(0.025, 0.05, 0.05, 0.05), "Save!", {
        scheduler.saveGame();
    });

    string fullMsg = "";
    auto handleMsg = (string s) {
        synchronized(gameLog) {
            fullMsg ~= s;
            if(s == "\n") {
                gameLog.insertItem(fullMsg, 0);
                fullMsg = null;
                while(gameLog.getItemCount() > 50) {
                    gameLog.removeItem(50);
                }
            }
        }
    };
    setLogCallback(handleMsg);

    auto now = mstime();
    auto sampleIntervall = 1000; // 1000 ms


    auto mutex = new Mutex();

    game.init(true);
    game.loadGame();
    import cgy.util.strings;
    StringBuilder tmpString;
    EventAndDrawLoop!true(guiSystem,  DownwardDelegate((float){
        if(now + sampleIntervall < mstime()) {
            now = mstime();
            //Sample cpu and memory information
            sampleEverything();
            auto memMax = cast(ulong)(reduce!max(memorySamples)*1.1);
            memoryGraph.setData(memorySamples, 0, memMax);
            memoryBlockGraph.setData(memoryBlockSamples, 0, memMax);
            //memoryPrivateGraph
            auto mem = memorySamples[$-1];
            auto megabytes = mem / 1024;
            auto kilobytes = mem % 1024;
            auto deltaKB = mem - memorySamples[$-2];
            memoryTextMB.format(   "MB:    %4d", cast(int)megabytes);
            memoryTextKB.format(   "KB:    %4d", cast(int)kilobytes);
            memoryTextDelta.format("Delta: %4d", cast(int)deltaKB);

            CPUGraph.setData(CPUSamples, 0.0, 1.0);
            CPUText.format("CPU:%5.1f%%", 100.0f*CPUSamples[$-1]);

            synchronized (mutex) {
                playerList.setItemCount(game.players.length);
                int idx = 0;
                foreach(name, player ; game.players) {
                    if(player.unit is null) continue;
                    auto pos = player.unit.pos.value.convert!float;
                    tmpString.write("%16s   %.2f, %.2f, %.2f", name, pos.x, pos.y, pos.z);
                    playerList.setItemText(idx, tmpString.str);
                }
            }
        }
    }));

    game.destroy();
    guiSystem.destroy();

}





