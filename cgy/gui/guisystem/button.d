

module gui.guisystem.button;

import std.stdio;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import util.util;
import util.rect;


//Difference between this and subclass GuiElementButton
//is that GuiElementButton only calls callback on released click on button.
class GuiElementButtonAll : public GuiElement {
    protected GuiElementText buttonText;

    protected bool pushedDown;    
    alias void delegate(bool pressed, bool abort) PressCallback;
    private PressCallback pressCallback;
        
    this(GuiElement parent, Rectd relative, string text, PressCallback cb = null) {
        super(parent);
        setRelativeRect(relative);
        setText(text);
        setColor(vec3f(0,0,0));
        pressCallback = cb;
        onMove();
    }    
    
    void setText(string str) {
        if (buttonText is null) {
            buttonText = new GuiElementText(this, vec2d(0, 0), str);
        } else {
            buttonText.setText(str);            
        }
        buttonText.setColor(vec3f(1.0, 1.0, 1.0));
    }
    
    void setColor(vec3f c) {
        buttonText.setColor(c);
    }
    
    override void onMove() {
        if (buttonText !is null) {
            auto buttonSize = buttonText.getSize();
            auto newTextRect = absoluteRect.centerRect(Recti(vec2i(0, 0), buttonSize));
            buttonText.setAbsoluteRect(newTextRect);        
        }
        super.onMove();        
    }
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75)); //Background color
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
        auto inner = absoluteRect.diff(vec2i(1, 1), vec2i(-1, -1));
        if(pushedDown) {
            renderOutlineRect(inner, vec3f(0.5, 0.5, 0.5));
        } else {
            renderXXRect(inner, vec3f(1.0, 1.0, 1.0), true);
            renderXXRect(inner, vec3f(0.25, 0.25, 0.25), false);
            inner = inner.diff(vec2i(1, 1), vec2i(-1, -1));
            renderXXRect(inner, vec3f(0.5, 0.5, 0.5), false);
        }
        super.render();
    }
    
    void onPushed(bool down, bool abort){
        if (pressCallback) {
            pressCallback(down, abort);
        }
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
                        pushedDown = true;
                        onPushed(true, false);
                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    if (pushedDown) {
                        pushedDown = false;
                        if(absoluteRect.isInside(m.pos)) {
                            onPushed(false, false);
                            return GuiEventResponse.Accept;
                        } else {
                            onPushed(false, true);
                            return GuiEventResponse.Accept;
                        }
                    }
                }
            }
        }
        return super.onEvent(e);
    }
}

class GuiElementButton : GuiElementButtonAll {
    private void delegate() callback;
    this(GuiElement parent, Rectd relative, string text, void delegate() cb = null) {
        super(parent, relative, text);
        callback = cb;
    }
    
    override void onPushed(bool down, bool abort){
        if (!down && !abort && callback !is null) {
            callback();
        }
    }
}

