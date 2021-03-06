module scene.texturearray;

import std.exception;

import graphics.image;
import graphics.ogl;

import settings;
import cgy.util.util;
import cgy.opengl.error : glError;
import cgy.opengl.textures;

final class TextureArray {

    this() {
    }
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
    }

    uint capacity;
    uint imgCount;
    uint[string] texToIdx;
    uint textureId;
    uint width;
    uint height;

    bool dirty = false;
    Image[] toUpload;

    uint loadImage(string texture, Image image) {

        if(texture in texToIdx) {
            return texToIdx[texture]; //Can trigger here when called from scenemanager, ? yes think so.
        }

        if(width == 0) {
            width = image.imgWidth;
            height = image.imgHeight;
        } else {
            enforce(height == image.imgHeight, "Error, trying to add image of wrong size to texture atlas");
            enforce(width == image.imgWidth, "Error, trying to add image of wrong size to texture atlas");
        }

        int ret;
        synchronized(this) {
            ret = imgCount;
            imgCount += 1;
            toUpload ~= image;            
            dirty = true;
            texToIdx[texture] = ret;
        }

        return ret;
    }

    uint loadImage(string texture) {
        if(texture in texToIdx) {
            return texToIdx[texture];
        }
        Image image = Image(texture);
        return loadImage(texture, image);
    }

    private void reupload() {
        synchronized(this) {
            uint oldCount = imgCount - cast(int)toUpload.length;
            if(imgCount > capacity) {
                capacity = imgCount + 5;

                //I guess a PBO would help here. Muääääh, i thought the copy functions could copy tex2tex :(
                ubyte[] data;
                data.length = 4*width*height*capacity;
                if(textureId) {
                    glBindTexture(GL_TEXTURE_2D_ARRAY, textureId); glError();
                    glGetTexImage(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA, GL_UNSIGNED_BYTE, data.ptr); glError();

                    DeleteTextures(textureId);
                }

                textureId = Create2DArrayTexture(GL_RGBA8, width, height, capacity, data.ptr);
                glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST); glError();
                glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR); glError();
                glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glError();
                glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); glError();
                glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_ANISOTROPY_EXT, renderSettings.anisotropy); glError();
                if(g_glVersion < 3.0){
                    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_GENERATE_MIPMAP, GL_TRUE);
                    glError();
                }
            }
            glBindTexture(GL_TEXTURE_2D_ARRAY, textureId);
            foreach(idx, img ; toUpload) {
                uint targetIdx = oldCount + cast(int)idx;
                auto offsetX = 0;
                auto offsetY = 0;
                auto dataPtr = img.imgData.ptr;
                glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, offsetX, offsetY, targetIdx, width, height, 1, GL_RGBA, GL_UNSIGNED_BYTE, dataPtr);
                glError();
            }
            glGenerateMipmap(GL_TEXTURE_2D_ARRAY); glError();
            toUpload = null;
            dirty = false;
        }
    }

    void bind(int textureUnit = 3){
        if(dirty) {
            reupload();
        }
        enforce(textureId != 0, "No texture set/uploaded/made! Sad sad sadness is overpowering!");
        glActiveTexture(GL_TEXTURE0 + textureUnit); glError();
        glBindTexture(GL_TEXTURE_2D_ARRAY, textureId); glError();
    }
    void unbind() {
        glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
    }
}

