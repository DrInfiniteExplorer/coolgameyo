

module gui.guisystem.button;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;


class GuiElementButton : public GuiElement {
    private string text;
    private GuiElementText buttonText;

    bool pushedDown;    
    
        
    this(GuiElement parent, Rect r, string text) {
        super(parent);
        setRect(r);
        setText(text);
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
    
    private void recalcRects() {
    }
    
    override void onMove() {
        recalcRects();
        super.onMove();
    }
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.5, 0.5, 0.5)); //Background color
        super.render();
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        /+
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
        +/
        return super.onEvent(e);
    }
}


