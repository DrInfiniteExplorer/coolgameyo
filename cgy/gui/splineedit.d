



module gui.splineedit;

import std.conv;
import std.regex;

import main;

import gui.mainmenu;
import gui.all;

import graphics.image;
import graphics.ogl;
import graphics.renderconstants;

import random.catmullrom;

import settings;
import util.util;
import util.rect;

class SplineEditor : GuiElementWindow {
    GuiElement guiSystem;

    alias GuiElementSimpleGraph!(float) FloatGraph;
    FloatGraph redGraph;
    FloatGraph greenGraph;
    FloatGraph blueGraph;

    GuiElementImage colorImg;
    Image img;
    uint glTex = 0;


	GuiElementListBox listBox;

    GuiElementEditbox editBox;

    MainMenu main;
    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1.0, 1.0)), "Color Spline Editor~~~!", false, false);

        redGraph = new FloatGraph(this, Rectd(0.1, 0.10, 0.4, 0.5), true);
        greenGraph = new FloatGraph(this, redGraph.getRelativeRect, true);
        blueGraph = new FloatGraph(this, redGraph.getRelativeRect, true);

        redGraph.setColor(vec3f(1.0, 0.0, 0.0));
        greenGraph.setColor(vec3f(0.0, 1.0, 0.0));
        blueGraph.setColor(vec3f(0.0, 0.0, 1.0));

        colorImg = new GuiElementImage(this, Rectd(blueGraph.leftOf, blueGraph.bottomOf + 0.1, blueGraph.widthOf, 0.1));
        img = Image(null, colorImg.getAbsoluteRect().widthOf, 1);
        glTex = img.toGLTex(glTex);
        colorImg.setImage(glTex);

        listBox = new GuiElementListBox(this, Rectd(redGraph.rightOf + 0.05, redGraph.topOf, 0.3, 0.6), 30, &onColorSelect);

        editBox = new GuiElementEditbox(this, Rectd(listBox.leftOf, listBox.bottomOf + 0.05, listBox.widthOf, 0.05), "R, G, B");

        auto up = new PushButton(this, Rectd(listBox.rightOf+0.05, listBox.topOf + 0.15, 0.05, 0.05), "Up", &onMoveUp);
        auto down = new PushButton(this, Rectd(listBox.rightOf+0.05, up.bottomOf + 0.05, 0.05, 0.05), "Down", &onMoveDown);

        auto add = new PushButton(this, Rectd(editBox.leftOf, editBox.bottomOf + 0.05, editBox.widthOf/2.0, 0.05), "Add", &onAddColor);
        auto set = new PushButton(this,
            Rectd(add.rightOf + 0.05, add.topOf, editBox.rightOf - (add.rightOf+0.05), add.heightOf), "Set", &onSetColor);

        auto del = new PushButton(this, Rectd(add.leftOf, add.bottomOf+ 0.025, add.widthOf, add.heightOf), "Delete", &onDelete);


        new PushButton(this, Rectd(listBox.leftOf, listBox.topOf - 0.075, 0.2, 0.05), "Load skycolors", &onLoadSky);


        auto butt = new PushButton(this, Rectd(vec2d(colorImg.leftOf, colorImg.bottomOf + 0.05), vec2d(0.3, 0.10)), "Back", &onBack);
  
        main = m;
    }
    
    override void destroy() {
        super.destroy();
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }    
    
    void onColorSelect(int idx) {
        auto str = listBox.getItemText(listBox.getSelectedItemIndex());
        editBox.setText(str);
        //redraw();
    }

    bool parseColor(string str, out vec3f color) {
        color.set(0,0,0);


        auto ex = regex(r"^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$");
        auto m = match(str, ex);
        if(!m.empty) {
            int r = to!int(m.captures[1]);
            int g = to!int(m.captures[2]);
            int b = to!int(m.captures[3]);
            color.set(cast(float)r/255.0f, cast(float)g/255.0f, cast(float)b/255.0f);
            return true;
        }
        return false;


    }
    
    void onAddColor() {
        vec3f color;
        auto str = editBox.getText();
        if(parseColor(str, color)) {
            listBox.addItem(str, listBox.getSelectedItemIndex());
        }
        redraw();
    }
    void onSetColor() {
        if(listBox.getSelectedItemIndex() == -1) {
            return;
        }
        vec3f color;
        auto str = editBox.getText();
        if(parseColor(str, color)) {
            listBox.setText(str, listBox.getSelectedItemIndex());
        }
        redraw();
    }

    void onMoveUp() {
        int cnt = listBox.getItemCount();
        if(cnt < 2) {
            return;
        }
        int id = listBox.getSelectedItemIndex();
        if(id < 1) {
            return;
        }
        auto str = listBox.getItemText(id);
        listBox.removeItem(id);
        listBox.addItem(str, id-1);
        listBox.selectItem(id-1);
        redraw();

    }
    void onMoveDown() {
        int cnt = listBox.getItemCount();
        if(cnt < 2) {
            return;
        }
        int id = listBox.getSelectedItemIndex();
        if(id+1 >= cnt) {
            return;
        }
        auto str = listBox.getItemText(id+1);
        listBox.removeItem(id+1);
        listBox.addItem(str, id);
        listBox.selectItem(id+1);
        redraw();
    }

    void onDelete() {
        int id = listBox.getSelectedItemIndex();
        if(id == -1) {
            return;
        }
        listBox.removeItem(id);
        redraw();
    }

    void onLoadSky() {
        listBox.clear();
        foreach(color ; SkyColors) {
            vec3i icol = (color*255.0f).convert!int();
            listBox.addItem(text(icol.X, ", ", icol.Y, ", ", icol.Z));
        }
        redraw();
    }


    void redraw() {
        if(listBox.getItemCount() < 4) {
            return;
        }

        vec3f[] colors;
        vec3f color;
        for(int i=0; i < listBox.getItemCount(); i++) {
            parseColor(listBox.getItemText(i), color);
            colors ~= color;
        }

        int width = colorImg.getAbsoluteRect().widthOf;
        float[] r, g, b;
        foreach(idx ; 0 .. width) {
            float time = cast(float)idx/cast(float)width;
            color = CatmullRomSpline(time, colors);
            r ~= color.X;
            g ~= color.Y;
            b ~= color.Z;
            vec3i icol = (color*255.0f).convert!int();
            img.setPixel(idx, 0, icol.X, icol.Y, icol.Z);
        }
        redGraph.setData(r, 0.0, 1.0);
        greenGraph.setData(g, 0.0, 1.0);
        blueGraph.setData(b, 0.0, 1.0); 
        img.toGLTex(glTex);


    }
}

     

