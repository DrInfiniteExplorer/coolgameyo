

module gui.guisystem.image;

import std.stdio;

import gui.guisystem.guisystem;


import graphics._2d.image;
import graphics.image;
import cgy.util.rect;
import cgy.util.util;



class GuiElementImage : GuiElement {
    
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

    void setImage(Image img) {
        image = img.toGLTex(image);
    }

    void setImageSource(Rectf source) {
        imgSource = source;
    }
    
    void setSize(uint pixWidth, uint pixHeight) {
        absoluteRect.size.set(pixWidth, pixHeight);
        setAbsoluteRect(absoluteRect);
    }

    void saveImage(string filename) {
        Image img;
        img.fromGLTex(image);
        img.save(filename);
    }

    override void render() {
        //Render background, etc, etc.
        renderImage(image, absoluteRect, imgSource);        
        super.render();
    }
}

