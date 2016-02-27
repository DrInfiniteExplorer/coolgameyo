

module gui.guisystem.progressbar;

import std.conv;
import std.stdio;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import cgy.util.util;
import cgy.util.rect;


class GuiElementProgressBar : GuiElement {
    protected GuiElementText text;
    protected uint max;
    protected uint progress;
    protected string title;
    protected Recti progressBar;

    this(GuiElement parent, Rectd relative, string _title, uint _max, uint _progress = uint.init) {
        max = _max;
        title = _title;
        super(parent);
        setRelativeRect(relative);
        setProgress(_progress);
        updateText();
        setColor(vec3f(0,0,0));
        onMove();
    }    

    void setTitle(string str) {
        title = str;
    }
    void setMax(uint val) {
        max = val;
    }
    double oldRatio;
    void setProgress(uint val) {
        progress = val;
        progressBar = absoluteRect.diff(1,1,-1,-1);
        double ratio;
        if (max != 0) {
            ratio = to!double(progress) / to!double(max);
        } else {
            ratio = 0;
        }
        auto oldX = progressBar.size.x;
        progressBar.size.x = cast(int)( ratio * cast(double)progressBar.size.x);
        if(oldRatio != ratio) {
            oldRatio = ratio;
            updateText();
        }
    }
    
    private void updateText() {
        auto str = std.conv.text(title, "(", progress, "/", max, ")");
        if (text is null) {
            text = new GuiElementText(this, vec2d(0, 0), str);
        } else {
            text.setText(str);            
        }
        text.setColor(vec3f(1.0, 1.0, 1.0));
    }
    
    void setColor(vec3f c) {
        text.setColor(c);
    }
        
    override void onMove() {
        if (text !is null) {
            auto buttonSize = text.getSize();
            auto newTextRect = absoluteRect.centerRect(Recti(vec2i(0, 0), buttonSize));
            text.setAbsoluteRect(newTextRect);        
        }
        super.onMove();        
    }
    
    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75)); //Background color
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
        renderRect(progressBar, vec3f(0, 0.75, 0));

        super.render();
    }
    
}


