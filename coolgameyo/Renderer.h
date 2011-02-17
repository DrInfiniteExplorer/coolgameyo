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



public:
    Renderer(World *pWorld, IVideoDriver *pDriver);
    ~Renderer(void);

    void preRender(Camera *pCamera);
    void renderWorld();
    void postRender();
};

