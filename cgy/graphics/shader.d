
module graphics.shader;

import std.conv;
import std.exception;
import std.file;
import std.stdio;
import std.string : splitLines;

import graphics.ogl;
import log : LogWarning, LogError;
import stolen.all;
import util.util;


string makeUints(T...)() {
    string ret;
    foreach(s ; T) {
        ret ~= "uint " ~ s ~ " = -1;";       
    }
    return ret;
}

enum ShaderType {
    Vertex,
    Fragment,
    Compute
}

enum UniformMissingPolicy {
    Halt,
    Warning,
    Ignore
}

class ShaderProgram(T...){
    mixin(makeUints!T());

    alias typeof(this) SP;

    uint program = 0;
    uint vert = 0;
    uint frag = 0;
    uint compute = 0;
    
    string vertexShader;
    string fragmentShader;
    string computeShader;

    struct UniformMagic {
        SP outer;
        void opDispatch(string name, T)(T t) {
            static if(__traits(hasMember, SP, name)) {
                static assert( is(typeof(__traits(getMember, this.outer, name)) : uint), " variable " ~ name ~ " is not of type uint, bailing out!");
                if(__traits(getMember, this.outer, name) == -1) {
                    __traits(getMember, this.outer, name) = this.outer.getUniformLocation(name);
                }
                this.outer.setUniform(__traits(getMember, this.outer, name), t);
            } else {
                uint location = this.outer.getUniformLocation!(UniformMissingPolicy.Ignore)(name);
                this.outer.setUniform(location, t);
            }
        }
    };
    UniformMagic uniform;

    this(){
        uniform = UniformMagic(this);
        program = glCreateProgram(); glError();
    }

    this(string constants, string vertex, string fragment){
        this();
        compileFile!(ShaderType.Vertex)(vertex, constants);
        compileFile!(ShaderType.Fragment)(fragment, constants);
        link();
    }

    this(string vertexPath, string fragmentPath){
        this();
        this.vertex = vertexPath;
        this.fragment = fragmentPath;
        link();
    }

    this(string[2] source){
        this();
        compileVertex(source[0]);
        compileFragment(source[1]);
        link();
    }

    void destroy(){
        if(vert){ glDeleteShader(vert); }
        if(frag){ glDeleteShader(frag); }
        if(compute) { glDeleteShader(compute); }
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
            msg("!!!\n", arr);
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
            msg("!!! %s", arr);
            return to!string(arr);
        }
        return "";
    }

    void compileFile(ShaderType shaderType)(string filename, string constants = ""){

        //Cute that the memory management for the loaded file is now manual, but the File struct allocates data via gc :P
        // ^ lololol :P
        // HOW TO MAKE less irritating?
        // maek totally own file derps? D:
        import util.memory : ScopeMemory;
        auto file = File(filename, "r");
        auto fileSize = cast(uint)file.size();
        auto mem = ScopeMemory!char(fileSize);
        file.rawRead(mem[]);
        compileSource!shaderType(cast(string)mem[]);
    }

    void compileSource(ShaderType shaderType)(string source) {
        static if(shaderType == ShaderType.Vertex) {
            alias vert shader;
            alias GL_VERTEX_SHADER TypeEnum;
        } else static if(shaderType == ShaderType.Fragment){
            alias frag shader;
            alias GL_FRAGMENT_SHADER TypeEnum;
        } else static if(shaderType == ShaderType.Compute) {
            alias compute shader;
            alias GL_COMPUTE_SHADER TypeEnum;
        }
        if(shader == 0) {
            shader = glCreateShader(TypeEnum); glError();
            glAttachShader(program, shader); glError();
        }
        immutable(char)*[1] ptr;
        int[1] length;
        ptr[0] = source.ptr;
        length[0] = cast(int)source.length;
        glShaderSource(shader, 1, ptr.ptr, length.ptr); glError();
        glCompileShader(shader); glError();
        int error;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &error); glError();
        if(error != GL_TRUE) {
            foreach(idx, line ; source.splitLines) {
                LogError(idx+1, ":", line);
            }
            printShaderError(shader);
            BREAKPOINT;
        }
    }
    alias compileSource!(ShaderType.Vertex) compileVertex;
    alias compileSource!(ShaderType.Fragment) compileFragment;
    alias compileSource!(ShaderType.Compute) compileCompute;

    void vertex(string filename) @property{
        vertexShader = filename;
        compileFile!(ShaderType.Vertex)(filename);
    }
    void fragment(string filename) @property{
        fragmentShader = filename;
        compileFile!(ShaderType.Fragment)(filename);
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
            msg("vert: ", vertexShader);
            msg("frag: ", fragmentShader);
            assert(0, "Linking failed!");
        }
    }
    
    void getAttributeNames() {
        int attribCount;
        int bufferSize;
        glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES, &attribCount);
        glError();
        glGetProgramiv(program, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &bufferSize);
        glError();
        char[] buffer;
        buffer.length = bufferSize+1;
        foreach(idx ; 0 .. attribCount) {
            int writtenSize;
            uint type;
            int size; //Number of "type"'s that the attribute takes            
            glGetActiveAttrib(program, idx, bufferSize, &writtenSize, &size, &type, buffer.ptr);
            glError();
            msg("Attribute(",idx, "):", buffer);
        }
        
    }

    //There is also bindAttribLocation (Which must be followed by a link())
    uint getAttribLocation(string name){
        const char *ptr = std.string.toStringz(name);
        uint ret = glGetAttribLocation(program, ptr);        
        glError();
        if( ret == -1) {
            getAttributeNames();
        }
        enforce(ret != -1, "Could not find attribute of name: " ~name);
        return ret;
    }

    int getUniformLocation(UniformMissingPolicy policy = UniformMissingPolicy.Warning)(string name){
        auto ret = glGetUniformLocation(program, name.ptr);
        glError();
        if(ret == -1) {
            static if(policy == UniformMissingPolicy.Halt) {
                BREAKPOINT;
                assert(0, "Could not get uniform " ~ name);
            } else static if(policy == UniformMissingPolicy.Warning) {
                LogWarning("Could not get uniform " ~ name);
            } else static if(policy == UniformMissingPolicy.Ignore) {
            } else {
                static assert(0, "Huh error in uniformmissingpolicies");
            }
        }
        return ret;
    }

    void setUniform(UniformMissingPolicy policy = UniformMissingPolicy.Warning, T...)(string name, T t) {
        int location = getUniformLocation!policy(name);
        setUniform(location, t);
    }

    void setUniform()(uint location, int i){
        glUniform1i(location, i);
        glError();
    }
    void setUniform()(uint location, float f){
        glUniform1f(location, f);
        glError();
    }
    //Count != 1 for arrays
    void setUniform()(uint location, vec3i vec){
        glUniform3iv(location, 1, &vec.x);
        glError();
    }
    void setUniform()(uint location, vec3f vec){
        glUniform3fv(location, 1, &vec.x);
        glError();
    }
    void setUniform()(uint location, vec2i vec){
        glUniform2iv(location, 1, &vec.x);
        glError();
    }
    void setUniform()(uint location, vec2f vec){
        glUniform2fv(location, 1, &vec.x);
        glError();
    }
    void setUniform()(uint location, vec2d vec){
        setUniform(location, vec.convert!float());
    }

    void setUniform()(uint location, matrix4 mat){
        glUniformMatrix4fv(location, 1, false, mat.pointer());
        glError();
    }

    void use(bool set=true){
        glUseProgram(set?program:0);
        glError();
    }
}

