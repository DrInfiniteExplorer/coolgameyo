
module graphics.shader;

import std.conv;
import std.file;
import std.stdio;

import derelict.opengl.gl;
import derelict.opengl.glext;

import stolen.all;
import util;

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
        if(vert){ glDeleteShader(vert); }
        if(frag){ glDeleteShader(frag); }
        if(program){ glDeleteProgram(program); }
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

