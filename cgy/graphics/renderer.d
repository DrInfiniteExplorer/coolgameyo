
module graphics.renderer;

import std.array;
import std.conv;
import std.stdio;
import std.string;
import std.format;

import derelict.opengl.gl;
import derelict.opengl.glext;

import graphics.camera;
import graphics.shader;
import graphics.texture;
import graphics.camera;
import graphics.vbomaker;

import stolen.all;

import util;
import unit;
import world;
import scheduler;

struct RenderSettings{
    //Some opengl-implementation-dependant constants, gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;
    double glVersion;

    //Just user settings.
    bool disableVSync = true;
    bool useMipMap = true;
    float anisotropy = 0; //set to max of this(uservalue) and implementation limit sometime
    bool renderWireframe;
    bool renderInvalidTiles = true;
    /* Derp derp derp */

    int pixelsPerTile = 16;
}

RenderSettings renderSettings;

auto grTexCoordOffset = Vertex.texcoord.offsetof;
auto grTypeOffset = Vertex.type.offsetof;

void glError(string file = __FILE__, int line = __LINE__){
    debug{
        uint err = glGetError();
        string str;
        switch(err){
        case GL_NO_ERROR:
            return;
        case GL_INVALID_ENUM:
            str = "GL ERROR: Invalid enum"; break;
        case GL_INVALID_VALUE:
            str = "GL ERROR: Invalid value"; break;
        case GL_INVALID_OPERATION:
            str = "GL ERROR: Invalid operation"; break;
        case GL_OUT_OF_MEMORY:
            str = "GL ERROR: Out of memory"; break;
        default:
            str = "Got unrecognized gl error; "~ to!string(err);
            break;
        }
        auto derp = file ~ to!string(line) ~ "\n" ~str;
        assert(0, derp);
    }
}

class Renderer{
    World world;
    Scheduler scheduler;
    VBOMaker vboMaker;
    Camera camera;

    TileTextureAtlas atlas;

    uint texture2D;
    uint textureAtlas;
    ShaderProgram worldShader;
    ShaderProgram dudeShader;

    string constantsString;

    float oglVersion;


    void buildConstantsString(){
        auto writer = appender!string();
        auto format =   "#version 150 core\n"
                        "const float pixelWidth = 1.0/%f;\n"
                        "const vec2 tileSize = vec2(%f, %f) * pixelWidth;\n"
                        "uvec3 tileIndexFromNumber(in uint num){\n"
                        "   uvec3 ret;\n"
                        "   float n = float(num);\n"
                        "   ret.x = uint(mod(n, %f));\n"
                        "   ret.y = uint(mod(n / %f, %f));\n"
                        "   ret.z = uint(n / %f);\n"
                        "   return ret;\n"
                        "}\n";
        auto a = to!float(renderSettings.pixelsPerTile);
        auto b = to!float(renderSettings.maxTextureSize / renderSettings.pixelsPerTile);
        formattedWrite(writer, format, to!float(renderSettings.maxTextureSize), a, a, b, b, b, b*b);
        constantsString = writer.data;
    }




    this(World w, Scheduler s, Camera c)
    {
        world = w;
        scheduler = s;
        camera = c;
        vboMaker = new VBOMaker(w, s, c);

        buildConstantsString();

        //Would be kewl if with templates and compile-time one could specify uniform names / attrib slot names
        //that with help of shaders where made into member variables / compile-time-lookup(attrib slot names)
        worldShader = new ShaderProgram(constantsString, "shaders/renderGR.vert", "shaders/renderGR.frag");
        worldShader.bindAttribLocation(0, "position");
        worldShader.bindAttribLocation(1, "texcoord");
        worldShader.bindAttribLocation(2, "type");
        worldShader.link();
        worldShader.a = /*uniformOffsetLoc*/ worldShader.getUniformLocation("offset");
        worldShader.b = /*uniformViewProjection*/ worldShader.getUniformLocation("VP");
        worldShader.c = worldShader.getUniformLocation("atlas");
        worldShader.use();
        worldShader.setUniform(worldShader.c, 0); //Texture atlas will always reside in texture unit 0 yeaaaah

        dudeShader = new ShaderProgram("shaders/renderDude.vert", "shaders/renderDude.frag");
        dudeShader.bindAttribLocation(0, "position");
        dudeShader.link();
        dudeShader.a = dudeShader.getUniformLocation("VP");
        dudeShader.b = dudeShader.getUniformLocation("M");
        dudeShader.c = dudeShader.getUniformLocation("color");

        createDudeModel();

  }


