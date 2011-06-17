

module gui.guisystem;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import graphics._2d.rect;
import graphics.font;
import graphics.ogl;

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
            vec2d pos;
            vec2d delta;
        };
        MouseMove mouseMove;
        struct MouseClick{
            bool left; //Otherwise right?
            bool down;
            vec2d pos;
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
    private GuiElement[] children;
    private GuiElement parent;
    private Rect rect;
    private Rect absoluteRect;
    private Font font;
    
    this(GuiElement parent){
        if(parent) {
            setParent(parent);
            font = parent.getFont();        
        }
    }
    
    GuiElement getParent() {
        return parent;
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
            return a==e;
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
    
    bool isInside(vec2d pos){
        return rect.isInside(pos);
    }
    
    void setRect(Rect r) {
        rect = r;
    }
    
    Rect getRect() {
        return rect;
    }
    
    Rect getAbsoluteRect() {
        if(parent) {
            auto parentRect = parent.getAbsoluteRect();
            return parentRect.getSubRect(rect);
        }
        return rect;
    }
    
    
    void render(){
        foreach(child ; children) {
            child.render();
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

    GuiElement getElementFromPoint(vec2d pos){
        if (isInside(pos)) {
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
    
    void setFont(Font f) {
        font = f;
    }
    Font getFont() {
        return font;
    }
}

class GuiElementText : public GuiElement {
    StringTexture text;
    this(GuiElement parent) {
        super(parent);
    }
    this(GuiElement parent, vec2d pos, string str)
    in{
        enforce(parent !is null, "Cant use this constructor without a parent!");
        enforce(parent.getFont() !is null, "Cant use this constructor if parent doesnt have a font!");
    }
    body{        
        super(parent);
        
        text = new StringTexture(getFont());
        text.setText(str);
        vec2d size = text.getSize();
        rect = Rect(pos, size);
    }
    
    void setText(string str) {
        if (text is null) {
            text = new StringTexture(getFont());
        }
        text.setText(str);
    }
    
    override void render(){
        auto absRect = getAbsoluteRect();
        text.render(absRect);
        super.render();
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.FocusOn) {
            return GuiEventResponse.Reject;
        }
        return super.onEvent(e);
        return GuiEventResponse.Ignore;
    }
}

class GuiElementWindow : public GuiElement {
    private string caption;
    private bool dragable;
    private bool dragging; //true when dragging
    vec2d dragHold; //Hold-position of window, kinda, yeah.
    private GuiElementText captionText;
    
    Rect barRect;
    Rect clientRect;
    
    this(GuiElement parent, Rect r, string caption, bool dragAble = true) {
        super(parent);
        setRect(r);
        setCaption(caption);
        setDragable(dragAble);
    }    
    
    void setCaption(string text) {
        caption = text;
        if (captionText is null) {
            captionText = new GuiElementText(this, vec2d(0, 0), text);
        } else {
            captionText.setText(text);            
        }
        recalcRects();
    }
    void setDragable(bool enable) {
        dragable = enable;
    }
    
    private void recalcRects() {
        auto size = captionText.getRect().size;
        absoluteRect = getAbsoluteRect();
        barRect = absoluteRect.getSubRect(Rect(vec2d(0.0, 0.0), vec2d(1.0, 1.0)));
        clientRect = absoluteRect.getSubRect(Rect(vec2d(0.0, 0.0), vec2d(1.0, 1.0)));
        barRect.size.Y = size.Y;
        clientRect.start.Y += size.Y;
        clientRect.size.Y -= size.Y;
    }
    
    override void onMove() {
        recalcRects();
        super.onMove();
    }
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect); //Background color
        renderRect(barRect, vec3f(1.0, 0.0, 0.0));
        renderOutlineRect(barRect, vec3f(0.0, 1.0, 0.0));
        super.render();
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    //barRect is in absolute coordinates already                    
                    if(barRect.isInside(m.pos)) {
                        dragging = true;
                        //Calculate relative drag-hold-position.                        
                        dragHold = rect.start - parent.getAbsoluteRect().getRelative(m.pos);
                        return GuiEventResponse.Accept;
                    }                    
                } else if(dragging) {
                    dragging = false;
                    return GuiEventResponse.Accept;
                }
            }
        }
        if (e.type == GuiEventType.MouseMove) {
            if (dragging) {
                auto m = e.mouseMove;
                auto relPos = parent.getAbsoluteRect().getRelative(m.pos);
                rect.start = relPos + dragHold;
                
                //Move window
                onMove();
                return GuiEventResponse.Accept;
            }
        }
        return super.onEvent(e);
    }
}

final class GUI : GuiElement {
    
    private GuiElement hoverElement;
    private GuiElement focusElement;
    
    this() {
        super(null);
        setFont(new Font("fonts/courier"));
        rect = Rect(vec2d(0, 0), vec2d(1, 1));
        hoverElement = this;
        focusElement = this;
    }
    
    override bool isInside(vec2d p) {
        return true;
    }
    
    void setFocus(GuiElement e) {
        if (e == focusElement) {
            return;
        }
        if (focusElement) {
            GuiEvent event;
            event.type = GuiEventType.FocusOff;
            focusElement.onEvent(event);
        }
        focusElement = e;
        if (focusElement) {
            GuiEvent event;
            event.type = GuiEventType.FocusOn;
            while(focusElement != this) {
                if (focusElement.onEvent(event) != GuiEventResponse.Reject) {
                    break;
                }
                focusElement = focusElement.getParent();
            }
        }
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        switch (e.type) {
            case GuiEventType.MouseMove:
                auto move = e.mouseMove;
                auto element = getElementFromPoint(move.pos);
                if (hoverElement != element) {
                    GuiEvent hoverEvent;
                    hoverEvent.type = GuiEventType.HoverOn;
                    element.onEvent(hoverEvent);
                    hoverEvent.type = GuiEventType.HoverOff;
                    hoverElement.onEvent(hoverEvent);
                    hoverElement = element;
                }
                if(focusElement && focusElement != this) {
                    return focusElement.onEvent(e);
                }                
                break;
            case GuiEventType.MouseClick:
                auto m = e.mouseClick;
                if (m.left && m.down) {
                    setFocus(hoverElement);
                }
                if(focusElement && focusElement != this) {
                    return focusElement.onEvent(e);
                }
                break;
           case GuiEventType.Keyboard:
               //Handle hotkeys with modifiers, like ctrl+k
               //Got focused object? Give him input
               if (focusElement && focusElement != this) {
                   auto ret = focusElement.onEvent(e);
                   return ret;
                   //Lines below meaningful?
                   if (ret != GuiEventResponse.Ignore) {
                       return ret;
                   }
                   
               }
               //Handle other hotkeys
               //Else if non-focus-object'ish registered, send to it. (player walking etc..)
               break;
           case GuiEventType.HoverOn:
           case GuiEventType.HoverOff:
           case GuiEventType.FocusOn:
           case GuiEventType.FocusOff:
               break; //Dont handle these here.
           default:
               enforce(0, "Shouldnt get here, spank luben about it");
               break;
                
        }
        return GuiEventResponse.Ignore;
    }        
    
    
    override void render() {
        glDisable(GL_DEPTH_TEST);
        glDepthMask(0);        
        super.render();
        glDepthMask(1);        
        glEnable(GL_DEPTH_TEST);        
    }
}



