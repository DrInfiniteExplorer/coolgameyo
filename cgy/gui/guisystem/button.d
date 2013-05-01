

module gui.guisystem.button;


import std.stdio;
import std.traits;
import std.typecons;
import std.typetuple;

//TODO: Make this a public import in some gui-module.
import derelict.sdl.sdl;


import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import util.util;
import util.rect;

enum ButtonCallbackPolicies {
    Simple,
    Element,
    State,
    SimpleElement
}

mixin template params(ButtonCallbackPolicies policy, T...) {
    static if(policy == ButtonCallbackPolicies.State) {
        auto params(T t){ return tuple(t[0..2]); }
        enum SimpleButton = false;
    }else static if(policy == ButtonCallbackPolicies.Element) {
        auto params(T t){ return tuple(t[2]); }
        enum SimpleButton = false;
    }else static if(policy == ButtonCallbackPolicies.Simple) {
        auto params(T t){ return tuple(); }
        enum SimpleButton = true;
    }else static if(policy == ButtonCallbackPolicies.SimpleElement) {
        auto params(T t){ return tuple(t[2]); }
        enum SimpleButton = true;

    }else {
        static assert(0, "Unidentified button callback policy");
    }

}

//Difference between this and subclass PushButton
//is that PushButton only calls callback on released click on button.
class Button(ButtonCallbackPolicies policy) : GuiElement {
    protected GuiElementText buttonText;

    protected bool pushedDown;    
    protected vec3f textColor;
    
    mixin params!(policy, bool, bool, typeof(this));
    alias void delegate(typeof(ReturnType!(params).init.expand)) PressCallback;

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
        textColor = c;
        buttonText.setColor(c);
    }

    vec3f getColor() const {
        return textColor;
    }
    
    override void onMove() {
        if (buttonText !is null) {
            auto buttonSize = buttonText.getSize();
            auto newTextRect = absoluteRect.centerRect(Recti(vec2i(0, 0), buttonSize));
            buttonText.setAbsoluteRect(newTextRect);
        }
        super.onMove();        
    }

    override void setEnabled(bool enable) {
        super.setEnabled(enable);
        pushedDown = false;
        buttonText.setColor(enable ? textColor : vec3f(0.4f));
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

        if(hasFocus) {
            auto asd = absoluteRect.diff(4, 4, -4, -4);
            renderOutlineRect(asd, vec3f(0, 0, 0), 1);
        }

        super.render();
    }
    
    void onPushed(bool down, bool abort){
        pushedDown = down;
        if (pressCallback is null) return;
        static if(SimpleButton) {
            if(down || abort) return;
        }
        pressCallback(params(down, abort, this).expand);
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if(!enabled) {
            return super.onEvent(e);
        }
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
                        onPushed(true, false);
                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    if (pushedDown) {
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
        if (e.type == GuiEventType.Keyboard && hasFocus) {
            auto k = &e.keyboardEvent;
            if(k.SdlSym == SDLK_RETURN ||k.SdlSym == SDLK_SPACE) {
                onPushed(k.pressed, false);
            }
        }
        return super.onEvent(e);
    }
}

template StringButton(string policy) {
    mixin(q{alias Button!(ButtonCallbackPolicies.} ~ policy ~ q{) StringButton;});
}

alias StringButton!"Simple"  PushButton;
alias StringButton!"State"   StateButton;
alias StringButton!"Element" ElementButton;
alias StringButton!"SimpleElement" SimpleElementButton;


