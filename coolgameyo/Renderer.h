#pragma once

#include "include.h"

class World;
class Block;
class Chunk;
class RenderStrategy;
class Camera;


class Renderer
{
private:
    World           *m_pWorld;
    IVideoDriver    *m_pDriver;

    u32              m_TextureAtlas;

    RenderStrategy  *m_pRenderStrategy;

    void renderBlock(Block *pBlock);
    void renderChunk(Chunk *pChunk);

    /*  Aquire a nd fill a list of pointers to locked chunks. The world(sectors[actually chunkptr's]) is locked
        until a lock is aquired for all chunks[actually blocks] in the world, upon which the world is released,
        and the chunks[blocks] are released when they are rendered.*/
    void getChunksToRender();
    core::array<Chunk*> m_chunksToRender; //TODO: Determine if to use irrlicht or stl-container.


public:
    Renderer(World *pWorld, IVideoDriver *pDriver);
    ~Renderer(void);

    void preRender(Camera *pCamera);
    void renderWorld();
    void postRender();
};

