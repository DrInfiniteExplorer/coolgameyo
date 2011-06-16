

module gui.gui;

import std.algorithm;
import std.exception;
import std.stdio;

import graphics.font;
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
    
    GuiEventResponse event(GuiEvent e){
        switch(e.type) {
            case GuiEventType.MouseMove: writeln("MouseMove!"); break;
            default: writeln("other event."); break;
        }
        return GuiEventResponse.Ignore;
    }
    
    GuiEventResponse onEvent(GuiEvent e){
        auto ret = event(e);
        if(ret != GuiEventResponse.Ignore){
            return ret;
        }
        foreach(child ; children) {
            ret = child.onEvent(e);
            if(ret != GuiEventResponse.Ignore){
                return ret;
            }
        }
        return GuiEventResponse.Ignore;
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
    
    override GuiEventResponse event(GuiEvent e) {
        if (e.type == GuiEventType.FocusOn) {
            return GuiEventResponse.Reject;
        }
        return super.event(e);
        return GuiEventResponse.Ignore;
    }
}

class GuiElementWindow : public GuiElement {
    private string caption;
    private bool dragable;
    private GuiElementText captionText;
    this(GuiElement parent, Rect r, bool dragAble, string caption) {
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
    }
    void setDragable(bool enable) {
        dragable = enable;
    }
    
    override void render() {
        //Render background, etc, etc.
        super.render();
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
}



