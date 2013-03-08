module graphics.heightmap;

import std.algorithm : max, map, reduce;
import std.getopt;

import derelict.sdl.sdl;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import gui.all;
import gui.util;
import main : g_commandLine, handleSDLEvent;
import math.math;
import math.vector;
import util.filesystem;
import util.rangefromto : Range2D;
import util.util : BREAK_IF, msg, utime;

immutable vertShaderSource = q{
    #version 150 core
    in vec3 vert;
    in vec3 norm;
    in vec4 col;
    uniform mat4 transform;
    out vec3 normal;
    out vec4 color;
    void main() {
        gl_Position = (transform * vec4(vert, 1.0));
        normal = norm;
        color = col;
    }
};
immutable fragShaderSource = q{
    #version 150 core
    #extension GL_ARB_explicit_attrib_location : enable
    in vec3 normal;
    in vec4 color;
    layout(location = 0) out vec4 frag_color;
    layout(location = 1) out vec4 light;
    //layout(location = 2) out vec4 depth;
    void main() {
        vec3 n = normalize(normal);
        vec3 sun = normalize(vec3(0.1, 0.1, 1));
        light = vec4(1.0, 1.0, 1.0, 1.0);
        frag_color = dot(n, sun) * color;
    }
};

class Heightmap : ShaderProgram!() {

    float[] map;
    vec3f[] colorMap;
    float[3][] triangles;
    float[3][] normals;

    float width;
    float depth;
    float height;

    int sizeX;
    int sizeY;

    uint triVbo;
    uint normVbo;
    uint colorVbo;
    uint vao;

    bool rebuild;

    this() {
        super();
        compileSource!true(vertShaderSource);
        compileSource!false(fragShaderSource);
        link();
    }
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    override void destroy() {
        super.destroy();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        if(triVbo) {
            glDeleteBuffers(1, &triVbo);
        }
        if(normVbo) {
            glDeleteBuffers(1, &normVbo);
        }
        if(colorVbo) {
            glDeleteBuffers(1, &colorVbo);
        }
        if(vao) {
            glBindVertexArray(0);
            glDeleteVertexArrays(1, &vao);
            vao = 0;
        }
        destroyed = true;
    }

    float widthPerCell() const {
        return width / sizeX;
    }
    float heightPerCell() const {
        return height / sizeY;
    }

    void load(float[] data) {
        auto len = data.length;
        auto sqrtLen = sqrt(cast(real)len);
        sizeY = sizeX = cast(int)sqrtLen;
        width = height = sizeX;
        BREAK_IF(sqrtLen != sizeX);
        BREAK_IF(sizeX ^^ 2 != len);
        map = data.dup;
        rebuild = true;
    }

    float maxHeight() {
        return reduce!max(map);
    }
    vec3f getCenter() {
        float posX = (sizeX-1.0) * 0.5;
        float posY = (sizeY-1.0) * 0.5;
        float posZ = reduce!"a+b"(map);
        posZ /= ((sizeX-1) * (sizeY-1));
        return vec3f(posX, posY, posZ); 
    }

    void load(string path) {
        BREAKPOINT;
        // Load image, convert to heightmap.
        rebuild = true;
    }

    float getVal(int x, int y) {
        x = clamp(x, 0, sizeX-1);
        y = clamp(y, 0, sizeY-1);
        return map[x + y * sizeX];
    }

    float[3] getNormal(int x, int y) {
        float[3] ret = void;
        vec3f toX = vec3f(2*widthPerCell, 0, getVal(x-1, y) - getVal(x+1, y));
        vec3f toY = vec3f(0, 2*heightPerCell, getVal(x, y-1) - getVal(x, y+1));
        auto normal = toX.normalizeThis.crossProduct(toY.normalizeThis);
        //normal.z += 0.05;
        normal.normalizeThis;
        ret[0] = normal.x;
        ret[1] = normal.y;
        ret[2] = normal.z;
        return ret;
    }
    float alpha = 0.0;
    float[4] getColor(int x, int y) {
        auto c = colorMap[y * sizeX + x].tupleof;
        float[4] ret;
        ret[0] = c[0];
        ret[1] = c[1];
        ret[2] = c[2];
        ret[3] = alpha;
        return ret;
    }

