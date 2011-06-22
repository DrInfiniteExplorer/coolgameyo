

module gui.guisystem.guisystem;

import std.exception;

import graphics._2d.rect;
import graphics.font;
import graphics.ogl;

public import util;
public import gui.guisystem.element;


final class GuiSystem : GuiElement{
    
    private GuiElement hoverElement;
    private GuiElement focusElement;
    
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



