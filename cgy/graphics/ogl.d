

module graphics.ogl;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;

public import derelict.opengl.gl;
public import derelict.opengl.glext;
import derelict.opengl.wgl;
import opencl.all;

import graphics.renderer;
import graphics.font;
import graphics.image;
import graphics.raycastgpu;
import graphics.shader;
import settings;
import util.util;

void initOpenGL(bool client){
    string derp = to!string(glGetString(GL_VERSION));
    auto a = split(derp, ".");
    auto major = to!int(a[0]);
    auto minor = to!int(a[1]);

    //TODO: POTENTIAL BUG EEAPASASALPDsAPSLDPLASDsPLQWPRMtopmkg>jfekofsaplPSLFPsLSDF
    renderSettings.glVersion=major + 0.1*minor; //TODO: version might be 3.45 in which case this will not work.
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

    //Uh 1 or 2 if vsync enable......? <-- wut? =p
    enableVSync(renderSettings.enableVSync);
    glError();

    glClearColor(1.0, 0.7, 0.4, 0.0);
    glError();

    glEnable(GL_DEPTH_TEST);
    glError();
    glEnable(GL_CULL_FACE);
    glError();
    glDepthFunc(GL_LEQUAL);
    
    initFont();

    initQuad();
    initFBO();
    initOCL();

}

void deinitOpenGL() {
    deinitOCL();
    deinitFBO();
    deinitFont();
}

__gshared CLContext g_clContext;
__gshared CLCommandQueue g_clCommandQueue;

const bool UseRenderBuffer = false;

static if(UseRenderBuffer) {
__gshared CLBufferRenderGL g_clDepthBuffer; //Depth buffer after renderinrerer
} else {
__gshared CLImage2DGL g_clDepthBuffer; //Result from opencl raycasting yeah!
}
__gshared CLImage2DGL g_clResultTexture; //Result from opencl raycasting yeah!
__gshared CLMemories g_clRayCastMemories;

void initOCL() {
    cl_context_properties[] props;
    auto rawContextHandle = wglGetCurrentContext();
    auto curDC = wglGetCurrentDC();
    props = [CL_GL_CONTEXT_KHR, cast(cl_context_properties) rawContextHandle,
        CL_WGL_HDC_KHR, cast(cl_context_properties) curDC];

    g_clContext = CLContext(CLHost.getPlatforms()[0], CL_DEVICE_TYPE_GPU, props);

    g_clCommandQueue = CLCommandQueue(g_clContext, g_clContext.devices[0]);

    static if(UseRenderBuffer) {
        g_clDepthBuffer = CLBufferRenderGL(g_clContext, CL_MEM_READ_ONLY, g_FBODepthBuffer);
    } else {
        g_clDepthBuffer = CLImage2DGL(g_clContext, CL_MEM_READ_ONLY, GL_TEXTURE_2D, 0, g_FBODepthBuffer);
    }

    g_clResultTexture = CLImage2DGL(g_clContext, CL_MEM_WRITE_ONLY, GL_TEXTURE_2D, 0, g_ResultTexture);

    g_clRayCastMemories = CLMemories([g_clDepthBuffer, g_clResultTexture]);

    initInteractiveComputeYourFather();

}

void deinitOCL() {
    deinitInteractiveComputeYourFather();
}

