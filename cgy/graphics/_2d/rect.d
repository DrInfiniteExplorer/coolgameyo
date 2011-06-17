
module graphics._2d.rect;

import std.exception;

import util;
import graphics.ogl;
import graphics.shader;

struct RectVertex {
    vec2f pos;
    vec3f color;
}

struct RectQuad{
    RectVertex[4] vertices;
    
    void renderQuad() {
        RectShader().render(this);
    }
    
    void setPosition(Rect r) {
        auto start = convert!float(r.start);
        start.Y = 1.0 - start.Y;
        auto size = convert!float(r.size);
        size.Y = - size.Y;
        auto x = vec2f(size.X, 0);
        auto y = vec2f(0, size.Y);
    
        vertices[0].pos = start;
        vertices[1].pos = start + y;
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
    alias ShaderProgram!("position", "color") RectProgram;
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
    }
    
    void destroy() {
        enforce(0, "Make sure to clean up and, uh. yeah.");
        rectProgram.destroy();
    }
    
    void render(RectQuad q) {
        //glEnable(GL_BLEND);
        //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        //glDisable(GL_DEPTH_TEST);
        //glDepthMask(0);
        rectProgram.use();
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
        glDrawArrays(GL_QUADS, 0, 4);
        glError();

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

void renderRect(Rect r, vec3f color = vec3f(1.0, 1.0, 1.0)) {
    RectQuad quad;
    quad.setPosition(r);    
    quad.setColor(color);
    quad.renderQuad();
}

void renderOutlineRect(Rect r, vec3f color = vec3f(1.0, 1.0, 1.0)) {
    auto old = setWireframe(true);
    renderRect(r, color);
    setWireframe(old);
}

