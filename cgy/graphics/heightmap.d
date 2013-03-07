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
    in vec3 col;
    uniform mat4 transform;
    out vec3 normal;
    out vec3 color;
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
    in vec3 color;
    layout(location = 0) out vec4 frag_color;
    layout(location = 1) out vec4 light;
    //layout(location = 2) out vec4 depth;
    void main() {
        vec3 n = normalize(normal);
        vec3 sun = vec3(0, 0, 1);
        light = vec4(dot(n, sun));
        frag_color = vec4(1.0, 1.0, 1.0, 1.0) * vec4(color, 1.0);
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
        return [toX.normalize.crossProduct(toY.normalize).tupleof];
    }

    void setColor(vec3f color) {
        colorMap.length = 1;
        colorMap[0] = color;
        rebuild = true;
    }

    void build() {
        rebuild = false;
        triangles.length = 6 * (sizeX-1)*(sizeY-1);
        normals.length = (sizeX-1)*(sizeY-1);

        foreach(x, y ; Range2D(0, sizeX-1, 0, sizeY-1)) {
            auto idx = x + y * (sizeX-1);
            auto triIdx = idx * 6;
            normals[x + y * (sizeX-1)] = getNormal(x, y);
            triangles[triIdx+0] = [x, y, getVal(x, y)];
            triangles[triIdx+1] = [x, y+1, getVal(x, y+1)];
            triangles[triIdx+2] = [x+1, y, getVal(x+1, y)];
            triangles[triIdx+3] = [x, y+1, getVal(x, y+1)];
            triangles[triIdx+4] = [x+1, y+1, getVal(x+1, y+1)];
            triangles[triIdx+5] = [x+1, y, getVal(x+1, y)];
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
        auto colorSize = colorMap.length * colorMap[0].sizeof;

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
            glBufferData(GL_ARRAY_BUFFER, colorSize, colorMap.ptr, GL_STATIC_DRAW); glError();
            glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, colorMap[0].sizeof, null); glError();
            glEnableVertexAttribArray(2); glError();
        } else if(colorMap.length == 1) {
            glVertexAttrib3f(2, colorMap[0].x, colorMap[0].y, colorMap[0].z);
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




