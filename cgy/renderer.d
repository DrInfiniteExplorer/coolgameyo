import std.file;
import std.stdio;
import std.conv;
import std.string;

import derelict.opengl.gl;
import derelict.opengl.glext;
import engine.irrlicht;

import util;
import world;
import camera;
import vbomaker;

class ShaderProgram{
    
    uint program=0;
    uint vert=0;
    uint frag=0;
    
    this(){
        DerelictGL.loadClassicVersions(GLVersion.GL21);
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
    
    uint getUniformLocation(string name){
        return glGetUniformLocation(program, name.ptr);
    }
    
    //Count != 1 for arrays
    void setUniform(uint location, vec3i vec){
        glUniform3iv(location, 1, &vec.X);
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
	IVideoDriver driver;
    VBOMaker vboMaker;
		
	uint texture2D;
	uint textureAtlas;
    ShaderProgram shader;
    uint uniformOffsetLoc;
    uint uniformViewProjection;
    
	float oglVersion;
		
	this(World w, IVideoDriver d)
	{
		world = w;
		driver = d;
		vboMaker = new VBOMaker(w);
		shader = new ShaderProgram("shaders/renderGR.vert", "shaders/renderGR.frag");
        shader.bindAttribLocation(0, "position");
        shader.bindAttribLocation(1, "type");
        shader.link();
        uniformOffsetLoc = shader.getUniformLocation("offset");
        uniformViewProjection = shader.getUniformLocation("VP");
		
	}
		
	void render(Camera camera)
	{        
		//Render world
		renderWorld(camera);
		//Render dudes
		//Render foilage and other cosmetics
		//Render HUD/GUI
		//Render some stuff deliberately offscreen, just to be awesome.
		
	}
    
    void renderGraphicsRegion(const GraphicsRegion region){
        shader.setUniform(uniformOffsetLoc, region.grNum.min().value);

        shader.bindAttribLocation(0, "position");

        glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
        //auto posLoc = glGetAttribLocation(..., "position");
        glVertexAttribPointer(/*Position stream*/ 0, 3, GL_INT, GL_FALSE, Vertex.sizeof, null /* offset in vbo */);
        glEnableVertexAttribArray(/*Position stream*/ 0);

        glVertexAttribPointer(1, 1, GL_INT, GL_FALSE,
                              Vertex.sizeof,
                              cast(void*)asd /* offset in vbo */);
        glEnableVertexAttribArray(1);
        
        glDrawArrays(GL_QUADS, 0, region.quadCount*4);
    }
	
	void renderWorld(Camera camera)
	{
        shader.use();
        auto transform = camera.getProjectionMatrix() * camera.getViewMatrix();
        shader.setUniform(uniformViewProjection, transform);
//		auto vboList = vboMaker.getVBOs();
		auto regions = vboMaker.getRegions();
        foreach(region ; regions){
            if(camera.inFrustum(region.grNum.getAABB())){
                renderGraphicsRegion(region);
            }
        }
        //Get list of vbo's
        //Do culling
        //Render vbo's.
        shader.use(false);        
	}
}

