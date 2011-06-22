



module gui.guisystem.checkbox;

import std.stdio;

import gui.guisystem.guisystem;
import gui.guisystem.button;
import gui.guisystem.text;

import graphics._2d.rect;

enum checkboxSizeInPixels = 12;


class GuiElementCheckBox : public GuiElementButton {    
    
    protected bool checked;
    
    this(GuiElement parent, Rectd relative, string text, PressCallback cb = null) {
        super(parent, relative, text, cb);
    }    
    
    override void setText(string str) {
        super.setText(str);
        //auto buttonSize = buttonText.getSize();
        auto textRect = Recti(vec2i(0, 0), buttonText.getSize());
        textRect = absoluteRect.centerRect(textRect, false);
        textRect = textRect.diff(vec2i(checkboxSizeInPixels+2, 0), vec2i(0, 0));
        buttonText.setAbsoluteRect(textRect);
    }

    override void onPushed(bool down, bool abort){
        if (!down && !abort) {
            checked = !checked;
        }
        super.onPushed(down, abort);
    }
    
    void setChecked(bool c) {
        checked = c;
    }
    
    bool getChecked() {
        return checked;
    }
    
    override void render() {
        auto r = absoluteRect;
        renderOutlineRect(r, vec3f(1, 0, 0));
        auto checkSize = Recti(vec2i(0,0), vec2i(checkboxSizeInPixels, checkboxSizeInPixels));
        auto rect = r.centerRect(checkSize, false);
        
        renderRect(rect, vec3f(1.0, 1.0, 1.0));
        renderXXRect(rect, vec3f(0.5, 0.5, 0.5), true);
        renderXXRect(rect, vec3f(0.75, 0.75, 0.75), false);
        rect = rect.diff(vec2i(1, 1), vec2i(-1, 0));
        renderXXRect(rect, vec3f(0.25, 0.25, 0.25), true);
        //rect = pixDiff(rect, vec2i(1, 1), vec2i(0, 0));
        
        if (checked) {
            renderRect(rect, vec3f(0.75, 0.75, 0.75), 1);
        }
        if(pushedDown){
            renderRect(rect, vec3f(0.5, 0.5, 0.5), true);
        }
        GuiElement.render();
    }
}