    vec3f[] makeCube(vec3f size=vec3f(1, 1, 1), vec3f offset=vec3f(0, 0, 0)){
        alias vec3f v;
        float a = 0.5;
        vec3f ret[] = [
            v(-a, -a, -a), v(a, -a, -a), v(a, -a, a), v(-a, -a, a), //front face (y=-a)
            v(a, -a, -a), v(a, a, -a), v(a, a, a), v(a, -a, a), //right face (x=a)
            v(a, a, -a), v(-a, a, -a), v(-a, a, a), v(a, a, a), //back face(y=a)
            v(-a, a, -a), v(-a, -a, -a), v(-a, -a, a), v(-a, a, a), //left face(x=-a)
            v(-a, -a, a), v(a, -a, a), v(a, a, a), v(-a, a, a), //top face (z = a)
            v(-a, a, -a), v(a, a, -a), v(a, -a, -a), v(-a, -a, -a) //bottom face (z=-a)
        ];
        foreach(i; 0..ret.length){
            auto vert = ret[i];
            vert *= size;
            vert += offset;
            ret[i] = vert;
        }
        return ret;
    }


    uint dudeVBO;
    void createDudeModel(){
        vec3f[] vertices;
        vertices ~= makeCube(vec3f(0.5, 0.5, 1)); //Body, -.25, -.25, -.5 -> .25, .25, .5
        vertices ~= makeCube(vec3f(1, 1, 1), vec3f(0, 0, 1)); //Head, -.5, -.5, .5 -> .5, .5, 1.0
        glGenBuffers(1, &dudeVBO);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glError();
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);
        glError();
    }

    void renderDude(Unit* unit){
        auto M = matrix4();
        M.setTranslation(util.convert!float(unit.pos.value));
        //auto v = vec3f(0, 0, sin(GetTickCount()/1000.0));
        //M.setTranslation(v);
        dudeShader.setUniform(dudeShader.b, M);
        dudeShader.setUniform(dudeShader.c, vec3f(0, 0.7, 0));
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null /* offset in vbo */);
        glError();

        glDrawArrays(GL_QUADS, 0, 4*6*2 /*2 cubes */);
        glError();
    }

    void renderDudes(Camera camera) {
        auto vp = camera.getProjectionMatrix() * camera.getViewMatrix();
        dudeShader.use();
        dudeShader.setUniform(dudeShader.a, vp);
        glEnableVertexAttribArray(0);
        glError();
        auto dudes = world.getVisibleUnits(camera);
        foreach(dude ; dudes) {
            renderDude(dude);
        }
        glDisableVertexAttribArray(0);
        glError();
    }

  void render()
  {

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glError();

        if(renderSettings.renderWireframe){
            /* WIRE FRA ME!!! */
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
            glError();
            glDisable(GL_CULL_FACE);
            glError();
        }else{
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            glError();
            glEnable(GL_CULL_FACE);
            glError();
        }
        //Render world
        renderWorld(camera);
        //Render dudes
        renderDudes(camera);
        //Render foilage and other cosmetics
        //Render HUD/GUI
        //Render some stuff deliberately offscreen, just to be awesome.
  }

    void renderGraphicsRegion(const GraphicsRegion region){
        //TODO: Do the pos-camerapos before converting to float, etc
        auto pos = region.grNum.min().value;
        worldShader.setUniform(worldShader.a, pos);

        glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
        glError();
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, null /* offset in vbo */);
        glError();

        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)grTexCoordOffset);
        glError();

        glVertexAttribIPointer(2, 1, GL_UNSIGNED_INT, Vertex.sizeof, cast(void*)grTypeOffset);
        glError();

        glDrawArrays(GL_QUADS, 0, region.quadCount*4);
        glError();
    }

  void renderWorld(Camera camera)
  {
        worldShader.use();
        glEnableVertexAttribArray(0);
        glError();
        glEnableVertexAttribArray(1);
        glError();
        glEnableVertexAttribArray(2);
        glError();
        atlas.use();
        auto transform = camera.getProjectionMatrix() * camera.getViewMatrix();
        worldShader.setUniform(worldShader.b, transform);
        auto regions = vboMaker.getRegions();
        foreach(region ; regions){
            if(region.VBO && camera.inFrustum(region.grNum.getAABB())){
                renderGraphicsRegion(region);
            }
        }
        //Get list of vbo's
        //Do culling
        //Render vbo's.
        glDisableVertexAttribArray(0);
        glError();
        glDisableVertexAttribArray(1);
        glError();
        glDisableVertexAttribArray(2);
        glError();
        worldShader.use(false);
  }
}

