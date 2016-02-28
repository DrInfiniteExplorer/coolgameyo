
module cgy.opengl.textures;

import std.array : isArray;

import derelict.opengl3.gl;

import cgy.opengl.error;
import cgy.opengl.types : InternalTypeToSize, InternalTypeToFormatType, TypeToGLTypeEnum;

alias void delegate(int memDiff) TextureMemoryTrackerDelegare;

private __gshared TextureMemoryTrackerDelegare textureMemoryTracker = null;
TextureMemoryTrackerDelegare setTextureMemoryTracker(TextureMemoryTrackerDelegare dg)
{
    auto old = textureMemoryTracker;
    textureMemoryTracker = dg;
    return old;
}

uint GetInternalFormat(uint tex) {
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    int format;
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_INTERNAL_FORMAT, &format); glError();
    return format;
}

int[2] GetTextureSize(uint tex) {
    int width, height;
    glBindTexture(GL_TEXTURE_2D, tex); glError();
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width); glError();
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height); glError();
    //glBindTexture(GL_TEXTURE_2D, 0); glError();
    int[2] ret;
    ret[0] = width;
    ret[1] = height;
    return ret;
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
    if(textureMemoryTracker) {
        //core.atomic.atomicOp!"+="(g_videoMemoryTextures, size);
        textureMemoryTracker(size);
    }

    return tex;
}


//textureType: for example GL_RGB8, GL_R32F, etc

uint Create2DTexture(DataType = void, INT)(uint textureType, INT a_width, INT a_height, void* data = null) if( is(INT == int) || is(INT : long)) {
    static if( is(INT : long)) {
        int width = cast(int)a_width;
        int height = cast(int)a_height;
    } else {
        alias a_width width;
        alias a_height height;
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
    if(textureMemoryTracker) {
        //core.atomic.atomicOp!"+="(g_videoMemoryTextures, size);
        textureMemoryTracker(size);
    }

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
    if(textureMemoryTracker) {
        //core.atomic.atomicOp!"+="(g_videoMemoryTextures, size);
        textureMemoryTracker(size);
    }

    return tex;
}


void DeleteTexture(uint tex) {
    auto dim = GetTextureSize(tex);
    auto internalType = GetInternalFormat(tex);
    uint pixelSize = InternalTypeToSize(internalType);
    uint size = pixelSize * dim[0] * dim[1];
    if(textureMemoryTracker) {
        //core.atomic.atomicOp!"-="(g_videoMemoryTextures, size);
        textureMemoryTracker(-size);
    }

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