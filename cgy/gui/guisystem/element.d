

module gui.guisystem.element;

import std.algorithm;
import std.range;
import std.conv;
import std.stdio;

import gui.guisystem.guisystem;

import graphics.font;
import settings;
import util.util;
import util.rect;


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
    double eventTimeStamp;
    union{
        struct MouseMove {
            vec2i pos;
            vec2i delta;
        };
        MouseMove mouseMove;
        struct MouseClick{
            bool left; //Otherwise right?
            bool right; //Otherwise right?
            bool middle; //Otherwise right?
            bool wheelUp; //Otherwise right?
            bool wheelDown; //Otherwise right?
            
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

    alias bool delegate(GuiElement, GuiEvent.MouseClick) MouseClickCallback;
    protected MouseClickCallback mouseClickCB;

    protected GuiElement guiSystem;
    private GuiElement[] children;
    protected GuiElement parent;

    protected Rectd relativeRect;
    protected Recti absoluteRect;
    protected Font font;

    protected bool visible = true;
    protected bool selectable = true;
    protected bool enabled = true;
    
    this(GuiElement parent){
        //Uh, yeah! make sure that if parent == null then we are a GuiSystem.
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

    GuiElement getNext() {
        if(children.length) {
            return children[0];
        }
        auto next = parent.getNextSibling(this);
        if(next !is null) {
            return next;
        }
        auto node = parent;
        while(node !is null && node.parent !is null) {
            next = node.parent.getNextSibling(node);
            if(next) return next;
            node = node.parent;
        }
        return null;
    }

    private GuiElement getNextSibling(GuiElement child) {
        foreach(idx, ch ; children) {
            if(ch is child) {
                if(idx+1 == children.length) {
                    return null;
                }
                return children[idx+1];
            }
        }
        return null;
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
        children = children.remove(countUntil(children, e));
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
    
    bool hasFocus() @property {
        return this is getFocusElement();
    }

    //Note: not a OnLooseFocus but more "Relinquish focus from this element!"
    // Use GuiEvent e.type == GuiEventType.FocusOff instead
    void looseFocus() {
        foreach(child ; children) {
            child.looseFocus();
        }
        if (hasFocus()) {
            setFocus(parent);
        }
    }

    void cycleFocus()
    in{
        assert(guiSystem !is null, "Element missing guisystem; cant cycle focus!");
    }
    body{
        return guiSystem.cycleFocus();
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
        if(parent is null) return;

        absoluteRect = r;
        auto parentScreenRelative = parent.getScreenRelativeRect();
        
        auto screenRect = Rectd(vec2d(0,0), vec2d(renderSettings.windowWidth, renderSettings.windowHeight));
        auto screenRelative = screenRect.getSubRectInv(r.convert!double);
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
        absoluteRect = screenRect.getSubRect(screenRelative).convert!int;
        return absoluteRect;
    }
    
    
    void render(){
        foreach(child ; children) {
            if (child.isVisible) {
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
            case GuiEventType.MouseClick:
                if(mouseClickCB !is null) {
                    if(mouseClickCB(this, e.mouseClick)) return GuiEventResponse.Accept;
                }
                break;
            default: /*msg("other event." ~ to!string(e.type)); */ break;
        }

        return GuiEventResponse.Ignore;
    }    
    
    void onMove() {
        absoluteRect = getAbsoluteRect();
        foreach(child ; children) {
            child.onMove();
        }
    }

    GuiElement getElementFromPoint(vec2i pos, bool all = false){
        if (visible && isInside(pos)) {
            foreach(child ; retro(children)) {
                auto ret = child.getElementFromPoint(pos);
                if(ret !is null){
                    return ret;
                }
            }
            if(all || selectable) {
                return this;
            }
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
    bool isVisible() const @property{
        return visible;
    }

    void setEnabled(bool enable) {
        enabled = enable;
    }
    bool isEnabled() const @property {
        return enabled;
    }
    
    void setSelectable(bool v) {
        selectable = v;
    }
    bool isSelectable() const @property {
        return selectable;
    }
    
    void bringToFront(bool uncursive = false) { //True to bring element and all parents to front.
        setParent(parent);
        if (uncursive) {
            parent.bringToFront();
        }
    }

    void setMouseClickCallback(MouseClickCallback cb) {
        mouseClickCB = cb;
    }
    
    double rightOf() const @property { return relativeRect.rightOf(); }
    double leftOf() const @property { return relativeRect.leftOf(); }
    double topOf() const @property { return relativeRect.topOf(); }
    double bottomOf() const @property { return relativeRect.bottomOf(); }
    double widthOf() const @property { return relativeRect.widthOf(); }
    double heightOf() const @property { return relativeRect.heightOf(); }
}
