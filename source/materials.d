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
    int tileStrength = 5; // Hurr durr random value.

    float talusConstant;
    float dissolutionConstant; // Or associate this with type? HUERR HUERR HUERR
}

__gshared MaterialInformation[string] g_materials;

float getDissolutionConstantFromType(string type) {
    switch(type) {
        case "stone": return 0.01; // Dunno random value D:
        default:
    }
    return 0.1; // Use generic something something-value.
}
float getTalusConstantFromType(string type) {
    return 3; // Use generic something something-value.
}

static void loadMaterial(string filename) {
    auto path = "data/materials/" ~ filename;
    auto name = filename.stripExtension();

    MaterialInformation mat;
    mat.dissolutionConstant = -1;
    mat.talusConstant = -1;
    loadJSON(path).read(mat);
    mat.name = name;
    mat.fancyName = mat.fancyName.idup; // Since strings loaded from json will ever never release the json file string D:
    mat.type = mat.type.idup;    
    if(mat.dissolutionConstant == -1) {
        mat.dissolutionConstant = getDissolutionConstantFromType(mat.type);
    }
    if(mat.talusConstant == -1) {
        mat.talusConstant= getTalusConstantFromType(mat.type);
    }
    g_materials[name] = mat;
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
    foreach(mat ; g_materials) {
        auto path = "data/materials/" ~ mat.name ~ ".json";
        encode(mat).saveJSON(path);
    }
}


void MaterialEditor() {
    import main;

    import graphics.ogl;
    import derelict.sdl2.sdl;
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
            if(name in g_materials) {
                new DialogBox(mainMenu, "Error!", "A material with that name already exists!",
                              "cancle", { msg("derp " ~ name ); }
                              );
                return;
            }
            g_materials.remove(selectedMaterial.name);
            materialsList.removeItem(selectedMaterial.name);
            materialsList.addItem(name);
        }
        selectedMaterial.name = name;
        selectedMaterial.fancyName = fancyName;
        selectedMaterial.type = type;
        g_materials[name] = selectedMaterial;
    }

    void onMaterialSelect(int idx) {
        if(idx == -1) return;
        saveMaterial();

        auto selected = materialsList.getItemText(idx);
        auto mat = g_materials[selected];
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
    foreach(material ; g_materials) {
        materialsList.addItem(material.name);
    }
    colorEdit.setMouseClickCallback((GuiElement _, MouseClick mc){
        if(mc.left && mc.down) {
            if(materialsList.getSelectedItemIndex() == -1) return true;
            auto color = selectedMaterial.color;
            import windows;
            COLORREF asRef = color.toColorUInt();
            COLORREF[16] customs;
            foreach(ref clr ; customs) {
                clr = asRef;
            }
            CHOOSECOLORA cc;
            cc.lStructSize = cc.sizeof;
            import util.window;
            cc.hwndOwner = getMainWindow();
            cc.hInstance = null;
            cc.rgbResult = asRef;
            cc.lpCustColors = customs.ptr;
            cc.Flags = CC_FULLOPEN | CC_RGBINIT;
            cc.lCustData = 0;
            cc.lpfnHook = null;
            cc.lpTemplateName  = null;
            if(ChooseColorA(&cc)) {
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
        while(name in g_materials) {
            name ~= "l";
        }

        MaterialInformation mat;
        mat.name = name;
        mat.fancyName = "fancy" ~ name;
        mat.type = "stone";
        mat.color.set(170,170,160);
        g_materials[name] = mat;
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


    EventAndDrawLoop!true(guiSystem, null);
}




