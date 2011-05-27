

module graphics.ogl;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;

public import derelict.opengl.gl;
public import derelict.opengl.glext;

import graphics.renderer;
import settings;

void initOpenGL(){
    string derp = to!string(glGetString(GL_VERSION));
    auto a = split(derp, ".");
    auto major = to!int(a[0]);
    auto minor = to!int(a[1]);

    //TODO: POTENTIAL BUG EEAPASASALPDsAPSLDPLASDsPLQWPRMtopmkg>jfekofsaplPSLFPsLSDF
    renderSettings.glVersion=major + 0.1*minor;
    writeln("OGL version ", renderSettings.glVersion);

    DerelictGL.loadExtensions();
    glError();
    glFrontFace(GL_CCW);
    glError();
    DerelictGL.loadClassicVersions(GLVersion.GL30);
    glError();
    DerelictGL.loadModernVersions(GLVersion.GL30);
    glError();

    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &renderSettings.maxTextureSize);
    glError();
    if(renderSettings.maxTextureSize > 512){
        debug writeln("MaxTextureSize(", renderSettings.maxTextureSize, ") to big; clamping to 512");
        renderSettings.maxTextureSize = 512;
    }
    glGetIntegerv(GL_MAX_ARRAY_TEXTURE_LAYERS, &renderSettings.maxTextureLayers);
    glError();
    float maxAni;
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &maxAni);
    glError();
    renderSettings.anisotropy = max(1.0f, min(renderSettings.anisotropy, maxAni));

    //Uh 1 or 2 if vsync enable......?
    version (Windows) {
        wglSwapIntervalEXT(renderSettings.disableVSync ? 0 : 1);
    } else {
        writeln("Cannot poke with vsync unless wgl blerp");
    }
    glError();

    glClearColor(1.0, 0.7, 0.4, 0.0);
    glError();

    glEnable(GL_DEPTH_TEST);
    glError();
    glEnable(GL_CULL_FACE);
    glError();
    glDepthFunc(GL_LEQUAL);
}


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

