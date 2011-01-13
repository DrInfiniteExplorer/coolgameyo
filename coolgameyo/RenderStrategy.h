#pragma once

#include "include.h"
#include "gl.h"
#include "Block.h"

class Block;
class Chunk;

class RenderStrategy
{
private:
protected:
    PFNGLGENBUFFERSARBPROC gen;
    PFNGLBINDBUFFERARBPROC bind;
    PFNGLBUFFERDATAARBPROC bufferdata;
    PFNGLDELETEBUFFERSARBPROC del;
    PFNGLGETBUFFERPARAMETERIVARBPROC getbufparam;

    IVideoDriver *m_pDriver;
    virtual void renderBlock(Block *pBlock) = 0;
public:
    RenderStrategy(IVideoDriver *pDriver);
    virtual ~RenderStrategy(void);

    virtual void preRender() = 0;
    virtual void renderChunk(Chunk *pChunk);
    virtual void postRender() = 0;
};

class RenderStrategySimple : public RenderStrategy
{
private:

public:
    RenderStrategySimple(IVideoDriver *pDriver);
    virtual ~RenderStrategySimple();

    virtual void preRender();
    virtual void renderBlock(Block *pBlock);
    virtual void postRender();
};


class RenderStrategyVBO : public RenderStrategy
{
private:
    GLuint cubeVBO[2];
public:
    RenderStrategyVBO(IVideoDriver *pDriver);
    virtual ~RenderStrategyVBO();

    virtual void preRender();
    virtual void renderBlock(Block *pBlock);
    virtual void postRender();
};

class RenderStrategyVBOPerBlock : public RenderStrategy
{
private:
    unsigned short uploadBlock(Block *pBlock);
    float m_vertices[24*TILES_PER_BLOCK];
    unsigned short m_indices[36*TILES_PER_BLOCK];
public:
    RenderStrategyVBOPerBlock(IVideoDriver *pDriver);
    virtual ~RenderStrategyVBOPerBlock();

    virtual void preRender();
    virtual void renderBlock(Block *pBlock);
    virtual void postRender();
};

class RenderStrategyVBOPerBlockSharedCubes : public RenderStrategy
{
private:
    unsigned short uploadBlock(Block *pBlock);
    GLuint m_cubesVBO;    
    unsigned short m_indices[36*TILES_PER_BLOCK];
public:
    RenderStrategyVBOPerBlockSharedCubes(IVideoDriver *pDriver);
    virtual ~RenderStrategyVBOPerBlockSharedCubes();

    virtual void preRender();
    virtual void renderBlock(Block *pBlock);
    virtual void postRender();
};



