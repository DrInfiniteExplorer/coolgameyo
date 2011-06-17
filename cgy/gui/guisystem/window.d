

module gui.guisystem.window;

import std.exception;

import graphics._2d.rect;

import gui.guisystem.guisystem;
import gui.guisystem.text;
import gui.guisystem.button;

import util;

class GuiElementWindow : public GuiElement {
    private string caption;
    private bool dragable;
    
    private bool closeable;
    private GuiElementButton closeButton;
    
    private bool dragging; //true when dragging
    vec2d dragHold; //Hold-position of window, kinda, yeah.
    private GuiElementText captionText;
    
    
    
    private Rect barRect;
    private Rect clientRect;
    private Rect closeRect;
    
    this(GuiElement parent, Rect r, string caption, bool dragAble = true, bool closeAble = true) {
        super(parent);
        setRect(r);
        setCaption(caption);
        setDragable(dragAble);
        setCloseable(closeAble);
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
    
    void setCloseable(bool enable) {
        if (closeable == enable) {
            return;
        }
        closeable = enable;
        if (enable) {
            Rect r;
            closeButton = new GuiElementButton(this, closeRect, "X", (bool down, bool abort){
                if (!down && !abort) {
                    onWindowClose();
                }
            });
            closeButton.setColor(vec3f(0, 0, 0));
        } else {
            if (closeButton) {
                closeButton.destroy();
                closeButton = null;
            }
        }
    }
    
    private void recalcRects() {
        auto size = captionText.getRect().size;
        absoluteRect = getAbsoluteRect();
        barRect = absoluteRect;
        clientRect = absoluteRect;
        barRect.size.Y = size.Y;
        clientRect.start.Y += size.Y;
        clientRect.size.Y -= size.Y;
        
        closeRect = barRect;
        closeRect.start.X += closeRect.size.X - closeRect.size.Y;
        closeRect.size.X = closeRect.size.Y;
        closeRect = pixDiff(closeRect, vec2i(2, 2), vec2i(-2, -2));
        closeRect = absoluteRect.getSubRectInv(closeRect);        
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
    
    void onWindowClose() {
        //Fire callback if got any registered, etc
        destroy();
    }
}