    void setColor(vec3f[] colors) {
        colorMap = colors;
        rebuild = true;
    }
    void setColor(vec3f color) {
        colorMap.length = 1;
        colorMap[0] = color;
        rebuild = true;
    }

    void build() {
        rebuild = false;
        int len = 6 * (sizeX-1)*(sizeY-1);
        triangles.length = len;
        normals.length = len;
        float[4][] colors;
        if(colorMap.length > 1) {
            colors.length = len;
        }

        foreach(x, y ; Range2D(0, sizeX-1, 0, sizeY-1)) {
            auto idx = x + y * (sizeX-1);
            auto Idx = idx * 6;
            normals[x + y * (sizeX-1)] = getNormal(x, y);
            triangles[Idx+0] = [x, y, getVal(x, y)];
            triangles[Idx+1] = [x+1, y, getVal(x+1, y)];
            triangles[Idx+2] = [x, y+1, getVal(x, y+1)];
            triangles[Idx+3] = [x, y+1, getVal(x, y+1)];
            triangles[Idx+4] = [x+1, y, getVal(x+1, y)];
            triangles[Idx+5] = [x+1, y+1, getVal(x+1, y+1)];
            normals[Idx+0] = getNormal(x, y);
            normals[Idx+1] = getNormal(x+1, y);
            normals[Idx+2] = getNormal(x+1, y+1);
            normals[Idx+3] = getNormal(x, y+1);
            normals[Idx+4] = getNormal(x+1, y);
            normals[Idx+5] = getNormal(x+1, y+1);
            if(colorMap.length > 1) {
                colors[Idx+0] = getColor(x, y);
                colors[Idx+1] = getColor(x+1, y);
                colors[Idx+2] = getColor(x+1, y+1);
                colors[Idx+3] = getColor(x, y+1);
                colors[Idx+4] = getColor(x+1, y);
                colors[Idx+5] = getColor(x+1, y+1);
            }
        }
        if(triVbo) {
            glDeleteBuffers(1, &triVbo); glError();
            triVbo = 0;
        }
        if(normVbo) {
            glDeleteBuffers(1, &normVbo); glError();
            normVbo = 0;
        }
        if(colorVbo) {
            glDeleteBuffers(1, &colorVbo); glError();
            colorVbo = 0;
        }
        if(!vao) {
            glGenVertexArrays(1, &vao); glError();
        }
        glBindVertexArray(vao);
        auto triSize = triangles.length * triangles[0].sizeof;
        auto normSize = normals.length * normals[0].sizeof;
        auto colorSize = colors.length * colors[0].sizeof;

        glGenBuffers(1, &triVbo); glError();
        glBindBuffer(GL_ARRAY_BUFFER, triVbo); glError();
        glBufferData(GL_ARRAY_BUFFER, triSize, triangles.ptr, GL_STATIC_DRAW); glError();
        glVertexAttribPointer(0u, 3, GL_FLOAT, GL_FALSE, triangles[0].sizeof, null); glError();
        glEnableVertexAttribArray(0); glError();

        glGenBuffers(1, &normVbo); glError();
        glBindBuffer(GL_ARRAY_BUFFER, normVbo); glError();
        glBufferData(GL_ARRAY_BUFFER, normSize, normals.ptr, GL_STATIC_DRAW); glError();
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, normals[0].sizeof, null); glError();
        glEnableVertexAttribArray(1); glError();

