
module graphics._2d.image;

import std.exception;


import graphics.ogl;
import graphics.shader;
import settings;
import util.util;
import util.rect;
//alias util.util.convert convert;

struct ImageRectVertex {
    vec2f pos;
    vec2f texcoord;
}


immutable(char[]) fixRect = q{
    auto screenSize = vec2f(renderSettings.windowWidth-1, renderSettings.windowHeight-1);
//    auto start = (vec2f(0.375, 0.375) + r.start.convert!float()) / screenSize;
    auto start = (vec2f(offset, offset) + r.start.convert!float()) / screenSize;
//    auto start = (r.start.convert!float()) / screenSize;
//    auto start = (r.start.convert!float());
    start.Y = 1.0 - start.Y;
    auto size = r.size.convert!float() / screenSize;
//    auto size = r.size.convert!float();
    size.Y = - size.Y;
    auto x = vec2f(size.X, 0);
    auto y = vec2f(0, size.Y);
};

struct ImageRectQuad{
    ImageRectVertex[4] vertices;
    
    void renderQuad() {
        ImageRectShader().render(this);
    }
    
    void setPosition(Recti r, float offset = 0) {
        mixin(fixRect);
        vertices[0].pos = start;
        vertices[1].pos = start + y;
        vertices[2].pos = start + size;
        vertices[3].pos = start + x;
//        vertices[0].pos.set(-1, -1);
//        vertices[1].pos.set(1, -1);
//        vertices[2].pos.set(1, 1);
//        vertices[3].pos.set(-1, 1);
        foreach(ref v ; vertices) {
            //v.pos += vec2f(0.25 / renderSettings.windowWidth, 0.25 / renderSettings.windowHeight);
        }
    }
    
    void setTexcoord(Rectf imgSource) {
        vertices[0].texcoord    = imgSource.start;
        vertices[1].texcoord    = imgSource.start;
        vertices[2].texcoord    = imgSource.start + imgSource.size;
        vertices[3].texcoord    = imgSource.start;
        vertices[1].texcoord.Y += imgSource.size.Y;
        vertices[3].texcoord.X += imgSource.size.X;
    }

}

class ImageRectShader {
    alias ShaderProgram!("position", "texcoord", "tex") ImageProgram;
    ImageProgram imageProgram;
    
    static ImageRectShader irs;
    static opCall() {
        if (irs is null) {
            irs = new ImageRectShader();
        }
        return irs;
    }
    
    private this() {
        imageProgram = new ImageProgram("shaders/gui/imageRectShader.vert", "shaders/gui/imageRectShader.frag");
        imageProgram.position = imageProgram.getAttribLocation("position");
        imageProgram.texcoord = imageProgram.getAttribLocation("texcoord");
        
        imageProgram.tex = imageProgram.getUniformLocation("tex");
    }
    
    void destroy() {
        enforce(0, "Make sure to clean up and, uh. yeah.");
        imageProgram.destroy();
    }
    
    void render(ImageRectQuad q) {
        //glEnable(GL_BLEND);
        //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        //glDisable(GL_DEPTH_TEST);
        //glDepthMask(0);
        imageProgram.use();
        //rect.start.Y = 1.0 - rect.start.Y;
        imageProgram.setUniform(imageProgram.tex, 2); //TODO: Make not hardcoded to texunit 2.        
        //TODO: Use rest of rect for clipping?
        glEnableVertexAttribArray(imageProgram.position);
        glError();
        glEnableVertexAttribArray(imageProgram.texcoord);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glError();
        glVertexAttribPointer(imageProgram.position, 2, GL_FLOAT, GL_FALSE, ImageRectVertex.sizeof, &q.vertices[0].pos.X);
        glError();
        glVertexAttribPointer(imageProgram.texcoord, 2, GL_FLOAT, GL_FALSE, ImageRectVertex.sizeof, cast(void*)&q.vertices[0].texcoord.X);
        glError();
        glDrawArrays(GL_QUADS, 0, 4);
        glError();

        glDisableVertexAttribArray(imageProgram.position);
        glError();
        glDisableVertexAttribArray(imageProgram.texcoord);
        glError();
        imageProgram.use(false);
        //glDepthMask(1);
        //glDisable(GL_BLEND);
        //glEnable(GL_DEPTH_TEST);        
    }
}

void renderImage(uint img, Recti r, Rectf imgSource = Rectf(0, 0, 1, 1), ) {
    ImageRectQuad quad;
    glActiveTexture(GL_TEXTURE2);
    glError();
    glBindTexture(GL_TEXTURE_2D, img);
    glError();

    quad.setPosition(r);
    quad.setTexcoord(imgSource);
    quad.renderQuad();
}

