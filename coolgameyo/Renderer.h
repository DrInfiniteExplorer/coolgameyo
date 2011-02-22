#pragma once

#include "include.h"

class World;
class Block;
class RenderStrategy;
class Camera;

#include <set>

class Renderer
{
private:
    World           *m_pWorld;
    IVideoDriver    *m_pDriver;


    u32              m_2dtex; //Used only to test fixed funtion pipeline.

    u32              m_TextureAtlas;

    RenderStrategy  *m_pRenderStrategy;

    f32              m_oglVersion;

    u32 loadTextures(bool textureArray);

    void renderBlock(Block *pBlock);

    static std::set<vec3i> m_blobSet;

public:
    Renderer(World *pWorld, IVideoDriver *pDriver);
    ~Renderer(void);

    void preRender(Camera *pCamera);
    void renderWorld();
    void postRender();

    void renderBlobs();
    static void addBlob(vec3i pos);


};

