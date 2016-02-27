
module gui.guisystem.slider;

import std.algorithm;
import std.conv;
import std.stdio;
import std.traits;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import util.util;
import util.rect;

class GuiElementSlider(ValueType) : GuiElement {

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
        updateText();
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
        
        Recti lineRect = Recti(0, 0, absoluteRect.size.x, 4);
        lineRect = absoluteRect.centerRect(lineRect);
        renderRect(lineRect, vec3f(0, 0, 0) );
        
        Recti sliderRect = Recti(-2, 0, 4, absoluteRect.size.y);
        sliderRect.start += absoluteRect.start;
        int startX = cast(int)(absoluteRect.size.x * (cast(float)(value-min) / (max-min)));
        sliderRect.start.x += startX;
        renderRect(sliderRect, vec3f(0.75, 0.75, 0.75));
        renderOutlineRect(sliderRect, vec3f(0.0));

        if(pushedDown) {
            //Use any indicator when slider is pressed down? Other color of slidery thing?
            //renderOutlineRect(inner, vec3f(0.5, 0.5, 0.5));
        }
        

        super.render();
    }
    
    void repositionSlider(float relativeX) {
        relativeX = std.algorithm.max(relativeX, 0.0);
        relativeX = std.algorithm.min(relativeX, 1.0);
        
        value = cast(ValueType) (relativeX * (max-min) + min);
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
        
    override GuiEventResponse onEvent(InputEvent e) {
        if (auto m = cast(MouseClick)e) {
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
                        pushedDown = true;
                        auto fAbs = absoluteRect.convert!double;
                        auto fPos = m.pos.convert!double();
                        //TODO: Figure out why the following lines causes a compiler crash but the once above dont
                        //auto fAbs = absoluteRect.convert!float();
                        //auto fPos = m.pos.convert!float();
                        auto relative = fAbs.getRelative(fPos);
                        repositionSlider(relative.x);
                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    pushedDown = false;
                    return GuiEventResponse.Accept;
                }
            }
        } else if (auto m = cast(MouseMove)e) {
            if (pushedDown) {
                auto fAbs = absoluteRect.convert!double;
                auto fPos = m.pos.convert!double();
                auto relative = fAbs.getRelative(fPos);
                repositionSlider(relative.x);
                return GuiEventResponse.Accept;
            }
        }
        return super.onEvent(e);
    }
}