        if(colorMap.length > 1) {
            glGenBuffers(1, &colorVbo); glError();
            glBindBuffer(GL_ARRAY_BUFFER, colorVbo); glError();
            glBufferData(GL_ARRAY_BUFFER, colorSize, colors.ptr, GL_STATIC_DRAW); glError();
            glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, colors[0].sizeof, null); glError();
            glEnableVertexAttribArray(2); glError();
        } else if(colorMap.length == 1) {
            glVertexAttrib4f(2, colorMap[0].x, colorMap[0].y, colorMap[0].z, alpha);
            glDisableVertexAttribArray(2); glError();
        } else {
            glVertexAttrib3f(2, 1, 1, 1);
            glDisableVertexAttribArray(2); glError();
        }

        glBindVertexArray(0); glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();
    }


    void render(Camera camera) {
        if(rebuild) {
            build();
        }
        if(!vao) return;
        use(true);
        auto transform = camera.getProjectionMatrix * camera.getViewMatrix;
        setUniform(getUniformLocation("transform"), transform);
        glBindVertexArray(vao); glError();
        glDrawArrays(GL_TRIANGLES, 0, (sizeX-1)*(sizeY-1)*6); glError();
        glBindVertexArray(0); glError();
        use(false);
    }

}


bool displayHeightmap(T)(T t) {
    msg("Starting heightmap render...");

    auto heightmap = new Heightmap();

    static if(is(T : string)) {
        string type = "image";
        getopt(g_commandLine,
               std.getopt.config.passThrough,
               "HeightMapType", &type);

        float[] floatMap;
        switch(type) {
            case "image":
                heightmap.load(t);
                break;
            case "float":
                BinaryFile file = BinaryFile(t, "r");
                floatMap.length = cast(uint)file.size / float.sizeof;
                file.read(floatMap);
                file.close();
                heightmap.load(floatMap);
                break;
            default:
                msg("ERRROR UKNKNOWNS HEIGHTMAPS TYPE ", type);
                return false;
        }
    } else {
        heightmap.load(t);
    }

    heightmap.setColor(vec3f(0));


    Camera camera = new Camera;
    camera.setPosition(vec3d(0, 0, heightmap.maxHeight * 1.1));
    camera.setTarget(heightmap.getCenter().convert!double);

    GuiSystem guiSystem;
    guiSystem = new GuiSystem;

    auto freeFlight = new FreeFlightCamera(camera);
    guiSystem.setEventDump(freeFlight);

    bool exit = false;

    setWireframe(true);
    scope(exit) {
        guiSystem.destroy();
        heightmap.destroy();
        setWireframe(false);
    }


    // Main loop etc
    long then;
    long now, nextTime = utime();
    SDL_Event event;
    GuiEvent guiEvent;
    while (!exit) {
        while (SDL_PollEvent(&event)) {
            guiEvent.eventTimeStamp = now / 1_000_000.0;
            if(handleSDLEvent(event, guiEvent, guiSystem)) {
                return false;
            }
        } //Out of sdl-messages

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = cast(float)(diff) / 1_000_000.0f;            
        then = now;

        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();
        
        heightmap.render(camera);

        SDL_GL_SwapBuffers();

        SDL_WM_SetCaption( "CoolGameYo! heightmap render\0", "CoolGameYo! heightmap render\0");
    }
    return true;

}


void renderLoop(Camera camera, bool delegate() exitWhen, void delegate() render) {
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
    auto freeFlight = new FreeFlightCamera(camera);
    guiSystem.setEventDump(freeFlight);

    scope(exit) {
        guiSystem.destroy();
    }

    long then;
    long now, nextTime = utime();
    SDL_Event event;
    GuiEvent guiEvent;
    while (!exitWhen()) {
        while (SDL_PollEvent(&event)) {
            guiEvent.eventTimeStamp = now / 1_000_000.0;
            if(handleSDLEvent(event, guiEvent, guiSystem)) {
                return;
            }
        } //Out of sdl-messages

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        now = utime();
        long diff = now-then;
        float deltaT = cast(float)(diff) / 1_000_000.0f;            
        then = now;
        guiSystem.tick(deltaT); //Eventually add deltatime and such as well :)
        guiSystem.render();
        render();
        SDL_GL_SwapBuffers();
    }
}


