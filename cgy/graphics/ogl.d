

module graphics.ogl;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;

public import derelict.opengl.gl;
public import derelict.opengl.glext;

import graphics.renderer;
import settings;

void initOpenGL(bool client){
    string derp = to!string(glGetString(GL_VERSION));
    auto a = split(derp, ".");
    auto major = to!int(a[0]);
    auto minor = to!int(a[1]);

    //TODO: POTENTIAL BUG EEAPASASALPDsAPSLDPLASDsPLQWPRMtopmkg>jfekofsaplPSLFPsLSDF
    renderSettings.glVersion=major + 0.1*minor;
    msg("OGL version ", renderSettings.glVersion);

    DerelictGL.loadExtensions();
    glError();
    glFrontFace(GL_CCW);
    glError();
    if (client) {
        DerelictGL.loadClassicVersions(GLVersion.GL30);
        glError();
        DerelictGL.loadModernVersions(GLVersion.GL30);
        glError();
    } else {
        //Load with lesser requirements.
    }

    int temp;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &temp);
    glError();
    renderSettings.maxTextureSize = temp;
    if(renderSettings.maxTextureSize > 512){
        debug msg("MaxTextureSize(", renderSettings.maxTextureSize, ") 'to big'; clamping to 512");
        renderSettings.maxTextureSize = 512;
    }
    glGetIntegerv(GL_MAX_ARRAY_TEXTURE_LAYERS, &temp);
    renderSettings.maxTextureLayers = temp;
    glError();
    float maxAni;
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &maxAni);
    glError();
    renderSettings.anisotropy = max(1.0f, min(renderSettings.anisotropy, maxAni));

    //Uh 1 or 2 if vsync enable......?
    setVSync(!renderSettings.disableVSync);
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

static bool oldValue = false;
bool setWireframe(bool wireframe) {
    bool ret = oldValue;
    oldValue = wireframe;
    if(wireframe){
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        glError();
        glDisable(GL_CULL_FACE);
        glError();
    }else{
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        glError();
        glEnable(GL_CULL_FACE);
        glError();
    }
    return ret;
}

void setVSync(bool enableVSync) {
    version (Windows) {
        wglSwapIntervalEXT(enableVSync ? 0 : 1);
    } else {
        msg("Cannot poke with vsync unless wgl blerp");
    }
}

