

module gui.gui;

import std.stdio;

import util;

final class Rect {
    private vec2d start;
    private vec2d size;
    
    this(vec2d _start, vec2d _size){
        start = _start;
        size = _size;
    }
    
    bool isInside(vec2d pos) {
        return !(pos.X < start.X ||
            pos.X > start.X+size.X ||
            pos.Y < start.Y ||
            pos.Y > start.Y+size.Y);
    }
    
    vec2d getRelative(vec2d pos){
        return vec2d(
            (pos.X - start.X) / size.X,
            (pos.Y - start.Y) / size.Y,
        );
    }
}

enum GuiEventType {
    MouseMove,
    MouseClick,
    Keyboard
};

final class GuiEvent{
    GuiEventType type;
    alias type this;
    union{
        struct MoveEvent {
            double x, y;
        };
        MoveEvent moveEvent;
        struct ClickEvent{
            bool left; //Otherwise right?
            bool down;
        };
        ClickEvent clickEvent;
        struct KeyboardEvent{
            byte Vk;
            bool pressed;
            int repeat;
            char ch;
        };
        KeyboardEvent keyboardEvent;
    };
}

class GuiElement {
    GuiElement[] children;
    
    Rect rect;
    bool isInside(vec2d pos){
        return rect.isInside(pos);
    }
    
    
    void render(){
        foreach(child ; children) {
            child.render();
        }
    }
    
    bool event(GuiEvent e){
        switch(e.type) {
            case GuiEventType.MouseMove: writeln("MouseMove!"); break;
            default: writeln("other event."); break;
        }
        return false;
    }
    
    bool onEvent(GuiEvent e){
        if(event(e)){
            return true;
        }
        foreach(child ; children) {
            if(child.onEvent(e)){
                return true;
            }
        }
        return false;
    }

    GuiElement getElementFromPoint(vec2d pos){
        if(isInside(pos)){            
            auto relPos = rect.getRelative(pos);
            foreach(child ; children) {
                auto ret = child.getElementFromPoint(relPos);
                if(ret !is null){
                    return ret;
                }
            }
            return this;
        }
        return null;
    }
}

class GuiElementText : public GuiElement {
    this(vec2d pos, string text) {       
    }
}

final class GUI : GuiElement {
    
    
    
    this() {
        
    }
    
        
}



