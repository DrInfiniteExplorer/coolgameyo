module materials;

import std.path;


import json;
import log;
import util.filesystem;
import util.util;

struct MaterialInformation {
    string name;
    string fancyName;
    vec3ub color;
    string type;

    float dissolutionConstant; // Or associate this with type? HUERR HUERR HUERR
}

__gshared MaterialInformation[string] g_Materials;

float getDissolutionConstantFromType(string type) {
    switch(type) {
        case "stone": return 0.01; // Dunno random value D:
        default:
    }

    return 0.1; // Use generic something something-value.
}

static void loadMaterial(string filename) {
    auto path = "data/materials/" ~ filename;
    auto name = filename.stripExtension();

    MaterialInformation mat;
    mat.dissolutionConstant = -1;
    loadJSON(path).read(mat);
    mat.name = name;
    mat.fancyName = mat.fancyName.idup; // Since strings loaded from json will ever never release the json file string D:
    mat.type = mat.type.idup;
    if(mat.dissolutionConstant == -1) {
        mat.dissolutionConstant = getDissolutionConstantFromType(mat.type);
    }
    g_Materials[name] = mat;
}

shared static bool materialsLoaded = false;
void loadMaterials() {
    if(materialsLoaded) {
        Log("Trying to load materials twice");
        return;
    }
    materialsLoaded = true;
    try {
        foreach(item ; dir("data/materials")) {
            loadMaterial(item);
        }
    }
    catch(Exception e) {
        LogError("Error trying to load materials: ", e.msg);
    }
}

void saveMaterials() {
    mkdir("data/materials");
    foreach(mat ; g_Materials) {
        auto path = "data/materials/" ~ mat.name ~ ".json";
        encode(mat).saveJSON(path);
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

    auto defaultWidth = 0.2;

    auto nameEdit = new GuiElementLabeledEdit(mainMenu, Rectd(0.3, 0.1, defaultWidth, 0.025), "Material name", "");
    auto fancyEdit = new GuiElementLabeledEdit(mainMenu, Rectd(0.3, nameEdit.bottomOf, defaultWidth, 0.025), "Fancy name   ", "");
    auto typeEdit = new GuiElementLabeledComboBox(mainMenu, Rectd(0.3, fancyEdit.bottomOf, defaultWidth, 0.025), "Material type");
    auto colorEdit = new GuiElementImage(mainMenu, Rectd(0.3, typeEdit.bottomOf+0.025, 0.05, 0.05));
    typeEdit.addItem("sand");
    typeEdit.addItem("soil");
    typeEdit.addItem("stone");
    typeEdit.addItem("ore");
    typeEdit.addItem("liquid");

    MaterialInformation selectedMaterial;
    GuiElementListBox materialsList;

    void saveMaterial() {
        if(selectedMaterial.name == "") return;
        auto name = nameEdit.getText();
        if(name == "") return;
        auto fancyName = fancyEdit.getText();
        auto type = typeEdit.getSelectedItemText();
        if(selectedMaterial.name != name) {
            if(name in g_Materials) {
                new DialogBox(mainMenu, "Error!", "A material with that name already exists!",
                              "cancle", { msg("derp " ~ name ); }
                              );
                return;
            }
            g_Materials.remove(selectedMaterial.name);
            materialsList.removeItem(selectedMaterial.name);
            materialsList.addItem(name);
        }
        selectedMaterial.name = name;
        selectedMaterial.fancyName = fancyName;
        selectedMaterial.type = type;
        g_Materials[name] = selectedMaterial;
    }

    void onMaterialSelect(int idx) {
        if(idx == -1) return;
        saveMaterial();

        auto selected = materialsList.getItemText(idx);
        auto mat = g_Materials[selected];
        nameEdit.setText(mat.name);
        fancyEdit.setText(mat.fancyName);
        typeEdit.selectItem(mat.type);

        auto color = mat.color;
        import graphics.image;
        Image colorImg = Image(null, 1, 1);
        colorImg.setPixel(0, 0, color.toColorUByte());
        colorEdit.setImage(colorImg);
        selectedMaterial = mat;

    }
    materialsList = new GuiElementListBox(mainMenu, Rectd(0.05, 0.05, 0.2, 0.6), 18, &onMaterialSelect);
    loadMaterials();
    foreach(material ; g_Materials) {
        materialsList.addItem(material.name);
    }
    colorEdit.setMouseClickCallback((GuiElement _, GuiEvent.MouseClick mc){
        if(mc.left && mc.down) {
            if(materialsList.getSelectedItemIndex() == -1) return true;
            auto color = selectedMaterial.color;

            import win32.windows;
            COLORREF asRef = color.toColorUInt();
            COLORREF[16] customs;
            foreach(ref clr ; customs) {
                clr = asRef;
            }
            CHOOSECOLOR cc;
            cc.lStructSize = cc.sizeof;
            import util.window;
            cc.hwndOwner = getMainWindow();
            cc.hInstance = null;
            cc.rgbResult = asRef;
            cc.lpCustColors = customs;
            cc.Flags = CC_FULLOPEN | CC_RGBINIT;
            cc.lCustData = 0;
            cc.lpfnHook = null;
            cc.lpTemplateName  = null;
            if(ChooseColor(&cc)) {
                import graphics.image;
                Image colorImg = Image(null, 1, 1);
                colorImg.setPixel(0, 0, cc.rgbResult);
                colorEdit.setImage(colorImg);
                color.fromColor(cc.rgbResult);
                selectedMaterial.color = color;
            }
        }
        return true; //Accept click
    });

    auto newMaterial = new PushButton(mainMenu, Rectd(0.3, colorEdit.bottomOf + 0.05, defaultWidth, 0.025), "New material", (){
        saveMaterial();
        string name = "NewMaterial";
        while(name in g_Materials) {
            name ~= "l";
        }

        MaterialInformation mat;
        mat.name = name;
        mat.fancyName = "fancy" ~ name;
        mat.type = "stone";
        mat.color.set(170,170,160);
        g_Materials[name] = mat;
        materialsList.selectItem(materialsList.addItem(name));
    }); 

    auto saveMaterials = new PushButton(mainMenu, Rectd(0.3, newMaterial.bottomOf + 0.05, defaultWidth, 0.025), "Save materials", (){
        saveMaterial();
        copy("data/materials", "data/oldMaterials");
        rmdir("data/materials");
        saveMaterials();
    }); 


    /*
    auto testImage = new GuiElementImage(materialsList, Rectd(0.5, 0, 0.5, 1));
    import graphics.image;
    testImage.setImage(Image("fonts/courier.tif"));
    */


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




