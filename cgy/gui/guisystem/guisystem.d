

module gui.guisystem.guisystem;

import std.conv;
import std.exception;


import graphics._2d.rect;
import graphics.font;
import graphics.ogl;

public import util;
public import gui.guisystem.element;

interface GuiEventDump {
    GuiEventResponse onDumpEvent(GuiEvent e);
    void tick(float dTime);
}

final class GuiSystem : GuiElement{
    
    alias void delegate() HotkeyCallback;
    
    private HotkeyCallback[int] hotkeys;
    
    private GuiElement hoverElement;
    private GuiElement focusElement;
    
    private GuiEventDump eventDump;
    
    this() {
        super(null);
        setFont(new Font("fonts/courier"));
        relativeRect = Rectd(vec2d(0, 0), vec2d(1, 1));
        hoverElement = this;
        focusElement = this;
        getAbsoluteRect();
    }
    
    override bool isInside(vec2i p) {
        return true;
    }
    
    void addHotkey(int key, HotkeyCallback cb) {
        enforce(key !in hotkeys, text("Key ", key, " already in hotkey-callbacks"));
        hotkeys[key] = cb;
    }
    
    void removeHotkey(int key) {
        enforce(key in hotkeys, text("Trying to remove key ",key, " from callbacks when not registered"));
        hotkeys.remove(key);
    }
    
    void setEventDump(GuiEventDump d)
    in{
        if (d !is null) {
            enforce(eventDump is null, "eventDump !is null, programming erroooaaarr~~~!");
        }
    }
    body{
        eventDump = d;
    }    

    override void setFocus(GuiElement e) {
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
    
    override GuiElement getFocusElement() {
        return focusElement;
    }
    
    private void setHover(vec2i pos) {
        auto element = getElementFromPoint(pos);
        if (hoverElement != element) {
            GuiEvent hoverEvent;
            hoverEvent.type = GuiEventType.HoverOn;
            element.onEvent(hoverEvent);
            hoverEvent.type = GuiEventType.HoverOff;
            hoverElement.onEvent(hoverEvent);
            hoverElement = element;
        }
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        switch (e.type) {
            case GuiEventType.MouseMove:
                auto move = e.mouseMove;
                setHover(move.pos);
                if(focusElement && focusElement != this) {
                    auto ret = focusElement.onEvent(e);
                    if (ret != GuiEventResponse.Ignore) {
                        return ret;
                    }
                }                
                break;
            case GuiEventType.MouseClick:
                auto m = e.mouseClick;
                setHover(m.pos);
                if (m.left && m.down) {
                    setFocus(hoverElement);
                }
                if(focusElement && focusElement != this) {
                    auto ret = focusElement.onEvent(e);
                    if (ret != GuiEventResponse.Ignore) {
                        return ret;
                    }
                }
                break;
           case GuiEventType.Keyboard:
               //Handle hotkeys with modifiers, like ctrl+k
               //Got focused object? Give him input
               if (focusElement && focusElement != this) {
                   auto ret = focusElement.onEvent(e);
                   if (ret != GuiEventResponse.Ignore) {
                       return ret;                   
                   }
               }
               //Handle other hotkeys
               auto kb = e.keyboardEvent;
               if (kb.pressed) {
                   auto sym = kb.SdlSym;
                   if (sym in hotkeys) {
                       hotkeys[sym]();
                       return GuiEventResponse.Accept;
                   }
               }
               //Else if non-focus-object'ish registered, send to it. (player walking etc..)
               //Will be done automagically after this here break.
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
        if (eventDump !is null) {
            return eventDump.onDumpEvent(e);
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
    
    override void tick(float dTime) {
        if (eventDump !is null) {
            eventDump.tick(dTime);
        }
        super.tick(dTime);
    }
}



