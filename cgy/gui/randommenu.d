



module gui.randommenu;

import std.conv;

import main;
import gui.mainmenu;
import gui.all;
import random.random;
import random.randsource;
import random.valuemap;
import random.xinterpolate;
import random.modmultadd;
import random.catmullrom;
import random.permutation;
import random.gradientnoise;
import settings;
//import worldgen.worldgen;
import worldgen.newgen;
import util.util;
import util.rect;

auto derp = WorldGenParams.randomSeed.init; //TODO: Why this needed? ;_;

class RandomMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    GuiElementImage valueImage;
    GuiElementSimpleGraph!double valueGraph, sliceGraph;
    
    ValueSource source;
    
    uint seed;
    double sliceValue = 0.0;
    
    enum graphWidth = 16.0;
    enum pixels = 256;        
    enum samples = 665;            
    
    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        seed = derp;
        
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "Randomness experiment Menu~~~!", false, false);

        valueImage = new GuiElementImage(this, Rectd(0.05, 0.1, 0.6, 0.3), false);
        valueGraph = new typeof(valueGraph)(this, Rectd(0.05, 0.45, 0.6, 0.10), false);
        sliceGraph = new typeof(sliceGraph)(this, Rectd(0.05, 0.45, 0.6, 0.10), false);
        
        new GuiElementSlider!double(this, Rectd(0.05, 0.8, 0.4, 0.1), sliceValue, 0.0, 10.0, &onSliceSlider);

        new GuiElementButton(this, Rectd(vec2d(0.75, 0.1), vec2d(0.2, 0.10)), "map-vnoise", &onMapVNoise);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.25), vec2d(0.2, 0.10)), "perm-vnoise", &onPermVNoise);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.40), vec2d(0.2, 0.10)), "perm-gnoise", &onPermGNoise);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);
    }
    
    override void destroy() {
        super.destroy();
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }    
    
    void onMapVNoise() {
        makeNoise!("map", true, true)();
    }
    void onPermVNoise() {
        makeNoise!("permv", true, true)();
    }
    void onPermGNoise() {
        makeNoise!("permg", true, true)();
    }
    
    void onSliceSlider(double value) {
        sliceValue = value;
        fill!true();
    }
    
    void makeNoise(string type, bool CosInter, bool ModMult)() {
        auto randSource = new RandSourceUniform(seed);
        static if (type == "map") {
            auto source = new ValueMap2Dd();
            source.fill(randSource, samples, samples);
        } else static if (type == "permv"){
            alias PermMap!(samples) asd;
            auto source = new asd(randSource);
        } else static if (type == "permg"){
            auto source = new GradientNoise!()(samples, randSource);
        }
        
        static if (type != "permg") {
            static if (CosInter) {
                auto vnoise = new CosInterpolation(source);
            } else {
                auto vnoise = source;
            }
        } else {
            auto vnoise = source;
        }
        

        static if (ModMult) {
            auto mod = new ModMultAdd!(0.5, 0.5)(vnoise);
        } else {
            auto mod = vnoise;
        }
        //toImage(mod, 0, 0, 256, 256, 256u, 256u, 0, 1);
        
        //auto img = toImage(mod, 0, 0, samples, samples, pixels, pixels, 0, 1);
        //valueGraph.setSize(graphHeightPx);
        this.source = mod;
        fill();
    }
    
    
    
    private void fill(bool onlySlice = false)() {
        if (source is null) {
            return;
        }
        static if (!onlySlice) {
            double[4] colorize(double t) {
                auto c = [
                    vec3d(0.0, 0.0, 0.0),
                    vec3d(1.0, 0.0, 0.0),
                    vec3d(1.0, 0.0, 0.0),
                    vec3d(1.0, 0.0, 0.0),
                    vec3d(1.0, 0.0, 0.0),
                    vec3d(0.0, 1.0, 0.0),
                    vec3d(0.0, 1.0, 0.0),
                    vec3d(0.0, 1.0, 0.0),
                    vec3d(0.0, 0.0, 1.0),
                    vec3d(0.0, 0.0, 1.0),
                    vec3d(0.0, 0.0, 1.0),
                    vec3d(0.0, 0.0, 1.0),
                    ];
                auto v = CatmullRomSpline(t, c);
                return [v.X, v.Y, v.Z, 0];
            }
            //auto img = toImage(source, 0, 0, graphWidth, graphWidth, pixels, pixels, 0, 1, &colorize);
            auto img = toImage(source, 0, 0, graphWidth, graphWidth, pixels, pixels, 0, 1, null);
            valueImage.setImage(img.toGLTex(0));
            valueImage.setSize(img.imgWidth, img.imgHeight);
        }
                
        double[] graph, slice;
        graph.length = pixels;
        slice.length = pixels;
        foreach(idx; 0 .. graph.length) {
            double d = graphWidth / to!double(pixels);
            double dx = d * to!double(idx);
            static if (!onlySlice) {
                graph[idx] = source.getValue(dx);
            }
            slice[idx] = source.getValue(dx, sliceValue);
        }
        
        static if (!onlySlice) {        
            auto r = valueGraph.getAbsoluteRect();
            r.start.Y = valueImage.getAbsoluteRect.getBottom() + 10;
            valueGraph.setAbsoluteRect(r);
            valueGraph.setData(graph, 0, 1);

            r.start.Y = r.getBottom() + 10;
            sliceGraph.setAbsoluteRect(r);
        }        
        sliceGraph.setData(slice, 0, 1);
    }
}

     

