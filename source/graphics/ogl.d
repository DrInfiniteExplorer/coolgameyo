

module graphics.ogl;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.traits : isArray;

public import derelict.opengl3.gl;
//import derelict.opengl.wgl;

import globals : g_glVersion, g_videoMemoryBuffers, g_videoMemoryTextures;
import graphics.image;
import graphics.shader;
import settings;

import cgy.math.vector : vec3f;
import cgy.opengl.textures;
import cgy.util.rangefromto;


enum int GL_SHADER_STORAGE_BUFFER = 0x90D2;

void initOpenGL(){
	DerelictGL3.reload();
    // Version returns for example "4.3.0" so grabbing the first 3 chars should be enough to get the version information
	auto version_ = glGetString(GL_VERSION);
	auto vendor = glGetString(GL_VENDOR);
	auto renderer = glGetString(GL_RENDERER);
	msg("OpenGl version : ", version_.to!string);
	msg("OpenGl vendor  : ", vendor.to!string);
	msg("OpenGl renderer: ", renderer.to!string);

    g_glVersion = glGetString(GL_VERSION)[0..3].to!string.to!double;
    msg("OGL version ", g_glVersion);

//    DerelictGL.loadExtensions();
    glError();
    glFrontFace(GL_CCW);
    glError();
//    DerelictGL.loadClassicVersions(GLVersion.GL21); //BECAUSE THERE IS ONLY UP TO 2.1 IN THE CLASSIC VERSION! :s
    glError();

    if(g_glVersion >= 3.0) {
        try {
//            DerelictGL.loadModernVersions(GLVersion.GL30);
        } catch (Exception e) {
            msg("Failed to load some modern gl function");
        }
        glError();
    } else {
        msg("ALERT! Don't have opengl 3.0, stuff amy crash randomly, and probably will!");
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
    if(GL_INVALID_ENUM == glGetError()) {
        msg("ALERT! opengl doesnt seem to like array textures :C");
        renderSettings.maxTextureLayers = 0;
    } else {
        renderSettings.maxTextureLayers = temp;
        //glError();
    }

    float maxAni;
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &maxAni);
    glError();
    renderSettings.anisotropy = max(1.0f, min(renderSettings.anisotropy, maxAni));

    //Uh 1 or 2 if vsync enable......? <-- wut? =p
    enableVSync(renderSettings.enableVSync);
    glError();

    int MaxVertexAttribs;
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, &MaxVertexAttribs);
    writeln("Supports max " ~ to!string(MaxVertexAttribs) ~ " attribute slots");

    glClearColor(1.0, 0.7, 0.4, 1.0);
    glError();

    glEnable(GL_DEPTH_TEST);
    glError();
    glEnable(GL_CULL_FACE);
    glError();
    glDepthFunc(GL_LEQUAL);
    
    initQuad();

    if(g_glVersion > 4.3) {
        int preferred_format;
        glGetInternalformativ(GL_TEXTURE_2D, GL_RGBA8, GL_TEXTURE_IMAGE_FORMAT, 1, &preferred_format);
        if(preferred_format == GL_RGBA) {
            writeln("Preffered internal format: GL_RGBA");
        } else if(preferred_format == GL_BGRA) {
            writeln("Preffered internal format: GL_BGRA");
            writeln("Säg till luben att ditt grafikkort rapporterar att BGRA är föredraget format");
            BREAKPOINT; 
        } else {
            writeln("Säg till luben att ditt grafikkort är totalt efterblivet. ", g_glVersion, [4,0,0] < [4,2,0]);
            BREAKPOINT; 
        }

        immutable GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX          = 0x9047;
        immutable GPU_MEMORY_INFO_TOTAL_AVAILABLE_MEMORY_NVX    = 0x9048;
        immutable GPU_MEMORY_INFO_CURRENT_AVAILABLE_VIDMEM_NVX  = 0x9049;
        immutable GPU_MEMORY_INFO_EVICTION_COUNT_NVX            = 0x904A;
        immutable GPU_MEMORY_INFO_EVICTED_MEMORY_NVX            = 0x904B;

        void asd(string what)() {
            int i;
            glGetIntegerv(mixin(what), &i);
            msg(what, ": ", i);
        }
        asd!"GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX";
        asd!"GPU_MEMORY_INFO_TOTAL_AVAILABLE_MEMORY_NVX";
        asd!"GPU_MEMORY_INFO_CURRENT_AVAILABLE_VIDMEM_NVX";
        asd!"GPU_MEMORY_INFO_EVICTION_COUNT_NVX";
        asd!"GPU_MEMORY_INFO_EVICTED_MEMORY_NVX";
    }

    renderSettings.canUseFBO = initFBO();

    //Refactor raycasting!!
    //initOCL();
}

