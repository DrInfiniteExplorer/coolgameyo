

module gui.guisystem.element;

import std.algorithm;
import std.conv;
import std.stdio;

import gui.guisystem.guisystem;

import graphics.font;
import settings;
import util;

enum GuiEventType {
    MouseMove,
    MouseClick,
    Keyboard,
    HoverOn,
    HoverOff,
    FocusOn, //If return false, focus goes to parent, which may reject as well, up to rootobject.
    FocusOff,
    
};

enum GuiEventResponse {
    Accept,
    Reject,
    Ignore
};

struct GuiEvent{
    GuiEventType type;
    union{
        struct MouseMove {
            vec2i pos;
            vec2i delta;
        };
        MouseMove mouseMove;
        struct MouseClick{
            bool left; //Otherwise right?
            bool down;
            vec2i pos;
        };
        MouseClick mouseClick;
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
    protected GuiElement guiSystem;
    private GuiElement[] children;
    protected GuiElement parent;

    protected Rectd relativeRect;
    protected Recti absoluteRect;
    protected Font font;
    protected bool visible;
    
    this(GuiElement parent){
        //Uh, yeah! make sure that if parent == null then we are a GuiSystem.
        visible = true;
        if(parent) {
            setParent(parent);
            font = parent.font;        
            while(parent.getParent() !is null) {
                parent = parent.getParent();
            }
            guiSystem = parent;
        }
    }
    
    void destroy() {
        looseFocus();
        while (children.length > 0) {
            children[0].destroy(); //Proper chilredn should remove themselfves from this array.
        }
        setParent(null);
        //Release resources
    }
    
    GuiElement getParent() {
        return parent;
    }
    
    GuiElement getGuiSystem() {
        return guiSystem;
    }
    
    void setParent(GuiElement p) {
        if (parent) {
            parent.removeChild(this);
        }
        
        if(p) {
            p.addChild(this);
        }
    }
    
    void removeChild(GuiElement e){
        bool b(GuiElement a){
            return a is e;
        }
        children = remove!(b)(children);
        e.parent = null;
    }
    void addChild(GuiElement e) {
        if (e.parent) {
            e.setParent(this);
        } else {
            e.parent = this;
            children ~= e;
        }
    }
    
    void setFocus(GuiElement e)
    in{
        assert(guiSystem !is null, "Element missing guisystem; cant set focus!");
    }
    body{
        guiSystem.setFocus(e);
    }
    
    GuiElement getFocusElement()
    in{
        assert(guiSystem !is null, "Element missing guisystem; cant set focus!");
    }
    body{
        return guiSystem.getFocusElement();
    }
    
    bool hasFocus() {
        return this is getFocusElement();
    }
    
    void looseFocus() {
        foreach(child ; children) {
            child.looseFocus();
        }
        if (hasFocus()) {
            setFocus(parent);
        }
    }
    
    bool isInside(vec2i pos){
        return absoluteRect.isInside(pos);
    }
    
    void setRelativeRect(Rectd r) {
        relativeRect = r;
        getAbsoluteRect();
        onMove();
    }
    
    void setAbsoluteRect(Recti r)
/*
    out{
        assert(getAbsoluteRect() == r, text("Derp errrooooor ", r, " ",getAbsoluteRect));
    }
*/
    body{
        absoluteRect = r;
        auto parentScreenRelative = parent.getScreenRelativeRect();
        
        auto screenRect = Rectd(vec2d(0,0), vec2d(renderSettings.windowWidth, renderSettings.windowHeight));
        auto screenRelative = screenRect.getSubRectInv(convert!double(r));
        relativeRect = parentScreenRelative.getSubRectInv(screenRelative);
        onMove();
    }
    
    Rectd getRelativeRect() {
        return relativeRect;
    }
    
    Rectd getScreenRelativeRect() {
        if (parent !is null) {
            auto p = parent.getScreenRelativeRect();
            return p.getSubRect(relativeRect);
        }
        return relativeRect;
    }
    
    Recti getAbsoluteRect() {
        auto screenRelative = getScreenRelativeRect();
        auto screenRect = Rectd(vec2d(0,0), vec2d(renderSettings.windowWidth, renderSettings.windowHeight));
        absoluteRect = convert!int(screenRect.getSubRect(screenRelative));
        return absoluteRect;
    }
    
    
    void render(){
        foreach(child ; children) {
            if (child.getVisible()) {
                child.render();
            }
        }
    }
    
    //Do things such as animating or controlling unit motion, derp etc
    void tick(float dTime) {
        foreach(child ; children) {
            child.tick(dTime);
        }        
    }
    
    GuiEventResponse onEvent(GuiEvent e){
        switch(e.type) {
            case GuiEventType.MouseMove: writeln("MouseMove!"); break;
            default: writeln("other event." ~ to!string(e.type)); break;
        }
        return GuiEventResponse.Ignore;
    }    
    
    void onMove() {
        absoluteRect = getAbsoluteRect();
        foreach(child ; children) {
            child.onMove();
        }
    }

    GuiElement getElementFromPoint(vec2i pos){
        if (visible && isInside(pos)) {
            foreach(child ; children) {
                auto ret = child.getElementFromPoint(pos);
                if(ret !is null){
                    return ret;
                }
            }
            return this;
        }
        return null;
    }
    
    void setFont(Font f) {
        font = f;
    }
    Font getFont() {
        return font;
    }
    
    void setVisible(bool enable) {
        if (visible && !enable) {
            looseFocus();
        }
        visible = enable;
    }
    bool getVisible() {
        return visible;
    }
    
    void bringToFront(bool uncursive = false) { //True to bring element and all parents to front.
        setParent(parent);
        if (uncursive) {
            parent.bringToFront();
        }
    }
}
