#include "Renderer.h"
#include "World.h"
#include "Block.h"
#include "Chunk.h"
#include "RenderStrategy.h"

Renderer::Renderer(World *pWorld, IVideoDriver *pDriver)
    : m_pWorld(pWorld),
    m_pDriver(pDriver)
{
    m_pTextureAtlas = m_pDriver->getTexture("textures/1.png");
    //m_pRenderStrategy = new RenderStrategySimple(pDriver);        //Veeerrry slow
    //m_pRenderStrategy = new RenderStrategyVBO(pDriver);           //Likewise
    //m_pRenderStrategy = new RenderStrategyVBOPerBlock(pDriver);   //Acceptable rates
    m_pRenderStrategy = new RenderStrategyVBOPerBlockSharedCubes(pDriver);  //Acceptable rates as well
    
}


Renderer::~Renderer(void)
{
    delete m_pRenderStrategy;
}

void Renderer::preRender(){
    m_pRenderStrategy->preRender();
}

void Renderer::postRender(){
    m_pRenderStrategy->postRender();
}

void Renderer::renderBlock(Block *pBlock){
    /*     Bind texture atlas!!!     */
    /*        (already bound?)       */
    /*  (consider unbound rendering  */
    // m_pRenderStrategy->renderBlock(pBlock);
    /*  Unbind texture atlas?  */

    BREAKPOINT; //Should we at all keep this function? 

}


void Renderer::renderChunk(Chunk *pChunk){
    m_pRenderStrategy->renderChunk(pChunk);
}


