#include "Renderer.h"
#include "World.h"
#include "Block.h"
#include "Chunk.h"
#include "RenderStrategy.h"
#include "gl.h"

typedef void (APIENTRYP PFNGLTEXIMAGE3DPROC) (GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLsizei depth, GLint border, GLenum format, GLenum type, const GLvoid *pixels);
typedef void (APIENTRYP PFNGLTEXSUBIMAGE3DPROC) (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLenum type, const GLvoid *pixels);


Renderer::Renderer(World *pWorld, IVideoDriver *pDriver)
    : m_pWorld(pWorld),
    m_pDriver(pDriver),
    m_pRenderStrategy(NULL)
{
    const u8 ImgCnt=5;
    IImage *pImages[ImgCnt];
    u32 width=0, height=0;
    for(int i=0;i<ImgCnt;i++){
        char arr[80];
        sprintf_s(arr, "textures/%03d.png", i+1);
        pImages[i] = m_pDriver->createImageFromFile(arr);
        if(pImages[i]){
            width   = pImages[i]->getDimension().Width; //TODO: More elegant code.
            height  = pImages[i]->getDimension().Height;
        }
    }
    ASSERT(width*height != 0);

    PFNGLTEXIMAGE3DPROC glTexImage3D = (PFNGLTEXIMAGE3DPROC)wglGetProcAddress("glTexImage3D");
    ASSERT(glTexImage3D != NULL);
    PFNGLTEXSUBIMAGE3DPROC glTexSubImage3D = (PFNGLTEXSUBIMAGE3DPROC)wglGetProcAddress("glTexSubImage3D");
    ASSERT(glTexSubImage3D != NULL);


    glGenTextures(1, &m_TextureAtlas);
    glBindTexture(GL_TEXTURE_2D_ARRAY, m_TextureAtlas);

    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST); //TODO: Check GL_NEAREST_MIPMAP_NEAREST / GL_NEAREST_CLIPMAP_NEAREST_SGIX

    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); //Like, why not? TODO: Think about it.
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

///////// THESE ARE ATTEMPTS TO REMOVE UGLY WHITE LINES
//*
    f32 max;
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &max);
    printf("%f\n", max);
    glTexParameterf(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_ANISOTROPY_EXT, max);
    //glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
//*/
/////////

//*
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST); //TODO: Check GL_NEAREST_MIPMAP_NEAREST / GL_NEAREST_CLIPMAP_NEAREST_SGIX
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAX_LEVEL, 6); // (2^10)/(2^6) = 2^4 = 16 yeah! tiles reduced to one pixel!
    //glHint(GL_GENERATE_MIPMAP_HINT, GL_FASTEST);
    //IF 1.4 <= GL-VERSION < 3.0
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_GENERATE_MIPMAP, GL_TRUE);
    //END IF 1.4 <= GL-VERSION < 3.0
//*/

    glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, width, height, ImgCnt, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    for(int i=0;i<ImgCnt;i++){
        if(pImages[i]){
            ASSERT(width == pImages[i]->getDimension().Width);
            ASSERT(height== pImages[i]->getDimension().Height);
            GLenum format;
            ECOLOR_FORMAT fmt = pImages[i]->getColorFormat();
            if(fmt == ECF_A8R8G8B8){
                format = GL_RGBA;
            }else if(fmt == ECF_R8G8B8){
                format = GL_RGB;
            }else{
                BREAKPOINT(); //Derp a herp. Maybe add support later. Maybe.
            }
            void *pData = pImages[i]->lock();
            glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, i, width, height, 1, format, GL_UNSIGNED_BYTE, pData);
            pImages[i]->unlock();
            pImages[i]->drop();
            pImages[i] = NULL;
        }
    }
    //IF 3.0 <= GL-VERSION
    //glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
    //END IF 3.0 <= GL-VERSION



    //m_pRenderStrategy = new RenderStrategySimple(pDriver);        //Veeerrry slow
    //m_pRenderStrategy = new RenderStrategyVBO(pDriver);           //Likewise
    //m_pRenderStrategy = new RenderStrategyVBOPerBlock(pDriver);   //Acceptable rates
    m_pRenderStrategy = new RenderStrategyVBOPerBlockSharedCubes(pDriver);  //Acceptable rates as well
    

    glDisable(GL_LIGHTING);
    glFrontFace(GL_CCW);

}


Renderer::~Renderer(void)
{
    delete m_pRenderStrategy;
}



void Renderer::renderChunk(Chunk *pChunk){
    m_pRenderStrategy->renderChunk(pChunk);
}

void Renderer::getChunksToRender(){
    SectorList *pSectors = m_pWorld->lock();
    m_chunksToRender.set_used(0);
    foreach(it, (*pSectors)){
        Sector *pSector = *it;
        Chunk **pChunks = pSector->lockChunks();
        for(int i=0;i<CHUNKS_PER_SECTOR;i++){
            Chunk* pChunk = pChunks[i];
            if(!CHUNK_VISIBLE(pChunk)){
                continue;
            }
            /* IF IN FRUSTUM OR LIKE SO, ELSE CONTIUNUE */
            pChunk->lockBlocks(); //Release when done with the chunk.
            m_chunksToRender.push_back(pChunk);
        }
        pSector->unlockChunks(pChunks);
    }
    m_pWorld->unlock(pSectors);

    //TODO: Sort chunks front to back?

}



void Renderer::preRender(Camera *pCamera){
//    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D_ARRAY_EXT, m_TextureAtlas);
    m_pRenderStrategy->preRender(pCamera);
    getChunksToRender();
}

void Renderer::renderWorld(){
    Chunk **pChunks = m_chunksToRender.pointer();
    int size = m_chunksToRender.size();

    const bool DepthFirst = false;
    if(DepthFirst){    
        m_pRenderStrategy->setPass(false, true);
        for(int i=0;i<size;i++){
            Chunk *pChunk = pChunks[i];
            renderChunk(pChunk);
        }
        m_pRenderStrategy->setPass(true, false);
        for(int i=0;i<size;i++){
            Chunk *pChunk = pChunks[i];
            renderChunk(pChunk);
            pChunk->unlockBlocks(NULL); //TODO: Figure out way to do this nicelylylyl.
        }
    }else{
        m_pRenderStrategy->setPass(true, true);
        for(int i=0;i<size;i++){
            Chunk *pChunk = pChunks[i];
            renderChunk(pChunk);
            pChunk->unlockBlocks(NULL); //TODO: Figure out way to do this nicelylylyl.
        }
    }
}

void Renderer::postRender(){
    m_pRenderStrategy->postRender();

}



