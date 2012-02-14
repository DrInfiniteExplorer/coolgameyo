



module gui.worldview;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import main;
import gui.mainmenu;
import gui.all;
import graphics.image;

import world.sizes;
import world.block;
import world.sector;
import random.random;
import random.catmullrom;
import random.randsource;
import pos;
import settings;
import statistics;
//import worldgen.worldgen;
import worldgen.newgen;
import util.util;
import util.rect;

auto derp = WorldGenParams.randomSeed.init; //TODO: Why this needed? ;_;

class MapImage : GuiElementImage {
    WorldGenerator worldGen;
    Image img;
    uint imgGl;

    vec2d viewPos;
    double scale = 1.0; //Pixel to tile-ratio
    int size;
    
    string mode = "vegetation";
    
    GuiElementText infoText;
    
    
    this(GuiElement parent, Rectd relative, WorldGenerator gen) {
        super(parent, relative, 0);
        auto textStart = vec2d(0);
        infoText = new GuiElementText(this, textStart, "");
        worldGen = gen;
    }
    
    override void setSize(uint width, uint height) {
        img = Image(null, width / 2, height / 2);
        super.setSize(width, height);
        auto rect = infoText.getAbsoluteRect;
        rect.start.Y = absoluteRect.getBottom;
        infoText.setAbsoluteRect(rect);
    }
    
    void setGenerator(WorldGenerator gen) {
        worldGen = gen;
    }
    
    void setMode(string newMode) {
        mode = newMode;
        updateMap();
    }
    
    void setSize(int s) {
        size = s;
        scale = to!double(s)*SectorSize.x * 2 / absoluteRect.getWidth;
        viewPos = vec2d(0, 0);
    }
    
    void updateMap() {
        
        auto str = text("Visible tiles: ", scale*SectorSize.x, " Pos: ", viewPos);
        infoText.setText(str);
        
        
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
            case "humidity":
                updateHumidity();
                break;
            case "wierdness":
                updateWierdness();
                break;
            default:
        }
    }
    
    private void generateMap(double delegate(TilePos p) getVal, ubyte[4] delegate(double) colorize) {
        int pixWidth = absoluteRect.size.X / 2;
        int halfWidth = pixWidth / 2;
        int pixHeight = absoluteRect.size.Y / 2;
        int halfHeight = pixHeight / 2;
        double min = double.max;
        double max = -double.max;
        
        foreach(x ; 0 .. pixWidth) {
            auto xx = x - halfWidth;
            foreach(y ; 0 .. pixHeight) {
                auto yy = y - halfHeight;
                auto pos = vec3d(xx, yy, 0) * scale + viewPos.vec3;
                auto p = util.util.convert!int(pos);

                auto val = getVal(TilePos(p)); 
                if (val < min) min = val;
                if (val > max) max = val;
                img.setPixel(x, y, colorize(val));
                //img.setPixel(x, y, [0,0,0,0]);
            }
        }
        imgGl = img.toGLTex(imgGl);
        setImage(imgGl);
        writeln(text("min ", min, " max ", max));
    }
    
    ubyte[4] colorize(T, T z, T o)(double t) {
        auto v = lerp!(vec3d, z, o)(t);
        return makeStackArray(
            cast(ubyte)(v.X * 255),
            cast(ubyte)(v.Y * 255),
            cast(ubyte)(v.Z * 255),
            cast(ubyte)0);
    }
    
    void updateElevation() {

        ubyte[4] colorize(double t) {
            auto c = [
                vec3d(0.0, 0.0, 0.0),
                vec3d(0.0, 0.1, 0.0),
                vec3d(0.1, 0.9, 0.1),
                vec3d(0.9, 0.9, 0.9),
                vec3d(0.9, 0.9, 0.9),
                vec3d(1.0, 1.0, 1.0),
            ];
            auto v = CatmullRomSpline(t, c);
            return makeStackArray(
                                  cast(ubyte)(clamp(v.X, 0, 1) * 255),
                                  cast(ubyte)(clamp(v.Y, 0, 1) * 255),
                                  cast(ubyte)(clamp(v.Z, 0, 1) * 255),
                                  cast(ubyte)0);
        }
        generateMap((TilePos p){ return worldGen.getHeight01(p);}, &colorize);
    }
    void updateTemperature() {
    }
    void updateVegetation() {
        mixin(Time!"writeln(\"Time to make map: \", usecs);");
        //mixin makeColorize!(vec3d(0,0,0), vec3d(0,1,0));
        //generateMap((TilePos p){ return worldGen.getVegetation01(p);}, &colorize);
        //generateMap((TilePos p){ return worldGen.getVegetation01(p);}, &colorize!(vec3d, vec3d(0,0,0), vec3d(1,1,1)));
    }
    void updateHumidity() {
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
                scale *= (1.0/1.1);
                updateMap();
            }
            if (m.wheelDown && m.down) {
                scale *= 1.1;
                scale = min(scale, 10000000.0);
                updateMap();
            }
        }
        else if(e.type == GuiEventType.MouseMove) {
            auto m = e.mouseMove;
            if (dragging) {
                viewPos -= util.util.convert!double(m.delta) * scale * 0.5;
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
        a = new GuiElementButton(this, Rectd(vec2d(0.75, a.bottomOf), vec2d(0.2, 0.10)), "Humidity", &setMode!"humidity");
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
        params.worldDiameter = size;
        params.randomSeed = seed;
        worldGen = new WorldGenerator;
        worldGen.init(params, null);
        worldImage.setGenerator(worldGen);
        worldImage.setSize(size);
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

     

