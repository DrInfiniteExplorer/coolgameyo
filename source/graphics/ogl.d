

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
import util.util;
import util.rangefromto;

enum int GL_SHADER_STORAGE_BUFFER = 0x90D2;

void initOpenGL(){
    // Version returns for example "4.3.0" so grabbing the first 3 chars should be enough to get the version information
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

uint TypeToGLTypeEnum(Type)() {
    static if( is(Type == void)) return GL_UNSIGNED_BYTE; // Huerr hurr
    else static if( is(Type == ubyte)) return GL_UNSIGNED_BYTE;
    else static if( is(Type == byte)) return GL_BYTE;
    else static if( is(Type == ushort)) return GL_UNSIGNED_SHORT;
    else static if( is(Type == short)) return GL_SHORT;
    else static if( is(Type == uint)) return GL_UNSIGNED_INT;
    else static if( is(Type == int)) return GL_INT;
    else static if( is(Type == float)) return GL_FLOAT;
    else {
        static assert(0, "Cant produce opengl type enum from type " ~ Type);
    }
}

auto TypeToGLInternalType(Type)() {
    static if( is( Type == float) || is( Type == float[1])) {
        return GL_R32F;
    } else static if( is( Type == float[2])) {
        return GL_RG32F;
    } else static if( is( Type == float[3])) {
        return GL_RGB32F;
    } else static if( is( Type == float[4])) {
        return GL_RGBA32F;
    } else {
        pragma(msg, Type);
        static assert(0, "Type unrecognized!");
    }
    assert(0);
}

uint InternalTypeToFormatType(uint Type) {
    if(Type == GL_RGBA8) return GL_RGBA;
    else if(Type == GL_R16F) return GL_RED;
    else if(Type == GL_R32F) return GL_RED;
    else if(Type == GL_RG16F) return GL_RG;
    else if(Type == GL_RG32F) return GL_RG;
    else if(Type == GL_RGBA16F) return GL_RGBA;
    else if(Type == GL_RGBA32F) return GL_RGBA;
    else {
        BREAKPOINT;
        assert(0, "Unknown mapping: " ~ Type.stringof);
    }
}

uint InternalTypeToSize(uint Type) {
    if(Type == GL_RGBA8) return 4;
    else if(Type == GL_R16F) return 2;
    else if(Type == GL_R32F) return 4;
    else if(Type == GL_RG16F) return 4;
    else if(Type == GL_RG32F) return 8;
    else if(Type == GL_RGBA16F) return 8;
    else if(Type == GL_RGBA32F) return 16;
    else {
        BREAKPOINT;
        assert(0, "Unknown mapping: " ~ Type.stringof);
    }
}

uint GetInternalFormat(uint tex) {
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    int format;
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_INTERNAL_FORMAT, &format); glError();
    return format;
}

vec2i GetTextureSize(uint tex) {
    int width, height;
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width); glError();
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height); glError();
    //glBindTexture(GL_TEXTURE_2D, 0); glError();
    return vec2i(width, height);
}

uint Create2DArrayTexture(DataType = void)(uint textureType, int width, int height, int layers, void* data = null) {

    uint format = InternalTypeToFormatType(textureType);
    uint dataType = TypeToGLTypeEnum!DataType;

    uint tex = 0;
    glGenTextures(1, &tex); glError();
    glBindTexture(GL_TEXTURE_2D_ARRAY, tex); glError();
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST); glError();
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glError();
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glError();
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); glError();
    // automatic mipmap
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_GENERATE_MIPMAP, GL_FALSE); glError();
    glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, textureType, width, height, layers, 0,
                 format, dataType, data);
    glError();
    //glBindTexture(GL_TEXTURE_2D, 0);
    uint pixelSize = InternalTypeToSize(textureType);
    uint size = pixelSize * width * height * layers;
    core.atomic.atomicOp!"+="(g_videoMemoryTextures, size);

    return tex;
}


//textureType: for example GL_RGB8, GL_R32F, etc