void deinitOpenGL() {
    deinitFBO();
}




__gshared uint g_FBO = 0;
__gshared uint g_FBODepthBuffer = 0;
__gshared uint g_albedoTexture = 0;
__gshared uint g_lightTexture = 0;
__gshared uint g_rayCastOutput = 0;

bool initFBO() {

    glGenFramebuffers(1, &g_FBO); glError();
    glBindFramebuffer(GL_FRAMEBUFFER, g_FBO); glError();
    uint[3] buffers = [ GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2 ];
    glDrawBuffers(3, buffers.ptr); glError();


    uint depth;
    glGenRenderbuffers(1, &depth); glError();
    glBindRenderbuffer(GL_RENDERBUFFER, depth); glError();
    glRenderbufferStorage(GL_RENDERBUFFER, 
            GL_DEPTH_COMPONENT32,
            renderSettings.windowWidth, renderSettings.windowHeight);
    glError();
    glBindRenderbuffer(GL_RENDERBUFFER, 0); glError();
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth); glError();

    g_albedoTexture = Create2DTexture(GL_RGBA8, renderSettings.windowWidth, renderSettings.windowHeight, null);

    glError();
    glBindTexture(GL_TEXTURE_2D, 0);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_albedoTexture, 0); glError();

    g_lightTexture = Create2DTexture(GL_RGBA8, renderSettings.windowWidth, renderSettings.windowHeight);
    glBindTexture(GL_TEXTURE_2D, 0);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, g_lightTexture, 0); glError();

    immutable UseRenderBuffer = true;
    static if(UseRenderBuffer) {
        glGenRenderbuffers(1, &g_FBODepthBuffer); glError();
        glBindRenderbuffer(GL_RENDERBUFFER, g_FBODepthBuffer); glError();
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA32F, renderSettings.windowWidth, renderSettings.windowHeight); glError();
        glBindRenderbuffer(GL_RENDERBUFFER, 0); glError();
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_RENDERBUFFER, g_FBODepthBuffer); glError();
    } else {
        g_FBODepthBuffer = Create2DTexture(GL_RGBA32F, renderSettings.windowWidth, renderSettings.windowHeight);
        glBindTexture(GL_TEXTURE_2D, 0);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, g_FBODepthBuffer, 0); glError();
    }


    auto error = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glError();
    if(error != GL_FRAMEBUFFER_COMPLETE) {
        writeln("Derp noncomplete framebuffer!");
        auto table = [
            GL_FRAMEBUFFER_UNDEFINED:"GL_FRAMEBUFFER_UNDEFINED",
            GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:"GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT",
            GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:"GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT",
            GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER:"GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER",
            GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER:"GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER",
            GL_FRAMEBUFFER_UNSUPPORTED:"GL_FRAMEBUFFER_UNSUPPORTED",
            GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE:"GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE",
            GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS:"GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS",

        ];
        if(error in table) {
            msg("Error: ", table[error]);
        } else {
            msg("OMG! error not found :C ! (error=", error, ")");
        }
        msg("ALERT! Could not create frame buffer object :C !");
        renderSettings.raycastPixelSkip = 0;
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        //TODO: Make code that fucks everything up, so that we dont have lingering fbo's and textoars lying around :)
        return false;
    }

    int resultWidth = renderSettings.windowWidth / renderSettings.raycastPixelSkip;
    int resultHeight = renderSettings.windowHeight / renderSettings.raycastPixelSkip;
    g_rayCastOutput = Create2DTexture(GL_RGBA8, resultWidth, resultHeight);
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR); glError();
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glError();


    glBindTexture(GL_TEXTURE_2D, 0); glError();

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    return true;
}


