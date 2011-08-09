
module graphics.texture;

import std.conv;
import std.exception;
import std.math;
import std.typecons;
import std.stdio;

import graphics.image;
import graphics.ogl;
import graphics.renderer;
import settings;
import statistics;
import util;




class TileTextureAtlas{
    uint texId;

    int tilesPerAxis;
    int tilesPerLayer;
    int maxTileCount;

    ubyte[] atlasData;
    ushort[Tuple!(string, vec2i, vec3i)] tileMap;

    vec3i tileIndexFromNumber(int num){
        auto layer = num / tilesPerLayer;
        auto y = (num / tilesPerAxis) % tilesPerAxis;
        auto x = num % tilesPerAxis;

        return vec3i(x, y, layer);
    }

    int tileNumberFromIndex(vec3i index){
        return index.X + tilesPerAxis*index.Y + tilesPerLayer*index.Z;
    }

    this() {
        tilesPerAxis = renderSettings.maxTextureSize / renderSettings.pixelsPerTile;
        tilesPerLayer = tilesPerAxis^^2;
        maxTileCount = tilesPerLayer * renderSettings.maxTextureLayers;
        debug{
            msg(tilesPerAxis, "x", tilesPerAxis,"=", tilesPerLayer, " tiles per layer");
            msg(renderSettings.maxTextureLayers, " layers at most");
            auto bytes = (renderSettings.maxTextureSize^^2)*4;
            msg(bytes, " bytes per layer");
            msg(bytes/1024, " kilobytes per layer");
            msg(bytes/(1024^^2), " megabytes per layer");
        }
    }


    bool destroyed;    
    ~this(){
        BREAK_IF(!destroyed);
    }

    void destroy(){
        glDeleteTextures(1, &texId);
        texId = 0;
        destroyed = true;
    }

    void genTex(){
        assert(texId == 0, "texId != 0");
        glGenTextures(1, &texId);
        glError();
        enforce(texId != 0, "Error generating ogl texture name!");
        glBindTexture(GL_TEXTURE_2D_ARRAY, texId);
        glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR);
        glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glError();
        glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_ANISOTROPY_EXT, renderSettings.anisotropy);
        glError();
        int bitsPerAxis = to!int(log2(renderSettings.maxTextureSize)); //ex 1024 -> 10
        int bitsPerTile = to!int(log2(renderSettings.pixelsPerTile)); //ex 16 -> 4
        int maxMipMapLevel = bitsPerAxis-bitsPerTile -1; //ex 6
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_LEVEL, maxMipMapLevel);
        glError();
        if(renderSettings.glVersion < 3.0){
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_GENERATE_MIPMAP, GL_TRUE);
            glError();
        }
    }

    void setMinFilter(bool mipLevelInterpolate, bool textureInterpolate){
        assert(texId != 0, "setMinFilter: texId == 0");
        glBindTexture(GL_TEXTURE_2D_ARRAY, texId);
        glError();

        auto filter = mipLevelInterpolate ?
                        (textureInterpolate ?
                            GL_LINEAR_MIPMAP_LINEAR :
                            GL_NEAREST_MIPMAP_LINEAR) :
                        (textureInterpolate ?
                            GL_LINEAR_MIPMAP_NEAREST :
                            GL_NEAREST_MIPMAP_NEAREST);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, filter);
        glError();
    }

    //Upload if can
    void upload(){
        mixin(LogTime!("AtlasUpload"));
        enforce(!texId, "texId != 0, error error error crying babies");
        int tileCount = tileMap.length;
        enforce(tileCount <= maxTileCount, "Derp e ti derp! can't allocate space for all tiles!");
        int layerCount = (tileCount / tilesPerLayer) + tileCount%tilesPerLayer==0 ? 0 : 1;
        genTex();
        auto size = renderSettings.maxTextureSize;

        uint bytesPerLayer = layerCount*(size^^2)*4;
        uint now = atlasData.length;
        version(none){
            uint d = now % bytesPerLayer;
            uint padCount = d == 0 ? 0 : bytesPerLayer - d;

            char[] asd;
            asd.length = padCount;
            asd[] = 255;

            //atlasData.length += padCount;
            atlasData ~= asd;

            Image img = Image(atlasData.ptr, size, size);
            img.save("derp.bmp");
        }

        glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, size, size, layerCount, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        glError();

        vec2i tileSize = vec2i(1,1)*renderSettings.pixelsPerTile;
        ubyte* dataPtr = atlasData.ptr;
        foreach(uint num ; 0 .. tileMap.length){
            auto index = tileIndexFromNumber(num);
            auto offsetX = tileSize.X * index.X;
            auto offsetY = tileSize.Y * index.Y;
            auto layer = index.Z;
            glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, offsetX, offsetY, layer, tileSize.X, tileSize.Y, 1, GL_RGBA, GL_UNSIGNED_BYTE, dataPtr);
            dataPtr += 4*tileSize.X*tileSize.Y;
        }

        atlasData.length=0;
        tileMap = null;

        if(renderSettings.glVersion >= 3.0){
            debug msg("Generating mipmaps 'manually' for tile atlas...");
            glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
            glError();
        }
    }

    ushort addTile(string filename, vec2i offset=vec2i(0,0),
            vec3i tint=vec3i(255,255,255)) {

        ushort tileCount = to!ushort(tileMap.length);
        assert(tileCount < maxTileCount, "Implement code to reallocate etc, or recode caller to reserve properly!!");
        enforce(tileCount < 100000, "Might want to think about reworking the auto-generated tileIndexFromNumber to account for float precision?");

        auto index = tuple(filename, offset, tint);
        ushort* valuePtr = (index in tileMap);
        if(valuePtr){
            return *valuePtr;
        }

        vec2i tileSize = vec2i(1, 1)*renderSettings.pixelsPerTile;
        Image img = Image(filename, offset, tileSize);
        img.tint(tint);
        atlasData ~= img.imgData;

        //glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, offsetX, offsetY, layer, tileSize.X, tileSize.Y, 1, GL_RGBA, GL_UNSIGNED_BYTE, img.imgData.ptr);

        return tileMap[index] = tileCount;
    }

    void use(int textureUnit = 0){
        enforce(texId != 0, "No texture set/uploaded/made! Sad sad sadness is overpowering!");
        glActiveTexture(GL_TEXTURE0 + textureUnit);
        glError();
        glBindTexture(GL_TEXTURE_2D_ARRAY, texId);
        glError();
    }
}