uint Create2DTexture(DataType = void, INT)(uint textureType, INT _width, INT _height, void* data = null) if( is(INT == int) || is(INT : long)) {
    static if( is(INT : long)) {
        int width = cast(int)_width;
        int height = cast(int)_height;
    } else {
        alias _width width;
        alias _height height;
    }

    uint format = InternalTypeToFormatType(textureType);
    uint dataType = TypeToGLTypeEnum!DataType;

    uint tex = 0;
    glGenTextures(1, &tex); glError();
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glError();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); glError();
    // automatic mipmap
    glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE); glError();
    glTexImage2D(GL_TEXTURE_2D, 0, textureType, width, height, 0,
                 format, dataType, data);
    glError();
    //glBindTexture(GL_TEXTURE_2D, 0);
    uint pixelSize = InternalTypeToSize(textureType);
    uint size = pixelSize * width * height;
    core.atomic.atomicOp!"+="(g_videoMemoryTextures, size);

    return tex;
}


uint Create1DTexture(uint textureType, DataType = void)(int width, DataType* data = null) {

    uint format = InternalTypeToFormatType(textureType);
    uint dataType = TypeToGLTypeEnum!DataType;

    uint tex = 0;
    glGenTextures(1, &tex); glError();
    glBindTexture(GL_TEXTURE_1D, tex); glError();
    glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); glError();
    glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glError();
    glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glError();
    glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); glError();
    // automatic mipmap
    glTexParameteri(GL_TEXTURE_1D, GL_GENERATE_MIPMAP, GL_FALSE); glError();
    glTexImage1D(GL_TEXTURE_1D, 0, textureType, width, 0,
                 format, dataType, data);
    glError();
    //glBindTexture(GL_TEXTURE_2D, 0);

    uint pixelSize = InternalTypeToSize(textureType);
    uint size = pixelSize * width;
    core.atomic.atomicOp!"+="(g_videoMemoryTextures, size);

    return tex;
}


void DeleteTexture(uint tex) {
    auto dim = GetTextureSize(tex);
    auto internalType = GetInternalFormat(tex);
    uint pixelSize = InternalTypeToSize(internalType);
    uint size = pixelSize * dim.x * dim.y;
    core.atomic.atomicOp!"-="(g_videoMemoryTextures, size);

    glBindTexture(GL_TEXTURE_2D, 0);
    glDeleteTextures(1, &tex);
}
void DeleteTextures(T...)(T t) {
    foreach(item ; t) {
        static if( isArray!(typeof(item))) {
            foreach(tex ; item) {
                DeleteTexture(tex);
            }
        } else {
            DeleteTexture(item);
        }
    }
}


void BindTexture(uint tex, uint textureUnit) {
    glActiveTexture(GL_TEXTURE0 + textureUnit);
    glBindTexture(GL_TEXTURE_2D, tex);
}

void FillTexture(uint tex, float r, float g, float b, float a) {
    int width, height;
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width); glError();
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height); glError();
    FillTexture(tex, 0, 0, width, height, r, g, b, a);
}

void FillTexture(uint tex, int x, int y, int width, int height, float r, float g, float b, float a) {
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    int totalSize = width * height;
    uint count = totalSize;
    float[4] rgba = void;
    rgba[0] = r;
    rgba[1] = g;
    rgba[2] = b;
    rgba[3] = a;
    float[4][] tmp;
    tmp.length = width * height;
    tmp[] = rgba;
    glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, width, height, GL_RGBA, GL_FLOAT, tmp.ptr); glError();
    delete tmp;
    glBindTexture(GL_TEXTURE_2D, 0); glError();
}


string makeLookupTable(string[] enums) {
    string ret = "[";
    foreach(str ; enums) {
        ret ~= str ~ ":\"" ~ str ~ "\",\n";
    }
    return ret ~ "]";
}
__gshared string[uint] glErrorTable;
shared static this() {
    glErrorTable = mixin(makeLookupTable(
        [
            "GL_INVALID_ENUM",
            "GL_INVALID_FRAMEBUFFER_OPERATION",
            "GL_INVALID_VALUE",
            "GL_INVALID_OPERATION",
            "GL_OUT_OF_MEMORY",
        ]));
}
void glError(string file = __FILE__, int line = __LINE__){
    uint err = glGetError();
    if(GL_NO_ERROR == err) return;
    string str;
    if(err in glErrorTable) {
        str = glErrorTable[err];
    } else {
        str = "Unrecognized opengl error! " ~ to!string(err);
    }
    auto derp = file ~":" ~ to!string(line) ~ "\n" ~str;
    writeln(derp);
    BREAKPOINT;
    //assert(0, derp);
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
