

module gui.guisystem.simplegraph;

import std.algorithm : reduce, min, max;
import std.stdio;

import gui.guisystem.guisystem;


import graphics._2d.rect;
import graphics._2d.line;
import util.util;
import util.rect;

class GuiElementSimpleGraph(Type) : GuiElement {
    
    private Lines lines;
    private uint length;
    private Type min, max;
    private bool transparent;
    private vec3f color = vec3f(1.0f, 0.0f, 0.0f);

    this(GuiElement parent, Rectd relative, bool transparent) {
        super(parent);
        setRelativeRect(relative);
        onMove();
        setTransparent(transparent);
    }    
    
    void setData(const(Type)[] data,  Type _min, Type _max) {
        length = cast(int)data.length;
        min = _min;
        max = _max;
        lines.makeGraph(absoluteRect, data, min, max);
    }
    void setData(const(Type)[] data) {
        Type min = Type.max;
        Type max = -Type.max;
        min = reduce!(std.algorithm.min)(data);
        max = reduce!(std.algorithm.max)(data);
        setData(data, min, max);
    }

    void setSize(uint pixWidth, uint pixHeight) {
        absoluteRect.size.set(pixWidth, pixHeight);
        setAbsoluteRect(absoluteRect);
    }
    void setSize(uint height) {
        absoluteRect.size.y = height;
        setAbsoluteRect(absoluteRect);
    }
    
    void setTransparent(bool trans) {
        transparent = trans;
    }
    void setColor(vec3f color) {
        this.color = color;
    }

    override void render() {
        //Render background, etc, etc.
        if (!transparent) {
            renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75));
        }
        renderLines(lines, color);
        renderOutlineRect(absoluteRect, vec3f(0, 0, 0));
        super.render();
    }
}

