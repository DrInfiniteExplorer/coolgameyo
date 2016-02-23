

module gui.guisystem.guisystem;

import std.conv;
import std.exception;


import graphics._2d.rect;
import graphics.font;
import graphics.ogl;
import util.memory;
import util.rect;
import util.util;

public import gui.guisystem.element;
import gui.guisystem.imagecache;

interface GuiEventDump {
    GuiEventResponse onDumpEvent(GuiEvent e);
    void tick(float dTime);
    void activate(bool activate);
}

final class GuiSystem : GuiElement {
    
    alias void delegate() HotkeyCallback;
    
    private HotkeyCallback[int] hotkeys;
    
    private GuiElement hoverElement;
    private GuiElement focusElement;
    
    private GuiEventDump eventDump;

    private Font standardFont;    

    ImageCache imageCache;
    
    this() {
        guiSystem = this;
        super(null);
        standardFont = new Font("fonts/courier");
        setFont(standardFont);
        relativeRect = Rectd(vec2d(0, 0), vec2d(1, 1));
        hoverElement = this;
        focusElement = this;
        getAbsoluteRect();

        imageCache = new ImageCache;
    }
    
    private bool destroyed;
    ~this() {
        BREAK_IF(!destroyed);
    }
    
    override void destroy() {
        destroyed = true;
        super.destroy();
        if (standardFont !is null) {
            standardFont.destroy();
            standardFont = null;
        }
        imageCache.destroy();
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
    
    GuiEventDump setEventDump(GuiEventDump d)
    in{
        if (d !is null) {
            enforce(eventDump is null, "eventDump !is null, programming erroooaaarr~~~!");
        }
    }
    body{
        auto old = eventDump;
        if (eventDump !is null) {
            eventDump.activate(false);
        }
        eventDump = d;
        if (eventDump !is null) {
            eventDump.activate(true);
        }
        return old;
    }    

    override void setFocus(GuiElement e) {
        if (e == focusElement) {
            return;
        }
        auto oldElement = focusElement;
        focusElement = e;
        if (focusElement) {
            GuiEvent event;
            event.type = GuiEventType.FocusOn;
            while(focusElement != this) {
                if (focusElement.onEvent(event) != GuiEventResponse.Reject) {
                    break;
                }
                focusElement = focusElement.getParent();
                if (focusElement == oldElement) {
                    return;
                }
            }
        }
        //Lololol maybe problem layer (solves things loosing focus, then setting focus on text in them which is rejected)
        // maybe add willAcceptFocus?()-functionality instead
        if (oldElement) {
            GuiEvent event;
            event.type = GuiEventType.FocusOff;
            oldElement.onEvent(event);
        }
    }
    
    override GuiElement getFocusElement() {
        return focusElement;
    }

    override GuiElement getNext() {
        return null;
    }

    override void cycleFocus() {
//        BREAKPOINT; //Finish implementing later, derp
        auto focus = focusElement;
        if(focus is null) {
            focus = super.getNext();
        } else {
            focus = focus.getNext();
        }
        while(focus && !focus.isSelectable) {
            focus = focus.getNext();
        }
        setFocus(focus);
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
            case GuiEventType.MouseWheel:
                auto m = e.mouseWheel;
                if (hoverElement != focusElement) {
                    if (hoverElement !is null) {
                        auto ret = hoverElement.onEvent(e);
                        if(ret != GuiEventResponse.Ignore) {
                            return ret;
                        }
                        break;
                    }
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
        //mixin(MemDiff!("guisystem.tick"));
        super.tick(dTime);
    }
}
