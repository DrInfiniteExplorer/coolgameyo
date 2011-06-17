
module gui.guisystem.text;

import std.exception;

import graphics.font;
import gui.guisystem.guisystem;
import util;


class GuiElementText : public GuiElement {
    StringTexture text;
    bool transparent;    
    vec3f color;
    this(GuiElement parent) {
        super(parent);
    }
    this(GuiElement parent, vec2d pos, string str, bool _transparent = true)
    in{
        enforce(parent !is null, "Cant use this constructor without a parent!");
        enforce(parent.getFont() !is null, "Cant use this constructor if parent doesnt have a font!");
    }
    body{        
        super(parent);
        
        transparent = _transparent;
        setText(str);
        setTransparency(transparent);
        vec2d size = text.getSize();
        rect = Rect(pos, size);
    }
    
    void setText(string str) {
        if (text is null) {
            text = new StringTexture(getFont());
        }
        text.setText(str);
    }
    void setTransparency(bool transp) {
        transparent = transp;
        text.setTransparent(transparent);
    }
    void setColor(vec3f c) {
        color = c;
        text.setColor(color);
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
    }
}

