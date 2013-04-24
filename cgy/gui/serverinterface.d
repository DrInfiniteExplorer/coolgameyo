module gui.serverinterface;

import std.conv : to;
import core.cpuid : threadsPerCPU;

import game;
import globals : g_worldPath;
import gui.all;

import log;
import main : EventAndDrawLoop;
import util.filesystem;
import util.memory : getMemoryUsage;
import util.rect;
import util.traits;
import util.util;
import worldstate.block : getBlockMemorySize;


immutable SAMPLE_LIMIT = 256;

__gshared ulong[SAMPLE_LIMIT] memorySamples;
__gshared ulong[SAMPLE_LIMIT] memoryBlockSamples;
__gshared float[SAMPLE_LIMIT] CPUSamples;

shared static this() {
    memorySamples[] = 0;
    memoryBlockSamples[] = 0;
    CPUSamples[] = 0.0;
}

// Should be elsewhere
__gshared ulong lastUs = 0;
__gshared ulong lastTotal = 0;
float getCPUUtilization() {

    import windows : FILETIME, GetProcessTimes, GetCurrentProcess;
    FILETIME creation, exit;
    FILETIME kernel;
    FILETIME user;
    GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel, &user);

    ulong ulKernel = *cast(ulong*)&kernel;
    ulong ulUser = *cast(ulong*)&user;

    ulong total = ulKernel + ulUser;

    ulong diff = total - lastTotal;
    lastTotal = total;

    ulong nowUs = utime();
    ulong diffUs = (nowUs - lastUs) * threadsPerCPU;
    lastUs = nowUs;

    //filetime == X * 100ns = X * 0.1us

    ulong processInUs = diff / 10;

    float percentage = cast(float)processInUs / cast(float)diffUs;
    return percentage;
}

void sampleMemory() {
    foreach(idx ; 0 .. SAMPLE_LIMIT-1) {
        memorySamples[idx] = memorySamples[idx+1];
    }
    memorySamples[$-1] = getMemoryUsage();

    foreach(idx ; 0 .. SAMPLE_LIMIT-1) {
        memoryBlockSamples[idx] = memoryBlockSamples[idx+1];
    }
    memoryBlockSamples[$-1] = getBlockMemorySize();
    
}

void sampleCPU() {
    foreach(idx ; 0 .. SAMPLE_LIMIT-1) {
        CPUSamples[idx] = CPUSamples[idx+1];
    }
    CPUSamples[$-1] = getCPUUtilization();
}

void startServer() {

    if(!exists(g_worldPath)) {
        msg("Alert! Tried to gui.serverinterface.d:startServer() without a " ~ g_worldPath ~ "!");
        return;
    }

    Game game;
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
        game.getScheduler.saveGame();
    });

    string fullMsg = "";
    auto handleMsg = (string s) {
        synchronized(gameLog) {
            fullMsg ~= s;
            if(s == "\n") {
                gameLog.addItem(fullMsg);
                fullMsg = null;
                while(gameLog.getItemCount() > 50) {
                    gameLog.removeItem(0);
                }
            }
        }
    };
    logCallback = handleMsg;

    auto now = mstime();
    auto sampleIntervall = 1000; // 1000 ms



    game = new Game(true);
    game.loadGame();
    import util.strings;
    StringBuilder tmpString;
    EventAndDrawLoop!true(guiSystem,  DownwardDelegate((float){
        if(now + sampleIntervall < mstime()) {
            now = mstime();
            //Sample cpu and memory information
            sampleMemory();
            sampleCPU();
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

            synchronized(game) {
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





