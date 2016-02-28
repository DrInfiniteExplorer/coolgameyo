
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
import cgy.math.vector;
import cgy.opengl.textures;
import cgy.util.statistics;





class TileTextureAtlas{
    uint texId;

    int tilesPerAxis;
    int tilesPerLayer;
    int maxTileCount;

    ubyte[] atlasData;
    static struct wtf {
        Tuple!(string, vec2i, vec3ub) data;
        alias data this;

        bool opEquals(ref const wtf o) const {
            return data[0] == o[0] && data[1] == o[1] && data[2] == o[2];
        }
    }
    ushort[wtf] tileMap;

    vec3i tileIndexFromNumber(int num){
        auto layer = num / tilesPerLayer;
        auto y = (num / tilesPerAxis) % tilesPerAxis;
        auto x = num % tilesPerAxis;

        return vec3i(x, y, layer);
    }

    int tileNumberFromIndex(vec3i index){
        return index.x + tilesPerAxis*index.y + tilesPerLayer*index.z;
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
        DeleteTextures(texId);
        texId = 0;
        destroyed = true;
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
        int tileCount = cast(int)tileMap.length;
        enforce(tileCount <= maxTileCount, "Derp e ti derp! can't allocate space for all tiles!");
        int layerCount = (tileCount / tilesPerLayer) + tileCount%tilesPerLayer==0 ? 0 : 1;
        auto size = renderSettings.maxTextureSize;

        uint bytesPerLayer = layerCount*(size^^2)*4;
        uint now = cast(uint)atlasData.length;

        glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, size, size, layerCount, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        glError();
        texId = Create2DArrayTexture(GL_RGBA8, size, size, layerCount);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST); glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR); glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glError();
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); glError();
        glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_ANISOTROPY_EXT, renderSettings.anisotropy); glError();
        int bitsPerAxis = to!int(log2(renderSettings.maxTextureSize)); //ex 1024 -> 10
        int bitsPerTile = to!int(log2(renderSettings.pixelsPerTile)); //ex 16 -> 4
        int maxMipMapLevel = bitsPerAxis-bitsPerTile -1; //ex 6
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_LEVEL, maxMipMapLevel); glError();
        if(g_glVersion < 3.0){
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_GENERATE_MIPMAP, GL_TRUE);
            glError();
        }


        vec2i tileSize = vec2i(1,1)*renderSettings.pixelsPerTile;
        ubyte* dataPtr = atlasData.ptr;
        foreach(ulong num ; 0 .. tileMap.length){
            auto index = tileIndexFromNumber(cast(uint)num);
            auto offsetX = tileSize.x * index.x;
            auto offsetY = tileSize.y * index.y;
            auto layer = index.z;
            glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, offsetX, offsetY, layer, tileSize.x, tileSize.y, 1, GL_RGBA, GL_UNSIGNED_BYTE, dataPtr);
            dataPtr += 4*tileSize.x*tileSize.y;
        }

        atlasData = null;
        tileMap = null;

        if(g_glVersion >= 3.0){
            debug msg("Generating mipmaps 'manually' for tile atlas...");
            glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
            glError();
        }
    }

    ushort addTile(string filename,
                   vec2i offset=vec2i(0,0),
            vec3ub tint=vec3ub(255,255,255)) {

        ushort tileCount = to!ushort(tileMap.length);
        assert(tileCount < maxTileCount, "Implement code to reallocate etc, or recode caller to reserve properly!!");
        enforce(tileCount < 100000, "Might want to think about reworking the auto-generated tileIndexFromNumber to account for float precision?");

        auto index = tuple(filename, offset, tint);
        ushort* valuePtr = (wtf(index) in tileMap);
        if(valuePtr){
            return *valuePtr;
        }

        vec2i tileSize = vec2i(renderSettings.pixelsPerTile);
        Image img = Image(filename, offset, tileSize);
        img.tint(tint);
        atlasData ~= img.imgData;

        //glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, offsetX, offsetY, layer, tileSize.x, tileSize.y, 1, GL_RGBA, GL_UNSIGNED_BYTE, img.imgData.ptr);

        return tileMap[wtf(index)] = tileCount;
    }

    void use(int textureUnit = 0){
        enforce(texId != 0, "No texture set/uploaded/made! Sad sad sadness is overpowering!");
        glActiveTexture(GL_TEXTURE0 + textureUnit);
        glError();
        glBindTexture(GL_TEXTURE_2D_ARRAY, texId);
        glError();
    }
}

