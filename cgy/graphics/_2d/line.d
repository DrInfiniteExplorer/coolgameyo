
module graphics._2d.line;

import std.algorithm;
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
    start.y = 1.0 - start.y;
    auto size = r.size.convert!float() / screenSize;
    start.y -= size.y;
    auto x = vec2f(size.x, 0);
    auto y = vec2f(0, size.y);
    ";

struct Lines{
    LineVertex[] vertices;
    
    void renderLines() {
        LineShader().render(this);
    }
    
    void makeGraph(T)(Recti r, const(T[]) values, T min, T max) {
        immutable offset = 0;
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

    void setLines(Recti r, vec2d[] points, vec3f color, vec2d _min = vec2d(0), vec2d _max = vec2d(0)) {
        immutable offset = 0;
        mixin(fixRect);
        double minX = double.max;
        double maxX = -minX;
        double minY = minX;
        double maxY = maxX;

        if(_min != _max) {
            minX = _min.x;
            maxX = _max.x;
            minY = _min.y;
            maxY = _max.y;
        } else {
            foreach(pt ; points) {
                minX = min(pt.x, minX);
                minY = min(pt.y, minY);
                maxX = max(pt.x, maxX);
                maxY = max(pt.y, maxY);
            }
        }

        double width = maxX - minX;
        double height = maxY - minY;
        vec2f fix(vec2d pt) {
            return start + (x+y) * (pt.convert!float - vec2f(minX, minY)) / vec2f(width, height);
        }
        foreach(pt ; points) {
            vertices ~= LineVertex(fix(pt), color);
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
    
    import util.singleton;
    mixin Singleton;

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
        //rect.start.y = 1.0 - rect.start.y;
        //program.setUniform(program.offset, rect.start);        
        //TODO: Use rest of rect for clipping?
        glEnableVertexAttribArray(lineProgram.position);
        glError();
        glEnableVertexAttribArray(lineProgram.color);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glError();
        glVertexAttribPointer(lineProgram.position, 2, GL_FLOAT, GL_FALSE, LineVertex.sizeof, &l.vertices[0].pos.x);
        glError();
        glVertexAttribPointer(lineProgram.color, 3, GL_FLOAT, GL_FALSE, LineVertex.sizeof, cast(void*)&l.vertices[0].color.x);
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

void renderLines(Lines l, vec3f color = vec3f(float.max)) {
    if (l.vertices.length <= 0) {
        return;
    }
    if(color != vec3f(float.max)) {
        l.setColor(color);
    }
    l.renderLines();
}

