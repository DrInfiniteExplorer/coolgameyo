

module gui.guisystem.window;

import graphics._2d.rect;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import util;

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
        captionText.setColor(vec3f(1.0, 1.0, 1.0));
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
        renderRect(absoluteRect, vec3f(0.5, 0.5, 0.5)); //Background color
        renderOutlineRect(clientRect, vec3f(0.0, 0.0, 1.0));
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
