#pragma once

#include "include.h"
#include "gl.h"
#include "Block.h"

class Block;
class Chunk;
class Camera;

class RenderStrategy
{
private:
protected:

    void printShaderError(u32 shader);
    u32 compileShader(const char *filename, GLenum type);
    u32 makeProgram(const char *vert, const char *frag);

    static bool m_bFixTC; //set to true when we've recalculated the texcoords according to atlas size.
    IVideoDriver *m_pDriver;
public:
    RenderStrategy(IVideoDriver *pDriver);
    virtual ~RenderStrategy(void);

    virtual void renderBlock(Block *pBlock) = 0;

    virtual void preRender(Camera *pCamera, u32 a);
    virtual void postRender() = 0;
};

class RenderStrategyVBOPerBlock : public RenderStrategy
{
private:
    unsigned short uploadBlock(Block *pBlock);
    float *m_pVertices;
    float *m_pTexCoords;
    unsigned short *m_pIndices;

    u32 m_vertSize;
    u32 m_vertOffset;
    u32 m_texSize;
    u32 m_texOffset;

    u32 m_indSize;
public:
    RenderStrategyVBOPerBlock(IVideoDriver *pDriver);
    virtual ~RenderStrategyVBOPerBlock();

    virtual void preRender(Camera *pCamera, u32 tex);
    virtual void renderBlock(Block *pBlock);
    virtual void postRender();
};

class RenderStrategyVBOPerBlockSharedCubes : public RenderStrategy
{
private:
    unsigned short uploadBlock(Block *pBlock);
    GLuint m_cubesVBO;    
    unsigned short *m_pIndices;

    u32 m_vertSize;
    u32 m_vertOffset;
    u32 m_texSize;
    u32 m_texOffset;

    u32 m_fullProgram;

    u32 m_loc_MVP;
    u32 m_loc_textureAtlas;
    u32 m_loc_blockPosition;
    u32 m_loc_vertex;
    u32 m_loc_tex;

    u32 m_loc_blockSeen;

public:
    RenderStrategyVBOPerBlockSharedCubes(IVideoDriver *pDriver, bool textureArray);
    virtual ~RenderStrategyVBOPerBlockSharedCubes();



    virtual void preRender(Camera *pCamera, u32 tex);
    virtual void renderBlock(Block *pBlock);
    virtual void postRender();
};



