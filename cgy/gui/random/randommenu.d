module gui.random.menu;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import main;
import gui.mainmenu;
import gui.all;
import random.catmullrom;
import random.fractal;

import random.ridgedfractal;
import random.hybridfractal;

import random.gradientnoise;
import random.modmultadd;
import random.permutation;
import random.random;
import random.randsource;
import random.valuemap;
import random.xinterpolate;

import settings;
//import worldgen.worldgen;
import worldgen.newgen;
import util.util;
import util.rect;

import graphics.image;
import graphics._2d.line;

import gui.random.voronoi;
import gui.random.perlin;
import gui.random.ridgedfractal;
import gui.random.hybridfractal;

import util.voronoi.voronoi;
import util.voronoi.fortune;
import util.voronoi.wrapper;

class RandomMenu : GuiElementWindow {
    GuiElement guiSystem;
    GuiElement container;
    MainMenu main;

    Lines[] lines;

    GuiElementLabeledComboBox randomSelector;
    GuiElementLabeledComboBox colorSelector;
    PushButton randomButton;

    int seed;

    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "Randomness experiment Menu~~~!", false, false);

        randomSelector = new GuiElementLabeledComboBox(this, Rectd(clientArea.leftOf, clientArea.topOf, 0.2, 0.05), "Randomness menu:", &onChangeRandom);
        randomSelector.addItem("Voronoi diagram");
        randomSelector.addItem("Perlin");
        randomSelector.addItem("Ridged Multifractal");
        randomSelector.addItem("Hybrid Multifractal");
        randomSelector.addItem("Back");

        colorSelector = new GuiElementLabeledComboBox(this, Rectd(randomSelector.rightOf, randomSelector.topOf, 0.2, randomSelector.heightOf),
                                                      "Color mode:", &onChangeColor);
        colorSelector.addItem("gray");
        colorSelector.addItem("cutOff");

        colorMode = &grayColor;

        auto a = new GuiElementLabeledEdit(this, Rectd(colorSelector.rightOf, colorSelector.topOf, 0.2, 0.05), "seed", to!string(seed));
        a.setOnEnter((string value) {
            seed = to!int(value);
            redraw();
        });

        randomButton = new PushButton(this, Rectd(a.leftOf, a.bottomOf, 0.2, 0.10), "Random", {
            auto rand = new RandSourceUniform(seed);
            seed = rand.get(0, int.max);
            a.setText(to!string(seed));
            redraw();
        });

        randomSelector.selectItem(1);
        colorSelector.selectItem(0);

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

    void delegate() redraw;

    mixin RandomVoronoi;
    mixin RandomPerlin;
    mixin RandomRidged;
    mixin RandomHybrid;

    string current;

    void onChangeRandom(int idx) {
        auto init = [
            "Voronoi diagram":&initVoronoi,
            "Perlin":&initPerlin,
            "Ridged Multifractal":&initRidged,
            "Hybrid Multifractal":&initHybrid,
            "Back":&onBack
        ];
        auto destroy = [
            "Voronoi diagram":&destroyVoronoi,
            "Perlin":&destroyPerlin,
            "Ridged Multifractal":&destroyRidged,
            "Hybrid Multifractal":&destroyHybrid,
            "Back":&onBack
        ];

        if(current !is null) {
            enforce(current in destroy, "DESTROYER not found for " ~ current);
            destroy[current]();
        }

        if(container !is null) {
            container.destroy();
        }
        container = new GuiElement(this);
        auto area = clientArea.diff(0, randomSelector.heightOf, -randomButton.widthOf, 0);
        container.setRelativeRect(area);

        auto which = randomSelector.getText(idx);
        enforce(which in init, "Initializer not found for " ~ which);
        init[which]();
        current = which;

        randomSelector.bringToFront();
    }

    string mode = "gray";
    void onChangeColor(int idx) {

        auto init = [
            "gray":&setGray,
            "cutOff":&setCutOff

        ];
        auto destroy = [
            "gray":&unsetGray,
            "cutOff":&unsetCutOff
        ];

        enforce(mode in destroy, "DESTROYER not found for " ~ current);
        destroy[mode]();

        auto which = colorSelector.getText(idx);
        enforce(which in init, "Initializer not found for " ~ which);
        init[which]();
        mode = which;
        redraw();
    }

    void setGray() {
        colorMode = &grayColor;
    }
    void unsetGray() {
    }

    void setCutOff() {
        colorMode = &cutOffColor;
    }
    void unsetCutOff() {
    }

    double cutOffVal = 0.3;
    double[4] cutOffColor(double d) {
        double[4] ret;
        ret[] = d;
        if(d < cutOffVal) ret[0..1] = 0;
        return ret;
    }
    double[4] grayColor(double d) {
        double[4] ret;
        ret[] = d;
        return ret;
    }
    double[4] delegate(double) colorMode;

}

