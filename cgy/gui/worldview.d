



module gui.worldview;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import main;
import gui.mainmenu;
import gui.all;
import graphics.image;

import worldparts.sizes;
import worldparts.block;
import worldparts.sector;
import random.random;
import pos;
import settings;
import statistics;
import worldgen.worldgen;
import util.util;
import util.rect;

auto derp = WorldGenParams.randomSeed.init; //TODO: Why this needed? ;_;

class MapImage : GuiElementImage {
    WorldGenerator worldGen;
    Image img;
    uint imgGl;

    vec2d viewPos;
    double zoom = 1.0;
    
    string mode = "vegetation";
    
    this(GuiElement parent, Rectd relative, WorldGenerator gen) {
        super(parent, relative, 0);
        worldGen = gen;
    }
    
    override void setSize(uint width, uint height) {
        img = Image(null, width/2, height/2);
        super.setSize(width, height);
    }
    
    void setGenerator(WorldGenerator gen) {
        worldGen = gen;
    }
    
    void setMode(string newMode) {
        mode = newMode;
        updateMap();
    }
    
    void setZoom(double z) {
        zoom = z;
    }
    void setViewPos(vec2d pos) {
        viewPos = pos;
    }
    
    void updateMap() {
        switch(mode) {
            case "elevation":
                updateElevation();
                break;
            case "temperature":
                updateTemperature();
                break;
            case "vegetation":
                updateVegetation();
                break;
            case "rainfall":
                updateRainfall();
                break;
            case "drainage":
                updateDrainage();
                break;
            case "wierdness":
                updateWierdness();
                break;
            default:
        }
    }
    
    private void generateMap(double delegate(TilePos p) getVal, ubyte[4] delegate(double) colorize) {
        writeln(to!string(viewPos.vec3()));
        int width = absoluteRect.size.X / 2;
        int halfWidth = width / 2;
        int height = absoluteRect.size.Y / 2;
        int halfHeight = height / 2;
        
        auto derpX = SectorSize.x / to!double(width);
        auto derpY = SectorSize.y / to!double(height);
        foreach(x ; 0 .. width) {
            auto xx = x - halfWidth;
            auto px = xx * derpX;
            foreach(y ; 0 .. height) {
                auto  yy = y - halfHeight;
                auto py = yy * derpY;
                auto p = util.util.convert!int(vec3d(px, py, 0) / zoom + viewPos.vec3);                
                
                auto val = getVal(TilePos(p)); 
                img.setPixel(x, y, colorize(val));
                //img.setPixel(x, y, [0,0,0,0]);
            }
        }
        imgGl = img.toGLTex(imgGl);
        setImage(imgGl);
    }

    void updateElevation() {
    }
    void updateTemperature() {
    }
    void updateVegetation() {
        mixin(Time!"writeln(\"Time to make map: \", usecs);");
        auto colors = [
            vec3d(0.0, 0.0, 0.0),
            vec3d(0.0, 0.25, 0.0),
            vec3d(0.0, 0.5, 0.0),
            vec3d(0.0, 0.75, 0.0), 
            vec3d(0.0, 1.0, 0.0),
            ];
        ubyte[4] colorize(double t) {
            t = max(0.5, t);
            t = (t - 0.5) * 2.0;
            
            auto v = CatmullRomSpline(t, colors);
            //*
            return makeStackArray(
                cast(ubyte)(v.X * 255),
                cast(ubyte)(v.Y * 255),
                cast(ubyte)(v.Z * 255),
                cast(ubyte)0);
        }
        
        generateMap((TilePos p){ return worldGen.getVegetation01(p);}, &colorize);
    }
    void updateRainfall() {
    }
    void updateDrainage() {
    }
    void updateWierdness() {
    }
     
    
    //vec2i dragPos;
    bool dragging = false;
    override GuiEventResponse onEvent(GuiEvent e){
        
        if(e.type == GuiEventType.MouseClick) {
            auto m = e.mouseClick;
            if (m.left) {
                dragging = m.down;
                if(m.down) {
                //    dragPos = m.pos;
                }
            }
            if (m.wheelUp && m.down) {
                zoom *= 1.1;
                updateMap();
            }
            if (m.wheelDown && m.down) {
                zoom *= (1.0/1.1);
                updateMap();
            }
        }
        else if(e.type == GuiEventType.MouseMove) {
            auto m = e.mouseMove;
            if (dragging) {
                viewPos += util.util.convert!double(m.delta) * (-0.5/zoom);
                updateMap();
            }
        }
        
        return super.onEvent(e);
    }


}

class WorldViewMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    MapImage worldImage;
    
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

        worldImage = new MapImage(this, Rectd(0.05, worldSeed.bottomOf + 0.1, 0.6, 0.6), null);
        worldImage.setSize(256, 256);

        auto a = new GuiElementButton(this, Rectd(vec2d(0.75, 0.05), vec2d(0.2, 0.10)), "Elevation", &setMode!"elevation");
        a = new GuiElementButton(this, Rectd(vec2d(0.75, a.bottomOf), vec2d(0.2, 0.10)), "Temperature", &setMode!"temperature");
        a = new GuiElementButton(this, Rectd(vec2d(0.75, a.bottomOf), vec2d(0.2, 0.10)), "Vegetation", &setMode!"vegetation");
        a = new GuiElementButton(this, Rectd(vec2d(0.75, a.bottomOf), vec2d(0.2, 0.10)), "Rainfall", &setMode!"rainfall");
        a = new GuiElementButton(this, Rectd(vec2d(0.75, a.bottomOf), vec2d(0.2, 0.10)), "Drainage", &setMode!"drainage");
        a = new GuiElementButton(this, Rectd(vec2d(0.75, a.bottomOf), vec2d(0.2, 0.10)), "Wierdness", &setMode!"wierdness");
        
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);
        
        onGenerate();
    }
    
    override void destroy() {
        super.destroy();
    }
    
    void setMode(string mode)() {
        worldImage.setMode(mode);
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
        worldImage.setGenerator(worldGen);
        worldImage.setZoom( 1.0 / size);
        worldImage.setViewPos(vec2d(0.5 / size, 0.5 / size));
        worldImage.updateMap();
    }
    
    void onGenerate() {
        collectException!ConvException(to!uint(worldSize.getText()), size);
        worldSize.setText(to!string(size));
        collectException!ConvException(to!uint(worldSeed.getText()), seed);
        worldSeed.setText(to!string(seed));
        initWorld();
    }
    void onRandomize() {
        auto randSource = new RandSourceUniform(cast(uint)utime());
        auto seed = randSource.get!uint(uint.min, uint.max);
        worldSeed.setText(to!string(seed));
    }    
        
}

     

