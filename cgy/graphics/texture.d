
module graphics.texture;

import std.algorithm;
import std.conv;
import std.string;
import std.math;
import std.typecons;
import std.exception;

import derelict.devil.il;
import derelict.opengl.gl;
import derelict.opengl.glext;

import graphics.renderer;
import util;

struct Image{
    string filename;
    int imgWidth;
    int imgHeight;
    ubyte[] imgData;
    
    this(string filename){
        this(filename, vec2i(0, 0), vec2i(int.max, int.max));
    }
    this(string _filename, vec2i offset, vec2i size){
        filename = _filename;

        uint ilImgID;
		ilGenImages(1, &ilImgID);
        scope(exit) ilDeleteImages(1, &ilImgID);
		ilBindImage(ilImgID);
		
		ilEnable(IL_ORIGIN_SET);
		ilSetInteger(IL_ORIGIN_MODE, IL_ORIGIN_UPPER_LEFT);
        
        auto cString = toStringz(filename);
		if (ilLoad(IL_TYPE_UNKNOWN, cString) == IL_FALSE)
		{
			assert(0, "error loading image " ~filename);
		}
        
        imgWidth = min(ilGetInteger(IL_IMAGE_WIDTH)- offset.X, size.X);
        imgHeight = min(ilGetInteger(IL_IMAGE_HEIGHT)- offset.Y, size.Y);
        imgData.length = 4*imgWidth*imgHeight;
        ilCopyPixels( offset.X, offset.Y, 0, imgWidth, imgHeight, 1, IL_BGRA, IL_UNSIGNED_BYTE, imgData.ptr);        
    }
    
    unittest{
        char a = 128;
        a *= 0.5;
        assert(a == 64, "derp");
        a = 128;
        a *= 0.25;
        assert(a == 32, "darp");
    }
    
    void tint(vec3i _color) {
        auto color = util.convert!float(_color) * (1.0/255.0);
        for(int i=0; i < imgData.length; i+=4){
            imgData[i+0] *= color.X;
            imgData[i+1] *= color.Y;
            imgData[i+2] *= color.Z;
        }
    }
}

class TileTextureAtlas{
    uint texId;
    
    int tilesPerAxis;
    int tilesPerLayer;
    int maxTileCount;

    ubyte[] atlasData;
    int[Tuple!(string, vec2i, vec3i)] tileMap;

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
    }

    debug{
        ~this(){
            assert(!texId, "Should've called TileTextureAtlas.destroy() at some point!");
        }
    }
    
    void destroy(){
        glDeleteTextures(1, &texId);
        texId = 0;
    }    
    
    void genTex(){
        assert(texId == 0, "texId != 0");
        glGenTextures(1, &texId);
        glBindTexture(GL_TEXTURE_2D_ARRAY, texId);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_ANISOTROPY_EXT, renderSettings.anisotropy);
        int bitsPerAxis = to!int(log2(renderSettings.maxTextureSize)); //ex 1024 -> 10
        int bitsPerTile = to!int(log2(renderSettings.pixelsPerTile)); //ex 16 -> 4
        int maxMipMapLevel = bitsPerAxis-bitsPerTile; //ex 6
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_LEVEL, maxMipMapLevel);        
        if(renderSettings.glVersion < 3.0){
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_GENERATE_MIPMAP, GL_TRUE);
        }
    }
    
    //Upload if can
    void upload(){        
        enforce(!texId, "texId != 0, error error error crying babies");
        int tileCount = tileMap.length;
        enforce(tileCount <= maxTileCount, "Derp e ti derp! can't allocate space for all tiles!");
        int layerCount = (tileCount / tilesPerLayer) + tileCount%tilesPerLayer==0 ? 0 : 1;
        genTex();
        auto size = renderSettings.maxTextureSize;
        glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, size, size, layerCount, 0, GL_RGBA, GL_UNSIGNED_BYTE, atlasData.ptr);
        atlasData.length=0;
        tileMap = null;
        assert(0, "check for errors");
    }
        
    int addTile(string filename, vec2i offset, vec3i tint) {
        int tileCount = tileMap.length;
        assert(tileCount < maxTileCount, "Implement code to reallocate etc, or recode caller to reserve properly!!");
        
        auto index = tuple(filename, offset, tint);
        int* valuePtr = (index in tileMap);
        if(valuePtr){
            return *valuePtr;
        }

        vec2i tileSize = vec2i(1, 1)*renderSettings.pixelsPerTile;
        Image img = Image(filename, offset, tileSize);
        img.tint(tint);
        atlasData ~= img.imgData;
        
        //glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, offsetX, offsetY, layer, tileSize.X, tileSize.Y, 1, GL_RGBA, GL_UNSIGNED_BYTE, img.imgData.ptr);        

        return tileMap[index] = tileCount++;
    }
}