__gshared uint g_FBO;
__gshared uint g_FBODepthBuffer;
__gshared uint g_FBOTexture;
__gshared uint g_ResultTexture;
void initFBO() {

    glGenFramebuffers(1, &g_FBO);
    glError();
    glBindFramebuffer(GL_FRAMEBUFFER, g_FBO);
    glError();
    uint[2] buffers = [ GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT ];
    glDrawBuffers(2, buffers.ptr);
    glError();


    uint depth;
    glGenRenderbuffers(1, &depth);
    glError();
    glBindRenderbuffer(GL_RENDERBUFFER, depth);
    glError();
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, renderSettings.windowWidth, renderSettings.windowHeight);
    glError();
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glError();
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth);
    glError();


    static if(UseRenderBuffer) {
        glGenRenderbuffers(1, &g_FBODepthBuffer);
        glError();
        glBindRenderbuffer(GL_RENDERBUFFER, g_FBODepthBuffer);
        glError();
        glRenderbufferStorage(GL_RENDERBUFFER, GL_R32F, renderSettings.windowWidth, renderSettings.windowHeight);
        glError();
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
        glError();
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_RENDERBUFFER, g_FBODepthBuffer);
        glError();
    } else {
        glGenTextures(1, &g_FBODepthBuffer);
        glError();
        glBindTexture(GL_TEXTURE_2D, g_FBODepthBuffer);
        glError();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glError();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glError();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glError();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glError();
        glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE); // automatic mipmap
        glError();
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, renderSettings.windowWidth, renderSettings.windowHeight, 0,
                     GL_RGBA, GL_FLOAT, null);
        glError();
        glBindTexture(GL_TEXTURE_2D, 0);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, g_FBODepthBuffer, 0);
        glError();
    }

    glGenTextures(1, &g_FBOTexture);
    glError();
    glBindTexture(GL_TEXTURE_2D, g_FBOTexture);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glError();
    glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE); // automatic mipmap
    glError();
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, renderSettings.windowWidth, renderSettings.windowHeight, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, null);
    glError();
    glBindTexture(GL_TEXTURE_2D, 0);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_FBOTexture, 0);
    glError();

    auto error = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glError();
    if(error != GL_FRAMEBUFFER_COMPLETE) {
        writeln("Derp noncomplete framebuffer!");
        BREAKPOINT;
    }

    glGenTextures(1, &g_ResultTexture);
    glError();
    glBindTexture(GL_TEXTURE_2D, g_ResultTexture);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glError();
    glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE); // automatic mipmap
    glError();
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, renderSettings.windowWidth, renderSettings.windowHeight, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, null);
    glError();
    glBindTexture(GL_TEXTURE_2D, 0);
    glError();

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

}


void deinitFBO() {

    glBindFramebuffer(GL_FRAMEBUFFER, g_FBO);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
    glDeleteRenderbuffers(1, &g_FBODepthBuffer);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &g_FBO);
}


alias ShaderProgram!("texture") QuadShaderProgram;
__gshared uint g_quadVBO;
__gshared QuadShaderProgram g_quadShader;
void initQuad(){
    vec3f[4] quad = [
        vec3f(-1, 1, 0),
        vec3f(-1,-1, 0),
        vec3f( 1,-1, 0),
        vec3f( 1, 1, 0),
    ];
    glGenBuffers(1, &g_quadVBO);
    glError();
    glBindBuffer(GL_ARRAY_BUFFER, g_quadVBO);
    glError();
    glBufferData(GL_ARRAY_BUFFER, quad.sizeof, quad.ptr, GL_STATIC_DRAW);
    glError();

    g_quadShader = new QuadShaderProgram("shaders/quadShader.vert", "shaders/quadShader.frag");

    g_quadShader.bindAttribLocation(0, "vertex");
    g_quadShader.link();
    g_quadShader.texture = g_quadShader.getUniformLocation("texture");
    g_quadShader.use();
    g_quadShader.setUniform(g_quadShader.texture, 3);
    g_quadShader.use(false);


}

void renderQuad(uint texture) {
    glBindBuffer(GL_ARRAY_BUFFER, g_quadVBO);
    glError();
    glEnableVertexAttribArray(0);
    glError();
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null /* offset in vbo */);
    glError();

    glActiveTexture(GL_TEXTURE3);
    glError();
    //g_FBOTexture
    glBindTexture(GL_TEXTURE_2D, texture);
    glError();

    g_quadShader.use();
    
    glDisable(GL_DEPTH_TEST);

    glDrawArrays(GL_QUADS, 0, 4);
    glError();

    glEnable(GL_DEPTH_TEST);        

    
    g_quadShader.use(false);

    glDisableVertexAttribArray(0);
    glError();

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

void enableVSync(bool enableVSync) {
    version (Windows) {
        wglSwapIntervalEXT(enableVSync ? 1 : 0);
    } else {
        msg("Cannot poke with vsync unless wgl blerp");
    }
}

Image screenCap() {
    Image img = Image(null, renderSettings.windowWidth, renderSettings.windowHeight);
    glReadPixels(0, 0, renderSettings.windowWidth, renderSettings.windowHeight,
                 GL_RGBA, GL_UNSIGNED_BYTE, img.imgData.ptr);
    return img;
}
