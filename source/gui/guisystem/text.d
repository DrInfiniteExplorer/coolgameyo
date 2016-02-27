
module gui.guisystem.text;

import std.exception;

import graphics.font;
import gui.guisystem.guisystem;
import util.util;
import util.rect;



class GuiElementText : GuiElement {
    StringTexture text;
    this(GuiElement parent) {
        super(parent);
    }
    this(GuiElement parent, vec2d pos, string str, bool transparent = true)
    in{
        enforce(parent !is null, "Cant use this constructor without a parent!");
        enforce(parent.getFont() !is null, "Cant use this constructor if parent doesnt have a font!");
    }
    body{        
        super(parent);
        
        setSelectable(false);
        setText(str);
        setTransparency(transparent);
        setRelativeRect(Rectd(pos, vec2d(1,1)));
        absoluteRect.size = text.getSize();
        setAbsoluteRect(absoluteRect);
        if(!transparent) {
            setColor(vec3f(1.0)); //If not transparent, make the font show by default :P
        }
    }

    override Recti getAbsoluteRect() {
        auto rect = super.getAbsoluteRect;
        absoluteRect.size = text.getSize();
        return absoluteRect;
    }

    void setPosition(vec2i absolutePos) {
        auto rect = getAbsoluteRect();
        rect.start = absolutePos;
        setAbsoluteRect(rect);
    }
    
    override void destroy() {
        super.destroy();
        text.destroy();
    }
    
    vec2i getSize() {
        return text.getSize();
    }
    
    string getText() {
        if (text is null) enforce(0, "lol, summit is wrooong!");
        return text.getText();
    }
    void setText(string str) {
        if (text is null) {
            text = new StringTexture(font);
        }
        text.setText(str);
    }

    void format(T...)(T t) {
        text.format(t);
    }

    void setTransparency(bool transp) {
        text.setTransparent(transp);
    }
    void setColor(vec3f c) {
        text.setColor(c);
    }
    
    override void render(){
        text.render(absoluteRect);
        super.render();
    }
    
    override GuiEventResponse onEvent(InputEvent e) {
        if (cast(FocusOnEvent) e) {
            return GuiEventResponse.Reject;
        }
        return super.onEvent(e);
    }
}

