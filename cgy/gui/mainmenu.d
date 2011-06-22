

module gui.mainmenu;

import std.conv;

import main;

import graphics._2d.rect;

import gui.guisystem.guisystem;
import gui.guisystem.window;
import gui.guisystem.text;
import gui.guisystem.button;
import gui.guisystem.checkbox;

class MainMenu : GuiElementWindow {
    Main main;
    GuiSystem guiSystem;
    this(GuiSystem g, Main m) {
        guiSystem = g;
        super(guiSystem, Rectd(vec2d(0.1, 0.1), vec2d(0.8, 0.8)), "Main Menu~~~!", true, true);
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "CoolGameYo!!");     
        auto text2 = new GuiElementText(this, vec2d(0.1, 0.2), "Where logic comes to die");     
        auto butt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.3), vec2d(0.3, 0.3)), "New gay me?", &onNewGame);
        auto cb = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.6), vec2d(0.3, 0.2)), "CHECKBOX", null);
        main = m;
    }
    
    override void destroy() {
        super.destroy();
    }
    
/*        
    override void render() {
        auto r = Recti(1, 1, 800-3, 600-3);
        //auto r = Recti(0, 0, 1, 1);
        renderRect(r, vec3f(1,1,1));
        r = r.diff(vec2i(1,1), vec2i(-1, -1));
        renderOutlineRect(r, vec3f(0,0,0));
        r = r.diff(vec2i(2,2), vec2i(-2, -2));
        renderXXRect(r, vec3f(0,0,0), false);
        auto r = Recti(0, 0, 4, 4);
        renderRect(r, vec3f(1,1,1));
        r.start += vec2i(4);
        renderOutlineRect(r, vec3f(0,0,0));
        r.start += vec2i(4);
        renderRect(r, vec3f(1,1,1));
        r.start += vec2i(4);
        renderXXRect(r, vec3f(0,0,0), true);
        r.start += vec2i(4);
        renderRect(r, vec3f(1,1,1));
        r.start += vec2i(4);
        renderXXRect(r, vec3f(0,0,0), false);
        r.start += vec2i(4);
        renderRect(r, vec3f(1,1,1));
        //renderXXRect(r, vec3f(0,0,0), false);
    }
*/        
    
    void onNewGame(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        main.startGame();
        setVisible(false);
    }
}

     
