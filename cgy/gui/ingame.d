module gui.ingame;


import derelict.sdl.sdl;

import gui.all;
import gui.debuginfo;
import gui.ingame_first;
import gui.ingame_third;
import unit;


class InGameGui : GuiElement {

    //GuiSystem guiSystem;

    FpsMode fpsMode;
    PlanningMode planningMode;
    bool usePlanningMode = true;

    this(GuiSystem parent) {

        super(parent);
        setRelativeRect(Rectd(0.0, 0.0, 1.0, 1.0));

        guiSystem.addHotkey(SDLK_F4, &toggleDebugInfo);
        guiSystem.addHotkey(SDLK_TAB, &toggleMode);

        planningMode = new PlanningMode(this);
        fpsMode = new FpsMode(this);

        activateMode(usePlanningMode);
    }

    override void destroy() {
        fpsMode.destroy();
        planningMode.destroy();
        super.destroy();
    }


    DebugInfo debugInfo;
    void toggleDebugInfo() {
        if(debugInfo is null) {
            debugInfo = new DebugInfo(this);
        } else {
            debugInfo.setVisible(!debugInfo.isVisible);
        }
    }

    void toggleMode() {
        usePlanningMode = !usePlanningMode;
        activateMode(usePlanningMode);
    }

    void activateMode(bool usePlanning) {
        GuiEventDump dump = fpsMode;
        if(usePlanning) {
            dump = planningMode;
        }
        guiSystem.setEventDump(null);
        guiSystem.setEventDump(dump);
    }


    override void tick(float dTime) {
        super.tick(dTime);
    }


}
