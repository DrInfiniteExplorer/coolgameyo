

module gui.guisystem.window;

import std.exception;

import graphics._2d.rect;

import gui.guisystem.guisystem;
import gui.guisystem.text;
import gui.guisystem.button;
import util.util;
import util.rect;



class GuiElementWindow : public GuiElement {
    private string caption;
    private bool dragable;
    
    private bool closeable;
    private PushButton closeButton;
    
    private bool dragging; //true when dragging
    vec2i dragHold; //Hold-position of window, kinda, yeah.
    private GuiElementText captionText;
    
    
    
    private Recti barRect;
    private Recti clientRect;
    private Recti closeRect;
    
    this(GuiElement parent, Rectd relative, string caption, bool dragAble = true, bool closeAble = true) {        
        super(parent);
        setRelativeRect(relative);
        setCaption(caption);
        setDragable(dragAble);
        setCloseable(closeAble);
    }    
    
    void setCaption(string text) {
        caption = text;
        if (captionText is null) {
            captionText = new GuiElementText(this, vec2d(0, 0), text);
            auto r = captionText.getAbsoluteRect();
            captionText.setAbsoluteRect(r.diff(r.heightOf / 2, 0, 0, 0));
        } else {
            captionText.setText(text);            
        }
        captionText.setColor(vec3f(1.0, 1.0, 1.0));
        recalcRects();
    }
    void setDragable(bool enable) {
        dragable = enable;
    }
    
    void setCloseable(bool enable) {
        if (closeable == enable) {
            return;
        }
        closeable = enable;
        if (enable) {
            closeButton = new PushButton(this, Rectd(0,0,1,1), "X", &onWindowClose);
            closeButton.setColor(vec3f(0, 0, 0));
            closeButton.setAbsoluteRect(closeRect);
        } else {
            if (closeButton) {
                closeButton.destroy();
                closeButton = null;
            }
        }
    }
    
    private void recalcRects() {
        if (captionText is null) {
            return;
        }
        auto size = captionText.getAbsoluteRect().size;
        getAbsoluteRect();
        barRect = absoluteRect;
        clientRect = absoluteRect;
        barRect.size.y = size.y;
        clientRect.start.y += size.y;
        clientRect.size.y -= size.y;
        
        closeRect = barRect;
        closeRect.start.x += closeRect.size.x - closeRect.size.y;
        closeRect.size.x = closeRect.size.y;
        closeRect.diff(vec2i(2, 2), vec2i(-2, -2));
    }
    
    override void onMove() {
        recalcRects();
        super.onMove();
    }    
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.85, 0.85, 0.5)); //Background color
        renderOutlineRect(clientRect, vec3f(0.0, 0.0, 1.0));
        renderRect(barRect, vec3f(1.0, 0.0, 0.0));
        renderOutlineRect(barRect, vec3f(0.0, 1.0, 0.0));
        super.render();
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if (!dragable) {
            return super.onEvent(e);
        }
        if (e.type == GuiEventType.MouseClick) {            
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    //barRect is in absolute coordinates already                    
                    if(barRect.isInside(m.pos)) {
                        dragging = true;
                        //Calculate relative drag-hold-position.                        
                        dragHold = absoluteRect.start - m.pos;
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
                auto r = absoluteRect;
                r.start = m.pos + dragHold;
                setAbsoluteRect(r);
                
                //Move window
                onMove();
                return GuiEventResponse.Accept;
            }
        }
        return super.onEvent(e);
    }
    
    void onWindowClose() {
        //Fire callback if got any registered, etc
        destroy();
    }

    Rectd clientArea() const @property {
        return absoluteRect.convert!double.getSubRectInv(clientRect.convert!double);
    }
    Recti clientAreaAbsolute() const @property {
        return absoluteRect.convert!double.getSubRect(clientArea).convert!int;
    }
    Rectd barArea() const @property {
        return absoluteRect.convert!double.getSubRectInv(barRect.convert!double);
    }
    Recti barAreaAbsolute() const @property {
        return absoluteRect.convert!double.getSubRect(barArea).convert!int;
    }
}
