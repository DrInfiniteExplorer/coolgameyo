module materials;

import std.path;
import json;
import util.filesystem;
import util.util;

struct MaterialInformation {
    string name;
    string fancyName;
    vec3ub color;
    string type;
}

__gshared MaterialInformation[string] g_Materials;


static void loadMaterial(string filename) {
    auto path = "data/materials/" ~ filename;
    auto name = filename.stripExtension();

    MaterialInformation mat;
    loadJSON(path).read(mat);
    mat.name = name;
    g_Materials[name] = mat;
}

void loadMaterials() {
    foreach(item ; dir("data/materials")) {
        loadMaterial(item);
    }
}


void MaterialEditor() {
    import main;
    //import derelict.opengl.gl;
    import graphics.ogl;
    import derelict.sdl.sdl;
    import gui.all;
    import util.rect;

    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
    auto mainMenu = new GuiElementWindow(guiSystem, Rectd(0,0,1,1), "Material Editor", false, false);

    loadMaterials();

    // Main loop etc
    long then;
    long now, nextTime = utime();
    bool exit = false;
    SDL_Event event;
    GuiEvent guiEvent;
    while (!exit) {
        while (SDL_PollEvent(&event)) {
            guiEvent.eventTimeStamp = now / 1_000_000.0;
            exit = handleSDLEvent(event, guiEvent, guiSystem);
        } //Out of sdl-messages

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = cast(float)diff / 1_000_000.0f;            
        then = now;

        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();            

        SDL_GL_SwapBuffers();

        SDL_WM_SetCaption( "CoolGameYo!\0", "CoolGameYo!\0");
    }

    guiSystem.destroy();
}




