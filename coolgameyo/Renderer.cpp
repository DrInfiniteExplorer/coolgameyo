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
    glBindTexture(GL_TEXTURE_2D_ARRAY_EXT, m_TextureAtlas);

    glTexParameteri(GL_TEXTURE_2D_ARRAY_EXT, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D_ARRAY_EXT, GL_TEXTURE_MIN_FILTER, GL_NEAREST); //TODO: Check GL_NEAREST_MIPMAP_NEAREST / GL_NEAREST_CLIPMAP_NEAREST_SGIX

    glTexParameteri(GL_TEXTURE_2D_ARRAY_EXT, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D_ARRAY_EXT, GL_TEXTURE_WRAP_T, GL_REPEAT);

    //TODO: Find out what this SGIS is. Apparently same id as non-_SGIS. ?
    //glTexParameteri(GL_TEXTURE_2D_ARRAY_EXT, GL_GENERATE_MIPMAP_SGIS, GL_TRUE);
    glTexImage3D(GL_TEXTURE_2D_ARRAY_EXT, 0, GL_RGBA8, width, height, ImgCnt, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
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
            glTexSubImage3D(GL_TEXTURE_2D_ARRAY_EXT, 0, 0, 0, i, width, height, 1, format, GL_UNSIGNED_BYTE, pData);
            pImages[i]->unlock();
            pImages[i]->drop();
            pImages[i] = NULL;
        }
    }

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

    matrix4 proj, view;
    proj = m_pDriver->getTransform(ETS_PROJECTION);
    view = m_pDriver->getTransform(ETS_VIEW);

    glDisable(GL_LIGHTING);
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D_ARRAY_EXT, m_TextureAtlas);
    m_pRenderStrategy->preRender(proj * view);
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


