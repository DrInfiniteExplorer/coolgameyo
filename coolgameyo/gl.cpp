#include "gl.h"
#include "Util.h"
#include <stdlib.h>

PFNGLGENBUFFERSARBPROC glGenBuffers;
PFNGLBINDBUFFERARBPROC glBindBuffer;
PFNGLBUFFERDATAARBPROC glBufferData;
PFNGLBUFFERSUBDATAARBPROC glBufferSubData;
PFNGLDELETEBUFFERSARBPROC glDeleteBuffer;
PFNGLGETBUFFERPARAMETERIVARBPROC glGetBufferParameteriv;

PFNGLCREATESHADERPROC glCreateShader;
PFNGLSHADERSOURCEPROC glShaderSource;
PFNGLCOMPILESHADERPROC glCompileShader;
PFNGLGETSHADERIVPROC glGetShaderiv;
PFNGLGETSHADERINFOLOGPROC glGetShaderInfoLog;

PFNGLCREATEPROGRAMPROC glCreateProgram;
PFNGLATTACHSHADERPROC glAttachShader;
PFNGLLINKPROGRAMPROC glLinkProgram;
PFNGLUSEPROGRAMPROC glUseProgram;
PFNGLGETPROGRAMIVPROC glGetProgramiv;

PFNGLGETUNIFORMLOCATIONPROC glGetUniformLocation;
PFNGLUNIFORM1IPROC glUniform1i;
PFNGLUNIFORM3IVPROC glUniform3iv;
PFNGLUNIFORM3FVPROC glUniform3fv;
PFNGLUNIFORMMATRIX4FVPROC glUniformMatrix4fv;

PFNGLGETATTRIBLOCATIONPROC glGetAttribLocation;
PFNGLVERTEXATTRIBPOINTERPROC glVertexAttribPointer;
PFNGLENABLEVERTEXATTRIBARRAYPROC glEnableVertexAttribArray;
PFNGLDISABLEVERTEXATTRIBARRAYPROC glDisableVertex;

PFNGLTEXIMAGE3DPROC glTexImage3D;
PFNGLTEXSUBIMAGE3DPROC glTexSubImage3D;
PFNGLGENERATEMIPMAPPROC glGenerateMipmap;

double glVersion;

void initGl(){

    glGenBuffers = (PFNGLGENBUFFERSARBPROC)wglGetProcAddress("glGenBuffersARB");
    glBindBuffer = (PFNGLBINDBUFFERARBPROC )wglGetProcAddress("glBindBufferARB");
    glBufferData = (PFNGLBUFFERDATAARBPROC)wglGetProcAddress("glBufferDataARB");
    glBufferSubData = (PFNGLBUFFERSUBDATAARBPROC)wglGetProcAddress("glBufferSubDataARB");
    glDeleteBuffer = (PFNGLDELETEBUFFERSARBPROC)wglGetProcAddress("glDeleteBuffersARB");
    glGetBufferParameteriv = (PFNGLGETBUFFERPARAMETERIVARBPROC)wglGetProcAddress("glGetBufferParameterivARB");

    glCreateShader = (PFNGLCREATESHADERPROC)wglGetProcAddress("glCreateShader");
    glShaderSource = (PFNGLSHADERSOURCEPROC)wglGetProcAddress("glShaderSource");
    glCompileShader= (PFNGLCOMPILESHADERPROC)wglGetProcAddress("glCompileShader");
    glGetShaderiv = (PFNGLGETSHADERIVPROC)wglGetProcAddress("glGetShaderiv");
    glGetShaderInfoLog = (PFNGLGETSHADERINFOLOGPROC)wglGetProcAddress("glGetShaderInfoLog");

    glCreateProgram = (PFNGLCREATEPROGRAMPROC)wglGetProcAddress("glCreateProgram");
    glAttachShader = (PFNGLATTACHSHADERPROC)wglGetProcAddress("glAttachShader");
    glLinkProgram = (PFNGLLINKPROGRAMPROC)wglGetProcAddress("glLinkProgram");
    glUseProgram = (PFNGLUSEPROGRAMPROC)wglGetProcAddress("glUseProgram");
    glGetProgramiv = (PFNGLGETPROGRAMIVPROC)wglGetProcAddress("glGetProgramiv");

    glGetUniformLocation = (PFNGLGETUNIFORMLOCATIONPROC)wglGetProcAddress("glGetUniformLocation");
    glUniform1i = (PFNGLUNIFORM1IPROC)wglGetProcAddress("glUniform1i");
    glUniform3iv = (PFNGLUNIFORM3IVPROC)wglGetProcAddress("glUniform3iv");
    glUniform3fv = (PFNGLUNIFORM3FVPROC)wglGetProcAddress("glUniform3fv");
    glUniformMatrix4fv = (PFNGLUNIFORMMATRIX4FVPROC)wglGetProcAddress("glUniformMatrix4fv");

    glGetAttribLocation = (PFNGLGETATTRIBLOCATIONPROC)wglGetProcAddress("glGetAttribLocation");
    glVertexAttribPointer = (PFNGLVERTEXATTRIBPOINTERPROC)wglGetProcAddress("glVertexAttribPointer");
    glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC)wglGetProcAddress("glEnableVertexAttribArray");
    glDisableVertex = (PFNGLDISABLEVERTEXATTRIBARRAYPROC)wglGetProcAddress("glDisableVertexAttribArray");

    glTexImage3D = (PFNGLTEXIMAGE3DPROC)wglGetProcAddress("glTexImage3D");
    glTexSubImage3D = (PFNGLTEXSUBIMAGE3DPROC)wglGetProcAddress("glTexSubImage3D");
    glGenerateMipmap = (PFNGLGENERATEMIPMAPPROC)wglGetProcAddress("glGenerateMipmap");

    enforce(glTexSubImage3D != NULL);

    enforce(glTexImage3D != NULL);


    glVersion= atof((const char*)glGetString(GL_VERSION)); 
}


void GLERROR(){
#ifdef _DEBUG
    u32 err = glGetError();
    switch(err){
    case GL_NO_ERROR:
        return;
    case GL_INVALID_ENUM:
        printf("GL ERROR: Invalid enum\n");break;
    case GL_INVALID_VALUE:
        printf("GL ERROR: Invalid value\n"); break;
    case GL_INVALID_OPERATION:
        printf("GL ERROR: Invalid operation\n"); break;
    case GL_OUT_OF_MEMORY:
        printf("GL ERROR: Out of memory\n"); break;
    default:
        printf("Got unrecognized gl error; %d\n");
    }
    BREAKPOINT;
#endif
}
