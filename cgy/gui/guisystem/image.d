

module gui.guisystem.image;

import std.stdio;

import gui.guisystem.guisystem;
import util;

import graphics._2d.image;



class GuiElementImage : public GuiElement {
    
    uint image;
    Rectf imgSource;
    //TODO: Figure out why this makes dmd hang: Rectf imgSource = Rectf(0, 0, 1, 1);

    this(GuiElement parent, Rectd relative, uint glTexture = 0) {
        super(parent);
        setRelativeRect(relative);
        imgSource = Rectf(0, 0, 1, 1);
        onMove();
    }    
    
    void setImage(uint img) {
        image = img;
    }

    void setImageSource(Rectf source) {
        imgSource = source;
    }
    
    void setSize(uint pixWidth, uint pixHeight) {
        absoluteRect.size.set(pixWidth, pixHeight);
        setAbsoluteRect(absoluteRect);
    }

    override void render() {
        //Render background, etc, etc.
        renderImage(image, absoluteRect, imgSource);        
        super.render();
    }
}

