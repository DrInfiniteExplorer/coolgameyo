



module gui.randommenu;

import std.algorithm;
import std.conv;
import std.stdio;

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

import graphics.image;
import graphics._2d.line;
import util.voronoi.voronoi;
import util.voronoi.fortune;
import util.voronoi.wrapper;

auto derp = WorldGenParams.randomSeed.init; //TODO: Why this needed? ;_;

class RandomMenu : GuiElementWindow {
    GuiElement guiSystem;
    MainMenu main;

    Lines[] lines;
    GuiElementImage img;
    
    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "Randomness experiment Menu~~~!", false, false);

        img = new GuiElementImage(this, Rectd(0, 0, 1, 1));

        new GuiElementButton(this, Rectd(vec2d(0.75, 0.1), vec2d(0.2, 0.10)), "VORO-FUCKING-NOI!", &onMapVNoise);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.25), vec2d(0.2, 0.10)), "derp", &onPermVNoise);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.40), vec2d(0.2, 0.10)), "pred", &onPermGNoise);
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.55), vec2d(0.2, 0.10)), "Back", &onBack);


    }
    
    override void destroy() {
        super.destroy();
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }    

    override void render() {
        super.render();
        foreach(line ; lines) {
            renderLines(line);
        }
    }
    
    int c = 4;
    void onMapVNoise() {

        lines = null;

        //Derp implement a lattice-based voronoi-point-query, and
        //implement a class containing both that one and VoronoiPoly
        //of lattice-data, and make it look like it is both.

        enum gridSize = 50;
        auto voronoi = new VoronoiWrapper(gridSize, gridSize, 880128);
        voronoi.setScale(vec2d(800, 600));

        Image img = Image(null, 800, 600);
        foreach(y ; 0 .. 600) {
            foreach(x ; 0 .. 800) {

                int id = voronoi.identifyCell(vec2d(x, y));
                enum v = 2^^24;

                double ratio = (cast(double)id) / (gridSize*gridSize);
                int c = v - (cast(int)(cast(double)v * ratio));
                char* ptr = cast(char*)&c;
                char r = ptr[0];
                char g = ptr[1];
                char b = ptr[2];
                img.setPixel(x, y, r, g ,b);
            }
        }
        this.img.setImage(img.toGLTex(this.img.image));

        foreach(site ; voronoi.poly.sites) {
            foreach(he ; site.halfEdges) {
                auto a = he.getStartPoint();
                auto b = he.getEndPoint();
                if(a !is null ) {
                    vec2d _b;
                    bool c = true;
                    if(b !is null) {
                        _b = b.pos;
                    } else {
                        c = false;
                        BREAKPOINT;
                        //_b = a.pos + he.dir * dirLength;
                    }
                    auto _a = a.pos;
                    //_a += (site.pos - _a ).normalize() * 0.2;
                    //_b += (site.pos - _b).normalize() * 0.2;
                    //_a.Y *= -1;
                    //_b.Y *= -1;
                    Lines line;
                    line.setLines(absoluteRect, [_a, _b], c ? vec3f(0, 0, 0) : vec3f(0, 0, 1), vec2d(0, 0), vec2d(800, 600));
                    lines ~= line;
                }
            }
        }

        /*

        auto voronoi = new Voronoi(c, c);

        voronoi.cutDiagram(vec2d(-1, -1), vec2d(c+1, c+1));

        c++;
        enum borderSize = 2;
        enum dirLength = 0.4;
        vec2d border = vec2d(borderSize);
        vec2d[] vertPairs;
        double minX = double.max;
        double maxX = -minX;
        double minY = minX;
        double maxY = maxX;
        foreach(vert ; voronoi.vertices) {
            auto pt = vert.pos;
            minX = min(pt.X, minX);
            minY = min(pt.Y, minY);
            maxX = max(pt.X, maxX);
            maxY = max(pt.Y, maxY);
        }
        minX -= borderSize;
        minY -= borderSize;
        maxX += borderSize;
        maxY += borderSize;

        
        foreach(edge ; voronoi.edges) {
            auto a = edge.halfLeft.vertex;
            auto b = edge.halfRight.vertex;
            if(a !is null ) {
                vec2d _b;
                bool c = true;
                if(b !is null) {
                    _b = b.pos;
                } else {
                    c = false;
                    _b = a.pos + edge.dir * dirLength;
                }
                auto _a = a.pos;
                //_a.Y *= -1;
                //_b.Y *= -1;
                Lines line;
                line.setLines(absoluteRect, [_a, _b], c ? vec3f(0.0f) : vec3f(1), vec2d(minX, maxY), vec2d(maxX, minY));
                lines ~= line;
            }
        }

        if(true) {

        }
        */


    }
    void onPermVNoise() {
    }
    void onPermGNoise() {
    }
    

}

     

