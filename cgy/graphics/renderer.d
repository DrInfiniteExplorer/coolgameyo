
module graphics.renderer;

import std.array;
import std.conv;
import std.stdio;
import std.string;

import derelict.opengl.gl;
import derelict.opengl.glext;
import win32.windows;

import graphics.shader;
import graphics.texture;
import stolen.all;
import util;
import unit;
import world;
import camera;
import vbomaker;

struct RenderSettings{
    //Some opengl-implementation-dependant constants, gathered on renderer creation
    int maxTextureLayers;
    int maxTextureSize;
    double glVersion;

    //Just user settings. 
    bool disableVSync = true;
    bool useMipMap = true;
    float anisotropy = 0; //set to max of this(uservalue) and implementation limit sometime
    /* Derp derp derp */    
    
    int pixelsPerTile = 16;
}

RenderSettings renderSettings;

auto grTexCoordOffset = Vertex.texcoord.offsetof;
auto grTypeOffset = Vertex.type.offsetof;

class Renderer{
	World world;	
    VBOMaker vboMaker;
    
    TileTextureAtlas atlas;
		
	uint texture2D;
	uint textureAtlas;
    ShaderProgram worldShader;
    ShaderProgram dudeShader;
    
	float oglVersion;
		
	this(World w)
	{
        world = w;
		vboMaker = new VBOMaker(w);

        //Move rest into initGraphics() or somesuch?
        DerelictGL.loadExtensions();
        glFrontFace(GL_CCW);
        DerelictGL.loadClassicVersions(GLVersion.GL21);
        
        string derp = to!string(glGetString(GL_VERSION));
        auto a = split(derp, ".");
        auto major = to!int(a[0]);
        auto minor = to!int(a[1]);
        
        //TODO: POTENTIAL BUG EEAPASASALPDsAPSLDPLASDsPLQWPRMtopmkg>jfekofsaplPSLFPsLSDF
        renderSettings.glVersion=major + 0.1*minor;
        
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &renderSettings.maxTextureSize);
        glGetIntegerv(GL_MAX_ARRAY_TEXTURE_LAYERS, &renderSettings.maxTextureLayers);
        float maxAni;
        glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &maxAni);
        renderSettings.anisotropy = min(renderSettings.anisotropy, maxAni);
        
        //Uh 1 or 2 if vsync enable......?
        wglSwapIntervalEXT(renderSettings.disableVSync ? 0 : 1);

        //Would be kewl if with templates and compile-time one could specify uniform names / attrib slot names
        //that with help of shaders where made into member variables / compile-time-lookup(attrib slot names)
		worldShader = new ShaderProgram("shaders/renderGR.vert", "shaders/renderGR.frag");
        worldShader.bindAttribLocation(0, "position");
        worldShader.bindAttribLocation(1, "texcoord");
        worldShader.bindAttribLocation(2, "type");
        worldShader.link();
        worldShader.a = /*uniformOffsetLoc*/ worldShader.getUniformLocation("offset");
        worldShader.b = /*uniformViewProjection*/ worldShader.getUniformLocation("VP");
        
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
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);
    }
    
    void renderDude(Unit* unit){
        auto M = matrix4();
        M.setTranslation(util.convert!float(unit.pos.value));        
        //auto v = vec3f(0, 0, sin(GetTickCount()/1000.0));
        //M.setTranslation(v);
        dudeShader.setUniform(dudeShader.b, M);
        dudeShader.setUniform(dudeShader.c, vec3f(0, 0.7, 0));
        glBindBuffer(GL_ARRAY_BUFFER, dudeVBO);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null /* offset in vbo */);
        glEnableVertexAttribArray(0);

        glDrawArrays(GL_QUADS, 0, 4*6*2 /*2 cubes */);
    }
    
    void renderDudes(Camera camera) {
        auto vp = camera.getProjectionMatrix() * camera.getViewMatrix();
        dudeShader.use();
        dudeShader.setUniform(dudeShader.a, vp);
        auto dudes = world.getVisibleUnits(camera);
        foreach(dude ; dudes) {
            renderDude(dude);
        }
    }
        
	void render(Camera camera)
	{   
        
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        static if( true ){
            /* WIRE FRA ME!!! */
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
            glDisable(GL_CULL_FACE);
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
        auto pos = region.grNum.min().value;
        worldShader.setUniform(worldShader.a, pos);

        glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, null /* offset in vbo */);
        glEnableVertexAttribArray(0);

        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)grTexCoordOffset);
        glEnableVertexAttribArray(2);

        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)grTypeOffset);
        glEnableVertexAttribArray(2);
        
        glDrawArrays(GL_QUADS, 0, region.quadCount*4);
    }
	
	void renderWorld(Camera camera)
	{
        worldShader.use();
        auto transform = camera.getProjectionMatrix() * camera.getViewMatrix();
        worldShader.setUniform(worldShader.b, transform);
//		auto vboList = vboMaker.getVBOs();
		auto regions = vboMaker.getRegions();
        foreach(region ; regions){
            if(region.VBO && camera.inFrustum(region.grNum.getAABB())){
                renderGraphicsRegion(region);
            }
        }
        //Get list of vbo's
        //Do culling
        //Render vbo's.
        worldShader.use(false);        
	}
}

