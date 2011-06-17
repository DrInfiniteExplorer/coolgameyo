

module gui.guisystem.button;

import std.stdio;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;


class GuiElementButton : public GuiElement {
    private string text;
    private GuiElementText buttonText;

    bool pushedDown;    
    alias void delegate(bool pressed, bool abort) PressCallback;
    PressCallback pressCallback;
        
    this(GuiElement parent, Rect r, string text, PressCallback cb = null) {
        super(parent);
        setRect(r);
        setText(text);
        pressCallback = cb;
    }    
    
    void setText(string str) {
        text = str;
        if (buttonText is null) {
            buttonText = new GuiElementText(this, vec2d(0, 0), str);
        } else {
            buttonText.setText(str);            
        }
        buttonText.setColor(vec3f(1.0, 1.0, 1.0));
        recalcRects();
    }
    void setColor(vec3f c) {
        buttonText.setColor(c);
    }

    
    private void recalcRects() {
        absoluteRect = getAbsoluteRect();
    }
    
    override void onMove() {
        recalcRects();
        super.onMove();
    }
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75)); //Background color
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
        auto inner = pixDiff(absoluteRect, vec2i(1, 1), vec2i(-1, -1));
        if(pushedDown) {
            renderOutlineRect(inner, vec3f(0.5, 0.5, 0.5));
        } else {
            renderXXRect(inner, vec3f(1.0, 1.0, 1.0), true);
            renderXXRect(inner, vec3f(0.25, 0.25, 0.25), false);
            inner = pixDiff(inner, vec2i(1, 1), vec2i(-1, -1));
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


