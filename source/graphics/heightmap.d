module graphics.heightmap;

import std.algorithm : max, map, reduce, clamp;
import std.getopt;

import derelict.sdl2.sdl;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import gui.all;
import gui.util;
import main : g_commandLine, EventAndDrawLoop;
import cgy.math.math;
import cgy.math.vector;
import cgy.util.filesystem;
import cgy.util.rangefromto : Range2D;
import cgy.debug_.debug_ : BREAK_IF;
import cgy.util.util : msg, utime;

immutable vertShaderSource = q{
    #version 430
    layout(location = 0) in ivec2 pos;
    layout(location = 2) in vec3 col;

    uniform mat4 transform;
    //layout(binding=0, r32f) readonly uniform image2D height;
    //layout(binding=1, r32f) readonly uniform image2D h2;
    //layout(binding=2, r16f) readonly uniform image2D h3;
    //layout(binding=3, r16f) readonly uniform image2D h4;
    layout(binding = 0) uniform sampler2D height;
    layout(binding = 1) uniform sampler2D h2;
    layout(binding = 2) uniform sampler2D h3;
    layout(binding = 3) uniform sampler2D h4;
    uniform vec2 cellSize;
    uniform int count;

    out vec3 normal;
    out vec3 color;
    out vec3 transformedPos;
    flat out ivec2 posss;

    float get(ivec2 pos) {
        float h = texelFetch(height, pos, 0).x;
        if(count > 1) {
            h += texelFetch(h2, pos, 0).x;
            if(count > 2) {
                //h += texelFetch(h3, pos, 0).x;
                if(count > 3) {
                    h += texelFetch(h4, pos, 0).x;
                }
            }
        }
        return h;
    }

    void main() {
        float h = get(pos);
        vec3 vert = vec3(pos * cellSize, h);
        gl_Position = transform * vec4(vert, 1.0);
        transformedPos = (transform * vec4(vert, 1.0)).xyz;
        posss = pos;

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
        vec3 clr = col;
        if(count > 2) {
            float water = clamp(texelFetch(h3, pos, 0).x, 0.0, 1.0);
            //clr = mix(col, vec3(0.1, 0.1, 0.9), water);
            clr.b += water;
            clr.b += texelFetch(h4, pos, 0).x;
            if(count > 3) {
                //clr.r += imageLoad(h4, pos).x;
            }
        }
        color = clr;
    }
};
immutable fragShaderSource = q{
    #version 430

    in vec3 normal;
    in vec3 color;
    in vec3 transformedPos;
    flat in ivec2 posss;
    layout(location = 0) out vec4 frag_color;
    layout(location = 1) out vec4 light;
    //layout(binding=2, r16f) readonly uniform image2D h3;
    //layout(location = 2) out vec4 depth;
    layout(binding = 0) uniform sampler2D height;
    layout(binding = 1) uniform sampler2D h2;
    layout(binding = 2) uniform sampler2D h3;
    layout(binding = 3) uniform sampler2D h4;
    uniform int renderLines;


    void main() {
        vec3 n = normalize(normal);
        vec3 sun = normalize(vec3(0.1, 0.1, 1));
        light = vec4(1.0, 1.0, 1.0, 1.0);
        float dottt = dot(n, sun);
        float water = texelFetch(h3, posss, 0).x;
        if(water > 0.3) {
            dottt = pow(dottt, 15);
        }

        if(renderLines == 1) {
            frag_color = vec4(vec3(0.0), 1.0);
            if(length(transformedPos.xy) > 500) {
                discard;
            }
        } else {
            frag_color = vec4(dottt * color, 1.0);
        }
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
    uint[] _loadTextureFormats;
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
            ReleaseBuffer(posVbo);
        }
        if(heightImg && heightImg != _loadTextures[0]) {
            glBindTexture(GL_TEXTURE_2D, 0);
            DeleteTextures(heightImg);
        }
        if(colorVbo) {
            ReleaseBuffer(colorVbo);
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
    void loadTexture(uint[] texes, int w, int h) {
        _loadTextures = texes.dup;
        _loadTextureFormats.length = texes.length;
        heightImg = texes[0];
        sizeX = w;
        sizeY = h;
        rebuild = true;
        foreach(size_t idx, tex ; texes) {
            _loadTextureFormats[idx] = GetInternalFormat(tex);
        }

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
        float[3][] colors;
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
                DeleteTextures(heightImg);
                heightImg = 0;
            }
            if(!heightImg) {
                heightImg = Create2DTexture!float(GL_R32F, sizeX, sizeY, map.ptr);
            } else {
                glBindTexture(GL_TEXTURE_2D, heightImg); glError();
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, sizeX, sizeY, GL_RED, GL_FLOAT, map.ptr); glError();
            }
        }
        immutable size = len * vec2i.sizeof;
        if(posVbo && BufferSize(posVbo) != size) {
            ReleaseBuffer(posVbo);
        }
        if(!posVbo) {
            vec2i[] positions;
            positions.length = len;
            foreach(x, y ; Range2D(0, sizeX-1, 0, sizeY-1)) {
                int idx = 4*(y * (sizeX-1) + x);
                positions[idx + 0].set(x  ,   y);
                positions[idx + 1].set(x+1,   y);
                positions[idx + 2].set(x+1, 1+y);
                positions[idx + 3].set(x  , 1+y);
            }
            posVbo = CreateBuffer(BufferType.Array, size, positions.ptr, GL_STATIC_DRAW);
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
            glVertexAttrib3f(2, colorMap[0].x, colorMap[0].y, colorMap[0].z);
            glDisableVertexAttribArray(2); glError();
        } else {
            glVertexAttrib3f(2, 1, 1, 1);
            glDisableVertexAttribArray(2); glError();
        }

        glBindVertexArray(0); glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();

        use(true);
        uniform.cellSize = vec2f(widthPerCell, depthPerCell);
        uniform.count = cast(int)max(1, _loadTextures.length);
        use(false);
    }


    void render(Camera camera, bool renderLines = false) {
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
        //glBindImageTexture(0, heightImg, 0, GL_FALSE, 0, GL_READ_ONLY, _loadTextureFormats[0]); glError();
        BindTexture(heightImg, 0);
        foreach(idx ; 1 .. _loadTextures.length) {
            //glBindImageTexture(cast(int)idx, _loadTextures[idx], 0, GL_FALSE, 0, GL_READ_ONLY, _loadTextureFormats[idx]); glError();
            BindTexture(_loadTextures[idx], cast(uint)idx);
        }

        if(colorMap.length == 1) {
            glVertexAttrib4f(2, colorMap[0].x, colorMap[0].y, colorMap[0].z, alpha);
            glDisableVertexAttribArray(2); glError();
        } else {
            glVertexAttrib3f(2, 1, 1, 1);   
            glDisableVertexAttribArray(2); glError();
        }

        glDrawArrays(GL_QUADS, 0, (sizeX-1)*(sizeY-1)*4); glError();

        if(renderLines) {
            uniform.renderLines = 1;

            auto old = setWireframe(true);
            glDrawArrays(GL_QUADS, 0, (sizeX-1)*(sizeY-1)*4); glError();
            setWireframe(old);
            uniform.renderLines = 0;
        }

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
                file.reader.read(floatMap);
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


    EventAndDrawLoop!true(guiSystem, (float deltaT){ heightmap.render(camera);});
    return true;

}


void renderLoop(Camera camera, bool delegate() exitWhen, void delegate() render) {
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
    auto freeFlight = new FreeFlightCamera(camera);
    guiSystem.setEventDump(freeFlight);

    scope(exit) {
        guiSystem.destroy();
        freeFlight.destroy();
    }

    EventAndDrawLoop!true(guiSystem, (float deltaT){ render(); }, exitWhen);
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


