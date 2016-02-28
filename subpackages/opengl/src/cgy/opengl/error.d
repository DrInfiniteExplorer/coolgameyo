
module cgy.opengl.error;

import std.stdio : writeln;
import std.traits : EnumMembers;
import std.conv : to;

import derelict.opengl3.gl;

enum OpenglErrors {
    GL_INVALID_ENUM                  = derelict.opengl3.gl.GL_INVALID_ENUM                  ,   
    GL_INVALID_FRAMEBUFFER_OPERATION = derelict.opengl3.gl.GL_INVALID_FRAMEBUFFER_OPERATION ,
    GL_INVALID_VALUE                 = derelict.opengl3.gl.GL_INVALID_VALUE                 ,
    GL_INVALID_OPERATION             = derelict.opengl3.gl.GL_INVALID_OPERATION             ,
    GL_OUT_OF_MEMORY                 = derelict.opengl3.gl.GL_OUT_OF_MEMORY                 ,
}

void glError(string file = __FILE__, int line = __LINE__){
    immutable uint err = glGetError();
    if(GL_NO_ERROR == err) return;
    foreach(immutable entry ; EnumMembers!OpenglErrors)
    {
        if(entry == err) {
            writeln(file,":",line,"\n",entry.to!string);
        }
    }
    writeln(file,":",line,"\nUnrecognized opengl error! " ~ err.to!string);
    asm { int 3 ;}
    //assert(0, derp);
}
