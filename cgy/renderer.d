import std.file;
import std.stdio;
import std.conv;
import std.string;

import derelict.opengl.gl;
import derelict.opengl.glext;
import win32.windows;

import stolen.all;
import util;
import unit;
import world;
import camera;
import vbomaker;

class ShaderProgram{
    
    uint program=0;
    uint vert=0;
    uint frag=0;
    
    uint a,b,c,d,e,f,g,h,i,j; //Shorthands for variables wohooohohohohohoohwowowowo
    
    this(){
        vert = glCreateShader(GL_VERTEX_SHADER);
        frag = glCreateShader(GL_FRAGMENT_SHADER);
        program = glCreateProgram();
        glAttachShader(program, vert);
        glAttachShader(program, frag);                
    }
    
    this(string vertex, string fragment){
        this();
        this.vertex = vertex;
        this.fragment = fragment;
        link();
    }
    
    void destroy(){
        if(vert){
            glDeleteShader(vert);
        }
        if(frag){
            glDeleteShader(frag);
        }
        if(program){
            glDeleteProgram(program);
        }
    }
        
    string printShaderError(uint shader){
        int len, len2;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);
        if(len>0){
            char[] arr;
            arr.length = len+1;
            arr[len]=0;
            glGetShaderInfoLog(shader, len, &len2, arr.ptr);
            writeln("!!! %s", arr);
            return to!string(arr);
        } 
        return "";
    }
    
    void compileFile(uint shader, string filename){
        auto content = readText(filename);
        const char* ptr = std.string.toStringz(content);
        const char** ptrptr = &ptr;
        glShaderSource(shader, 1, ptrptr, null);
        glCompileShader(shader);
        int p;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &p);
        if(p != GL_TRUE){
            writeln(content);
            writeln(*ptrptr);
            auto error = printShaderError(shader);
            assert(0, "Shader compilation failed: " ~ filename ~"\n" ~error);
        }
    }
    
    void vertex(string filename) @property{
        compileFile(vert, filename);
    }
    void fragment(string filename) @property{
        compileFile(frag, filename);
    }
        
    void bindAttribLocation(uint location, string name){
        glBindAttribLocation(program, location, name.ptr);
    }
    
    void link(){
        glLinkProgram(program);
        int p;
        glGetProgramiv(program, GL_LINK_STATUS, &p);
        assert(p == GL_TRUE, "Linking failed!");
    }
    
    //There is also bindAttribLocation (Which must be followed by a link())
    uint getAttribLocation(string name){
        return glGetAttribLocation(program, name.ptr);
    }
    
    int getUniformLocation(string name){
        auto ret = glGetUniformLocation(program, name.ptr);
        assert(ret != -1, "Could not get uniform: " ~ name);
        return ret;
    }
    
    //Count != 1 for arrays
    void setUniform(uint location, vec3i vec){
        glUniform3iv(location, 1, &vec.X);
    }
    void setUniform(uint location, vec3f vec){
        glUniform3fv(location, 1, &vec.X);
    }

    void setUniform(uint location, matrix4 mat){
        glUniformMatrix4fv(location, 1, false, mat.pointer());
    }

    
    void use(bool set=true){
        glUseProgram(set?program:0);
    }
}


auto asd = Vertex.type.offsetof;

class Renderer{
	World world;	
    VBOMaker vboMaker;
		
	uint texture2D;
	uint textureAtlas;
    ShaderProgram worldShader;
    ShaderProgram dudeShader;
    
	float oglVersion;
		
	this(World w)
	{
		world = w;
		vboMaker = new VBOMaker(w);

        glFrontFace(GL_CCW);
        DerelictGL.loadClassicVersions(GLVersion.GL21);

		worldShader = new ShaderProgram("shaders/renderGR.vert", "shaders/renderGR.frag");
        worldShader.bindAttribLocation(0, "position");
        worldShader.bindAttribLocation(1, "type");
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
        //auto posLoc = glGetAttribLocation(..., "position");
        glVertexAttribPointer(/*Position stream*/ 0, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, null /* offset in vbo */);
        glEnableVertexAttribArray(/*Position stream*/ 0);

        glVertexAttribPointer(1, 1, GL_FLOAT, GL_FALSE,
                              Vertex.sizeof,
                              cast(void*)asd /* offset in vbo */);
        glEnableVertexAttribArray(1);
        
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

