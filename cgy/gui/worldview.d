



module gui.worldview;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import main;
import gui.mainmenu;
import gui.all;
//import worldparts.sector;
import worldparts.sizes;
import worldparts.block;
import worldparts.sector;
import random.random;
import settings;
import pos;
import worldgen.worldgen;
import util.util;
import util.rect;

auto derp = WorldGenParams.randomSeed.init; //TODO: Why this needed? ;_;

class WorldViewMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    GuiElementImage worldImage;
    GuiElementEditbox worldSize;
    GuiElementEditbox worldSeed;
    uint size = 700;
    uint seed;
    
    WorldGenerator worldGen;
    string mode = "vegetation";

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "World View Menu~~~!", false, false);

 
        worldSize = new GuiElementLabeledEdit(this, Rectd(0.05, 0.05, 0.2, 0.05), "World Size", "16");
        worldSeed = new GuiElementLabeledEdit(this, Rectd(0.05, worldSize.bottomOf, 0.2, 0.05), "World Seed", "8801284210");
        worldSize.setNumbersOnly(true);
        worldSeed.setNumbersOnly(true);
        new GuiElementButton(this, Rectd(worldSize.rightOf, worldSize.topOf, 0.3, worldSize.heightOf), "Generate", &onGenerate);
        new GuiElementButton(this, Rectd(worldSeed.rightOf, worldSeed.topOf, 0.3, worldSeed.heightOf), "Randomize", &onRandomize);

        worldImage = new GuiElementImage(this, Rectd(0.05, worldSeed.bottomOf + 0.1, 0.6, 0.6), false);

        //new GuiElementButton(this, Rectd(vec2d(0.75, 0.05), vec2d(0.2, 0.10)), "Vegetation", &setMode!"vegetation");
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.05), vec2d(0.2, 0.10)), "Vegetation", &onVegetation);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);
    }
    
    override void destroy() {
        super.destroy();
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }
    
    void initWorld() {
        WorldGenParams params;
        params.worldSize = size;
        params.randomSeed = seed;
        worldGen = new WorldGenerator;
        worldGen.init(params, null);
    }
    
    void onGenerate() {
        collectException!ConvException(to!uint(worldSize.getText()), size);
        worldSize.setText(to!string(size));
        collectException!ConvException(to!uint(worldSeed.getText()), seed);
        worldSeed.setText(to!string(seed));
        initWorld();
        updateMap();
    }
    void onRandomize() {
        auto randSource = new RandSourceUniform(cast(uint)utime());
        auto seed = randSource.get!uint(uint.min, uint.max);
        worldSeed.setText(to!string(seed));
    }
    
    void setMode(string newMode) {
        mode = newMode;
        updateMap();
    }
    
    void onVegetation() {
        mode = "vegetation";
        updateMap();
    }
    
    void updateMap() {
        switch(mode) {
            case "vegetation":
                updateVegetation();
                break;
            default:
        }
    }


    void updateVegetation() {
        double[4] colorize(double t) {
            //writeln(t);
            t = max(0.5, t);
            t = (t - 0.5) * 2.0;
            auto c = [
                vec3d(0.0, 0.0, 0.0),
                vec3d(0.0, 0.25, 0.0),
                vec3d(0.0, 0.5, 0.0),
                vec3d(0.0, 0.75, 0.0), 
                vec3d(0.0, 1.0, 0.0),
                ];
            auto v = CatmullRomSpline(t, c);
            return [v.X, v.Y, v.Z, 0];
        }
        auto hs = size / 2.0;
        //*
        auto img = toImage(worldGen.vegetationMap,
                           -hs * SectorSize.x, -hs * SectorSize.y
                           , hs* SectorSize.x, hs * SectorSize.y,
                           256, 256, 0, 100, &colorize);
        /*///
        auto img = toImage(worldGen.vegetationMap,
                           -hs * SectorSize.x, -hs * SectorSize.y
                           , hs* SectorSize.x, hs * SectorSize.y,
                           256, 256, 0, 100, null);
        //*/
        worldImage.setImage(img.toGLTex(0));
        worldImage.setSize(img.imgWidth, img.imgHeight);
    }
    
}

     

