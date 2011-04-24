
module graphics.shader;

import std.conv;
import std.file;
import std.stdio;

import graphics.ogl;
import graphics.renderer;
import stolen.all;
import util;

class ShaderProgram{

    uint program=0;
    uint vert=0;
    uint frag=0;

    uint a,b,c,d,e,f,g,h,i,j; //Shorthands for variables wohooohohohohohoohwowowowo

    this(){
        vert = glCreateShader(GL_VERTEX_SHADER);
        glGetError();
        frag = glCreateShader(GL_FRAGMENT_SHADER);
        glError();
        program = glCreateProgram();
        glError();
        glAttachShader(program, vert);
        glError();
        glAttachShader(program, frag);
        glError();
    }

    this(string constants, string vertex, string fragment){
        this();
        compileFile(vert, vertex, constants);
        compileFile(frag, fragment, constants);
        link();
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
        glError();
        if(len>0){
            char[] arr;
            arr.length = len+1;
            arr[len]=0;
            glGetShaderInfoLog(shader, len, &len2, arr.ptr);
            glError();
            writeln("!!! %s", arr);
            return to!string(arr);
        }
        return "";
    }

    string printProgramError(uint program){
        int len, len2;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &len);
        glError();
        if(len>0){
            char[] arr;
            arr.length = len+1;
            arr[len]=0;
            glGetProgramInfoLog(program, len, &len2, arr.ptr);
            glError();
            writeln("!!! %s", arr);
            return to!string(arr);
        }
        return "";
    }

    void compileFile(uint shader, string filename, string constants = ""){
        auto content = readText(filename);
        const char* ptr = std.string.toStringz(constants ~ content);
        const char** ptrptr = &ptr;
        glShaderSource(shader, 1, ptrptr, null);
        glError();
        glCompileShader(shader);
        glError();
        int p;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &p);
        glError();
        if(p != GL_TRUE){
            writeln(constants ~ content);
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
        glError();
    }

    void link(){
        glLinkProgram(program);
        glError();
        int p;
        glGetProgramiv(program, GL_LINK_STATUS, &p);
        glError();
        if(p != GL_TRUE) {
            printProgramError(program);
            assert(0, "Linking failed!");
        }
    }

    //There is also bindAttribLocation (Which must be followed by a link())
    uint getAttribLocation(string name){
        return glGetAttribLocation(program, name.ptr);
        glError();
    }

    int getUniformLocation(string name){
        auto ret = glGetUniformLocation(program, name.ptr);
        glError();
        assert(ret != -1, "Could not get uniform: " ~ name);
        return ret;
    }

    void setUniform(uint location, int i){
        glUniform1i(location, i);
        glError();
    }
    //Count != 1 for arrays
    void setUniform(uint location, vec3i vec){
        glUniform3iv(location, 1, &vec.X);
        glError();
    }
    void setUniform(uint location, vec3f vec){
        glUniform3fv(location, 1, &vec.X);
        glError();
    }
    void setUniform(uint location, vec2i vec){
        glUniform2iv(location, 1, &vec.X);
        glError();
    }
    void setUniform(uint location, vec2f vec){
        glUniform2fv(location, 1, &vec.X);
        glError();
    }

    void setUniform(uint location, matrix4 mat){
        glUniformMatrix4fv(location, 1, false, mat.pointer());
        glError();
    }


    void use(bool set=true){
        glUseProgram(set?program:0);
        glError();
    }
}

