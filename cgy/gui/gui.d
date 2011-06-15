

module gui.gui;

import std.algorithm;
import std.exception;
import std.stdio;

import util;

struct Rect {
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
    Keyboard,
    HoverOn,
    HoverOff,
    FocusOn,
    FocusOff,
    
};

struct GuiEvent{
    GuiEventType type;
    union{
        struct MoveEvent {
            vec2d pos;
            vec2d delta;
        };
        MoveEvent moveEvent;
        struct ClickEvent{
            bool left; //Otherwise right?
            bool down;
        };
        ClickEvent clickEvent;
        struct KeyboardEvent{
            int SdlSym;
            int SdlMod;
            bool pressed;
            int repeat;
            char ch;
        };        
        KeyboardEvent keyboardEvent;
    };
}

class GuiElement {
    private GuiElement[] children;
    private GuiElement parent;
    private Rect rect;
    
    void setParent(GuiElement p) {
        if (parent) {
            parent.removeChild(this);
        }
        
        parent = p;
        if(parent) {
            parent.addChild(this);
        }
    }
    
    void removeChild(GuiElement e){
        bool b(GuiElement a){
            return a==e;
        }
        children = remove!(b)(children);
        e.parent = null;
    }
    void addChild(GuiElement e) {
        if (e.parent) {
            e.setParent(this);
        } else {
            children ~= e;
        }
    }
    
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
    
    private GuiElement hoverElement;
    
    this() {
        rect = Rect(vec2d(0, 0), vec2d(1, 1));
    }
    
    override bool isInside(vec2d p) {
        return true;
    }
    
    override bool onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseMove) {
            auto move = e.moveEvent;
            auto element = getElementFromPoint(move.pos);
            if (element != this) {
                if (hoverElement != element) {
                    GuiEvent hoverEvent;
                    hoverEvent.type = GuiEventType.HoverOn;
                }
            }
        }
        return false;;
    }
        
}



