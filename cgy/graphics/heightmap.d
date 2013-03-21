module graphics.heightmap;

import std.algorithm : max, map, reduce;
import std.getopt;

import derelict.sdl.sdl;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import gui.all;
import gui.util;
import main : g_commandLine, EventAndDrawLoop;
import math.math;
import math.vector;
import util.filesystem;
import util.rangefromto : Range2D;
import util.util : BREAK_IF, msg, utime;

immutable vertShaderSource = q{
    #version 430
    layout(location = 0) in ivec2 pos;
    layout(location = 2) in vec4 col;

    uniform mat4 transform;
    layout(binding=0, r32f) readonly uniform image2D height;
    layout(binding=1, r32f) readonly uniform image2D h2;
    layout(binding=2, r32f) readonly uniform image2D h3;
    layout(binding=3, r32f) readonly uniform image2D h4;
    uniform vec2 cellSize;
    uniform int count;

    out vec3 normal;
    out vec4 color;

    float get(ivec2 pos) {
        float h = imageLoad(height, pos);
        if(count > 1) {
            h += imageLoad(h2, pos);
            if(count > 2) {
                h += imageLoad(h3, pos);
                if(count > 3) {
                    h += imageLoad(h4, pos);
                }
            }
        }
        return h;
    }

    void main() {
        float h = get(pos);
        vec3 vert = vec3(pos * cellSize, h);
        gl_Position = (transform * vec4(vert, 1.0));

        //*
        vec3 x_n = vec3(2.0 * cellSize.x, 0.0, get(pos + ivec2(-1, 0)) - get(pos + ivec2(1, 0)));
        vec3 y_n = vec3(0.0, 2.0 * cellSize.y, get(pos + ivec2(0, -1)) - get(pos + ivec2(0, 1)));
        normal = normalize(
                           cross(
                                 normalize(x_n),
                                 normalize(y_n)
                                 )
                           );
        /*/
        normal = vec3(0.1, 0.0, 1.0);
        //*/
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

    float width = -1;
    float depth;
    float height;

    int sizeX;
    int sizeY;

    uint posVbo;
    uint heightImg;
    uint[] _loadTextures;
    uint colorVbo;
    uint vao;

    bool rebuild;

    this() {
        super();
        compileSource!(ShaderType.Vertex)(vertShaderSource);
        compileSource!(ShaderType.Fragment)(fragShaderSource);
        link();
    }
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }
    override void destroy() {
        super.destroy();
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        if(posVbo) {
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glDeleteBuffers(1, &posVbo);
        }
        if(heightImg && heightImg != _loadTextures[0]) {
            glBindTexture(GL_TEXTURE_2D, 0);
            glDeleteTextures(1, &heightImg);
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
    float depthPerCell() const {
        return depth / sizeY;
    }

    void load(string path) {
        BREAKPOINT;
        // Load image, convert to heightmap.
        rebuild = true;
    }
    void load(float[] data) {
        auto len = data.length;
        auto sqrtLen = sqrt(cast(real)len);
        sizeY = sizeX = cast(int)sqrtLen;
        if(width == -1) {
            width = depth = sizeX;
        }
        BREAK_IF(sqrtLen != sizeX);
        BREAK_IF(sizeX ^^ 2 != len);
        map = data.dup;
        rebuild = true;
    }
    void loadTexture(uint[] tex, int w, int h) {
        _loadTextures = tex.dup;
        heightImg = tex[0];
        sizeX = w;
        sizeY = h;
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

    float getVal(int x, int y) {
        x = clamp(x, 0, sizeX-1);
        y = clamp(y, 0, sizeY-1);
        return map[x + y * sizeX];
    }

    vec3f getNormal(int x, int y) {
        vec3f ret = void;
        vec3f toX = vec3f(2*widthPerCell, 0, getVal(x-1, y) - getVal(x+1, y));
        vec3f toY = vec3f(0, 2*depthPerCell, getVal(x, y-1) - getVal(x, y+1));
        ret = toX.normalizeThis.crossProduct(toY.normalizeThis);
        //normal.z += 0.05;
        return ret.normalized;
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
        int len = 4 * (sizeX-1)*(sizeY-1);
        float[4][] colors;
        if(colorMap.length > 1) {
            colors.length = len;
        }

        if(!vao) {
            glGenVertexArrays(1, &vao); glError();
        }
        glBindVertexArray(vao);

        if(_loadTextures.length == 0) {
            if(heightImg && GetTextureSize(heightImg) != vec2i(sizeX, sizeY)) {
                glBindTexture(GL_TEXTURE_2D, 0);
                glDeleteTextures(1, &heightImg);
                heightImg = 0;
            }
            if(!heightImg) {
                heightImg = Create2DTexture!(GL_R32F,float)(sizeX, sizeY, map.ptr);
            } else {
                glBindTexture(GL_TEXTURE_2D, heightImg); glError();
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, sizeX, sizeY, GL_RED, GL_FLOAT, map); glError();
            }
        }
        immutable size = len * vec2i.sizeof;
        if(posVbo && BufferSize(posVbo) != size) {
            glDeleteBuffers(1, &posVbo); glError();
            posVbo = 0;
        }
        if(!posVbo) {
            glGenBuffers(1, &posVbo); glError();
            glBindBuffer(GL_ARRAY_BUFFER, posVbo); glError();
            vec2i[] positions;
            positions.length = len;
            foreach(x, y ; Range2D(0, sizeX-1, 0, sizeY-1)) {
                int idx = 4*(y * (sizeX-1) + x);
                positions[idx + 0].set(x  ,   y);
                positions[idx + 1].set(x+1,   y);
                positions[idx + 2].set(x+1, 1+y);
                positions[idx + 3].set(x  , 1+y);
            }
            glBufferData(GL_ARRAY_BUFFER, size, positions.ptr, GL_STATIC_DRAW); glError();
        }

        glVertexAttribIPointer(0u, 2, GL_INT, vec2i.sizeof, cast(void*)0); glError();
        glEnableVertexAttribArray(0); glError();

        if(colorMap.length > 1) {
            /*
            glBindBuffer(GL_ARRAY_BUFFER, colorVbo); glError();
            if(newColor) {
                glBufferData(GL_ARRAY_BUFFER, size, colors.ptr, GL_STATIC_DRAW); glError();
            } else {
                glBufferSubData(GL_ARRAY_BUFFER, 0, size, colors.ptr); glError();
            }
            glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, colors[0].sizeof, null); glError();
            glEnableVertexAttribArray(2); glError();
            */
            BREAKPOINT;
        } else if(colorMap.length == 1) {
            glVertexAttrib4f(2, colorMap[0].x, colorMap[0].y, colorMap[0].z, alpha);
            glDisableVertexAttribArray(2); glError();
        } else {
            glVertexAttrib3f(2, 1, 1, 1);
            glDisableVertexAttribArray(2); glError();
        }

        glBindVertexArray(0); glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();

        use(true);
        uniform.cellSize = vec2f(widthPerCell, depthPerCell);
        uniform.count = max(1, _loadTextures.length);
        use(false);
    }


    void render(Camera camera) {
        if(map.length == 0 && _loadTextures.length == 0) return;
        if(rebuild) {
            build();
        }
        //setWireframe(true);
        if(!vao) return;
        use(true);
        auto transform = camera.getProjectionMatrix * camera.getViewMatrix;
        uniform.transform = transform;
        glBindVertexArray(vao); glError();
        glBindImageTexture(0, heightImg, 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        foreach(idx ; 1 .. _loadTextures.length) {
            glBindImageTexture(idx, _loadTextures[idx], 0, GL_FALSE, 0, GL_READ_ONLY, GL_R32F); glError();
        }
        glDrawArrays(GL_QUADS, 0, (sizeX-1)*(sizeY-1)*4); glError();
        glBindVertexArray(0); glError();
        use(false);
        //setWireframe(false);
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


    EventAndDrawLoop(guiSystem, (float deltaT){ heightmap.render(camera);});
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

    EventAndDrawLoop(guiSystem, (float deltaT){ render(); }, exitWhen);
/*
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

    */
}


