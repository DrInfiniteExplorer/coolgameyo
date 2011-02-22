#pragma once

#include <Windows.h>
#include <gl/GL.h>
#include <gl/GLU.h>
#include "glext.h"

extern PFNGLGENBUFFERSARBPROC glGenBuffers;
extern PFNGLBINDBUFFERARBPROC glBindBuffer;
extern PFNGLBUFFERDATAARBPROC glBufferData;
extern PFNGLBUFFERSUBDATAARBPROC glBufferSubData;
extern PFNGLDELETEBUFFERSARBPROC glDeleteBuffer;
extern PFNGLGETBUFFERPARAMETERIVARBPROC glGetBufferParameteriv;

extern PFNGLCREATESHADERPROC glCreateShader;
extern PFNGLSHADERSOURCEPROC glShaderSource;
extern PFNGLCOMPILESHADERPROC glCompileShader;
extern PFNGLGETSHADERIVPROC glGetShaderiv;
extern PFNGLGETSHADERINFOLOGPROC glGetShaderInfoLog;

extern PFNGLCREATEPROGRAMPROC glCreateProgram;
extern PFNGLATTACHSHADERPROC glAttachShader;
extern PFNGLLINKPROGRAMPROC glLinkProgram;
extern PFNGLUSEPROGRAMPROC glUseProgram;
extern PFNGLGETPROGRAMIVPROC glGetProgramiv;

extern PFNGLGETUNIFORMLOCATIONPROC glGetUniformLocation;
extern PFNGLUNIFORM1IPROC glUniform1i;
extern PFNGLUNIFORM3IVPROC glUniform3iv;
extern PFNGLUNIFORM3FVPROC glUniform3fv;
extern PFNGLUNIFORMMATRIX4FVPROC glUniformMatrix4fv;

extern PFNGLGETATTRIBLOCATIONPROC glGetAttribLocation;
extern PFNGLVERTEXATTRIBPOINTERPROC glVertexAttribPointer;
extern PFNGLENABLEVERTEXATTRIBARRAYPROC glEnableVertexAttribArray;
extern PFNGLDISABLEVERTEXATTRIBARRAYPROC glDisableVertexAttribArray;

extern PFNGLTEXIMAGE3DPROC glTexImage3D;
extern PFNGLTEXSUBIMAGE3DPROC glTexSubImage3D;
extern PFNGLGENERATEMIPMAPPROC glGenerateMipmap;


extern double glVersion;


void initGl();


void GLERROR();


