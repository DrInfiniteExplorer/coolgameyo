
module graphics._2d.line;

import std.conv;
import std.exception;
import std.stdio;


import graphics.ogl;
import graphics.shader;
import settings;
import util.util;
import util.rect;
alias util.util.convert convert;

struct LineVertex {
    vec2f pos;
    vec3f color;
}


immutable(char[]) fixRect = "
    auto screenSize = vec2f(renderSettings.windowWidth-1, renderSettings.windowHeight-1);
    auto start = (vec2f(offset, offset) + r.start.convert!float()) / screenSize;
    start.Y = 1.0 - start.Y;
    auto size = r.size.convert!float() / screenSize;
    start.Y -= size.Y;
    auto x = vec2f(size.X, 0);
    auto y = vec2f(0, size.Y);
    ";

struct Lines{
    LineVertex[] vertices;
    
    void renderLines() {
        LineShader().render(this);
    }
    
    void makeGraph(T)(Recti r, const(T[]) values, T min, T max) {
        enum offset = 0;
        mixin(fixRect);
        double dx = 1.0 / to!(double)(values.length-1);
        vertices.length = values.length;

        double b = to!double(max - min);
        foreach(idx , value ; values) {    
            double a = to!double(value - min);
            double dy = a / b;
            vertices[idx].pos = start + x * to!(double)(idx) * dx + y * dy;
        }
    }
    
    void setColor(vec3f c) {
        foreach(ref v ; vertices) {
            v.color = c;
        }
    }
    
    //Implement different gradient setting methods.
    
}

class LineShader {
    alias ShaderProgram!("position", "color") LineProgram;
    LineProgram lineProgram;
    
    static LineShader ls;
    static opCall() {
        if (ls is null) {
            ls = new LineShader();
        }
        return ls;
    }
    
    private this() {
        lineProgram = new LineProgram("shaders/gui/lineShader.vert", "shaders/gui/lineShader.frag");
        lineProgram.position = lineProgram.getAttribLocation("position");
        lineProgram.color = lineProgram.getAttribLocation("in_color");
    }
    
    void destroy() {
        enforce(0, "Make sure to clean up and, uh. yeah.");
        lineProgram.destroy();
    }
    
    void render(Lines l) {
        //glEnable(GL_BLEND);
        //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        //glDisable(GL_DEPTH_TEST);
        //glDepthMask(0);
        lineProgram.use();
        //rect.start.Y = 1.0 - rect.start.Y;
        //program.setUniform(program.offset, rect.start);        
        //TODO: Use rest of rect for clipping?
        glEnableVertexAttribArray(lineProgram.position);
        glError();
        glEnableVertexAttribArray(lineProgram.color);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glError();
        glVertexAttribPointer(lineProgram.position, 2, GL_FLOAT, GL_FALSE, LineVertex.sizeof, &l.vertices[0].pos.X);
        glError();
        glVertexAttribPointer(lineProgram.color, 3, GL_FLOAT, GL_FALSE, LineVertex.sizeof, cast(void*)&l.vertices[0].color.X);
        glError();

        glDrawArrays(GL_LINE_STRIP, 0, l.vertices.length);
        glError();

        glDisableVertexAttribArray(lineProgram.position);
        glError();
        glDisableVertexAttribArray(lineProgram.color);
        glError();
        lineProgram.use(false);
        //glDepthMask(1);
        //glDisable(GL_BLEND);
        //glEnable(GL_DEPTH_TEST);        
    }
}

void renderLines(Lines l, vec3f color = vec3f(1.0, 1.0, 1.0)) {
    if (l.vertices.length <= 0) {
        return;
    }
    l.setColor(color);
    l.renderLines();
}

