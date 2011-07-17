

module gui.guisystem.simplegraph;

import std.stdio;

import gui.guisystem.guisystem;
import util;

import graphics._2d.rect;
import graphics._2d.line;

class GuiElementSimpleGraph(Type) : public GuiElement {
    
    Lines lines;
    uint length;
    Type min, max;

    this(GuiElement parent, Rectd relative) {
        super(parent);
        setRelativeRect(relative);
        onMove();
    }    
    
    void setData(Type[] data,  Type _min, Type _max) {
        length = data.length;
        min = _min;
        max = _max;
        lines.makeGraph(absoluteRect, data, min, max);
    }
    void setData(Type[] data) {
        Type min = Type.max;
        Type max = -Type.max;
        foreach( value ; data ) {
            min = std.algorithm.min(min, value);
            max = std.algorithm.max(max, value);
        }
        setData(data, min, max);
    }

    void setSize(uint pixWidth, uint pixHeight) {
        absoluteRect.size.set(pixWidth, pixHeight);
        setAbsoluteRect(absoluteRect);
    }
    void setSize(uint height) {
        absoluteRect.size.Y = height;
        setAbsoluteRect(absoluteRect);
    }

    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75));
        renderLines(lines, vec3f(1.0, 0, 0));
        super.render();
    }
}

