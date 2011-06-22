
module graphics._2d.rect;

import std.exception;

import util;
import graphics.ogl;
import graphics.shader;
import settings;

struct RectVertex {
    vec2f pos;
    vec3f color;
}


immutable(char[]) fixRect = "
    auto screenSize = vec2f(renderSettings.windowWidth-1, renderSettings.windowHeight-1);
//    auto start = (vec2f(0.375, 0.375) + convert!float(r.start)) / screenSize;
    auto start = (vec2f(offset, offset) + convert!float(r.start)) / screenSize;
//    auto start = (convert!float(r.start)) / screenSize;
//    auto start = (convert!float(r.start));
    start.Y = 1.0 - start.Y;
    auto size = convert!float(r.size) / screenSize;
//    auto size = convert!float(r.size);
    size.Y = - size.Y;
    auto x = vec2f(size.X, 0);
    auto y = vec2f(0, size.Y);
    ";

struct RectQuad{
    RectVertex[4] vertices;
    
    void renderQuad(bool lines = false, float stripes = 0) {
        RectShader().render(this, lines, stripes);
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
    
    void setUL(Recti r) {
        float offset = 0.5;
        mixin(fixRect);
    
        vertices[0].pos = start;
        vertices[1].pos = start + y;
        vertices[2].pos = start;
        vertices[3].pos = start + x;        
    }

    void setLR(Recti r) {
        float offset = 0.5;
        mixin(fixRect);
    
        vertices[0].pos = start + y;
        vertices[1].pos = start + size;
        vertices[2].pos = start + size;
        vertices[3].pos = start + x;        
    }
    
    void setColor(vec3f c) {
        foreach(ref v ; vertices) {
            v.color = c;
        }
    }
    
    //Implement different gradient setting methods.
    
}

class RectShader {
    alias ShaderProgram!("position", "color", "stripes") RectProgram;
    RectProgram rectProgram;
    
    static RectShader rs;
    static opCall() {
        if (rs is null) {
            rs = new RectShader();
        }
        return rs;
    }
    
    private this() {
        rectProgram = new RectProgram("shaders/rectShader.vert", "shaders/rectShader.frag");
        rectProgram.position = rectProgram.getAttribLocation("position");
        rectProgram.color = rectProgram.getAttribLocation("in_color");    
        rectProgram.stripes = rectProgram.getUniformLocation("stripes");
    }
    
    void destroy() {
        enforce(0, "Make sure to clean up and, uh. yeah.");
        rectProgram.destroy();
    }
    
    void render(RectQuad q, bool lines, float stripes) {
        //glEnable(GL_BLEND);
        //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        //glDisable(GL_DEPTH_TEST);
        //glDepthMask(0);
        rectProgram.use();
        rectProgram.setUniform(rectProgram.stripes, stripes);
        //rect.start.Y = 1.0 - rect.start.Y;
        //program.setUniform(program.offset, rect.start);        
        //TODO: Use rest of rect for clipping?
        glEnableVertexAttribArray(rectProgram.position);
        glError();
        glEnableVertexAttribArray(rectProgram.color);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glError();
        glVertexAttribPointer(rectProgram.position, 2, GL_FLOAT, GL_FALSE, RectVertex.sizeof, &q.vertices[0].pos.X);
        glError();
        glVertexAttribPointer(rectProgram.color, 3, GL_FLOAT, GL_FALSE, RectVertex.sizeof, cast(void*)&q.vertices[0].color.X);
        glError();
        if (lines) {
            glDrawArrays(GL_LINES, 0, 4);
            glError();
        } else {
            glDrawArrays(GL_QUADS, 0, 4);
            glError();
        }

        glDisableVertexAttribArray(rectProgram.position);
        glError();
        glDisableVertexAttribArray(rectProgram.color);
        glError();
        rectProgram.use(false);
        //glDepthMask(1);
        //glDisable(GL_BLEND);
        //glEnable(GL_DEPTH_TEST);        
    }
}

void renderRect(Recti r, vec3f color = vec3f(1.0, 1.0, 1.0), float stripes = 0) {
    RectQuad quad;
    quad.setPosition(r);    
    quad.setColor(color);
    quad.renderQuad(false, stripes);
}

void renderOutlineRect(Recti r, vec3f color = vec3f(1.0, 1.0, 1.0), float stripes = 0) {
    auto old = setWireframe(true);
    r = r.diff(vec2i(0,0), vec2i(-1,-1));
    RectQuad quad;
    quad.setPosition(r, 0.5);    
    quad.setColor(color);
    quad.renderQuad(false, stripes);
    setWireframe(old);
}


void renderXXRect(Recti r, vec3f color, bool UL) {
    RectQuad quad;
    r = UL ?
        r.diff(vec2i(0, 0), vec2i(0 , 0)) :
        r.diff(vec2i(0,-1), vec2i(-1,-1));
    UL ? quad.setUL(r) : quad.setLR(r);
    quad.setColor(color);
    auto old = setWireframe(true);
    quad.renderQuad(true);
    setWireframe(old);    
}

/*
Rectd pixDiff(Rectd r, vec2i startOffset, vec2i stopOffset) {
    auto perPixel = vec2d(1.0 / renderSettings.windowWidth, 1.0 / renderSettings.windowHeight);
    auto add = convert!double(startOffset) * perPixel;
    return Rectd(
        r.start + add,
        r.size + convert!double(stopOffset) * perPixel - add
    );
}
*/
