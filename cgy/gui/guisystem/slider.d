
module gui.guisystem.slider;

import std.algorithm;
import std.conv;
import std.stdio;
import std.traits;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;

class GuiElementSlider(ValueType) : public GuiElement {

    alias void delegate(ValueType value) ChangeCallback;    
    ChangeCallback cb;
    
    protected GuiElementText valueText;
    private ValueType min, max;
    private ValueType value;
    private bool pushedDown;
            
    this(GuiElement parent, Rectd relative, ValueType _value, ValueType _min, ValueType _max, ChangeCallback _cb = null) {
        super(parent);
        setRelativeRect(relative);
        min = _min;
        max = _max;
        value = _value;
        cb = _cb;
        onMove();
    }    
        
    override void onMove() {
        if (valueText) {
            //Asd asd
        }
        super.onMove();        
    }
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75)); //Background color
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
        
        Recti lineRect = Recti(0, 0, absoluteRect.size.X, 4);
        lineRect = absoluteRect.centerRect(lineRect);
        renderRect(lineRect, vec3f(0, 0, 0) );
        
        Recti sliderRect = Recti(-2, 0, 4, absoluteRect.size.Y);
        sliderRect.start += absoluteRect.start;
        sliderRect.start.X += to!int(to!ValueType(absoluteRect.size.X) * ((value-min) / (max-min)));
        renderRect(sliderRect, vec3f(0.75, 0.75, 0.75));

        if(pushedDown) {
            //Use any indicator when slider is pressed down? Other color of slidery thing?
            //renderOutlineRect(inner, vec3f(0.5, 0.5, 0.5));
        }
        

        super.render();
    }
    
    void repositionSlider(float relativeX) {
        relativeX = std.algorithm.max(relativeX, 0.0);
        relativeX = std.algorithm.min(relativeX, 1.0);
        
        value = relativeX * (max-min) + min;
        if (cb !is null) {
            cb(value);
        }
        
        updateText();        
    }
    
    void updateText() {
        if (valueText is null) {
            valueText = new GuiElementText(this, vec2d(0, 0), "");
        }
        valueText.setColor(vec3f(1.0, 1.0, 1.0));
        string str;
        static if (isIntegral!(ValueType)) {
            str = to!string(value);
        } else {
            //TODO: Special formatting for float values!
            str = to!string(value);
        }
        valueText.setText(str);
    }
        
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
                        pushedDown = true;
                        auto fAbs = util.convert!double(absoluteRect);
                        auto fPos = util.convert!double(m.pos);
                        //TODO: Figure out why the following lines causes a compiler crash but the once above dont
                        //auto fAbs = util.convert!float(absoluteRect);
                        //auto fPos = util.convert!float(m.pos);
                        auto relative = fAbs.getRelative(fPos);
                        repositionSlider(relative.X);
                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    pushedDown = false;
                    return GuiEventResponse.Accept;
                }
            }
        } else if (e.type == GuiEventType.MouseMove) {
            if (pushedDown) {
                auto m = &e.mouseMove;
                auto fAbs = util.convert!double(absoluteRect);
                auto fPos = util.convert!double(m.pos);
                auto relative = fAbs.getRelative(fPos);
                repositionSlider(relative.X);
                return GuiEventResponse.Accept;
            }
        }
        return super.onEvent(e);
    }
}