void deinitFBO() {
    if(g_FBO == 0) return;
    //Dont care if shit is fucked up! :D

    glBindFramebuffer(GL_FRAMEBUFFER, g_FBO);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
    glDeleteRenderbuffers(1, &g_FBODepthBuffer); glError(); //Later implement static if around this.

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &g_FBO);
}


__gshared uint g_quadVBO;

//Build the best, quaaa~d in the world, or i'll eat your soul!
void initQuad(){
    vec3f[4] quad = [
        vec3f(-1, 1, 0),
        vec3f(-1,-1, 0),
        vec3f( 1,-1, 0),
        vec3f( 1, 1, 0),
    ];
    g_quadVBO = CreateBuffer(BufferType.Array, quad.sizeof, quad.ptr, GL_STATIC_DRAW);
}

void renderQuad() {
    glBindBuffer(GL_ARRAY_BUFFER, g_quadVBO); glError();
    glEnableVertexAttribArray(0); glError();
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, null); glError();
    
    glDisable(GL_DEPTH_TEST);

    glDrawArrays(GL_QUADS, 0, 4); glError();

    glEnable(GL_DEPTH_TEST);        
    glDisableVertexAttribArray(0); glError();
}

enum BufferType {
    Array,
    ElementArray,
    ShaderStorage
}

uint oglBufferType(BufferType type) {
    if(type == BufferType.Array) return GL_ARRAY_BUFFER;
    else if(type == BufferType.ElementArray) return GL_ELEMENT_ARRAY_BUFFER;
    else if(type == BufferType.ShaderStorage) return GL_SHADER_STORAGE_BUFFER;
    BREAKPOINT;
    assert(0);
}

uint CreateBuffer(BufferType bufferType, size_t size, void* data, uint typeHint) {
    uint ret;
    glGenBuffers(1, &ret); glError();

    uint glBufferType = bufferType.oglBufferType;
    glBindBuffer(glBufferType, ret); glError();
    glBufferData(glBufferType, size, data, typeHint); glError();

    core.atomic.atomicOp!"+="(g_videoMemoryBuffers, size);
    return ret;
}

void ReleaseBuffer(ref uint buffer) {
    if(buffer == 0) return;
    size_t size = BufferSize(buffer);
    core.atomic.atomicOp!"-="(g_videoMemoryBuffers, size);
    glDeleteBuffers(1, &buffer); glError();
    buffer = 0;
}

int BufferSize(uint buffer) {
    if(buffer == 0) return 0;
    int bufferSize;
    glBindBuffer(GL_ARRAY_BUFFER, buffer); glError();
    glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, &bufferSize); glError();
    return bufferSize;    
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
        msg("wglSwapIntervalEXT(enableVSync ? 1 : 0);");
    } else {
        msg("Cannot poke with vsync unless wgl blerp");
    }
}

Image screenCap(bool ignoreAlpha = true) {
    Image img = Image(null, renderSettings.windowWidth, renderSettings.windowHeight);
    glReadPixels(0, 0, renderSettings.windowWidth, renderSettings.windowHeight,
                 GL_RGBA, GL_UNSIGNED_BYTE, img.imgData.ptr);
    img.flipHorizontal();
    img.clearAlpha();
    return img;
}
