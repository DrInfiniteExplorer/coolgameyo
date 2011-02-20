#include "Renderer.h"
#include "World.h"
#include "Block.h"
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
                BREAKPOINT; //Derp a herp. Maybe add support later. Maybe.
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



void Renderer::renderBlock(Block *block){
    m_pRenderStrategy->renderBlock(block);
}

#include "Camera.h"

void Renderer::preRender(Camera *pCamera){
//    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D_ARRAY_EXT, m_TextureAtlas);
    m_pRenderStrategy->preRender(pCamera);

    matrix4 proj;
    pCamera->getProjectionMatrix(proj);
    matrix4 view;
    pCamera->getViewMatrix(view);
    glMatrixMode(GL_PROJECTION);

    glLoadMatrixf(proj.pointer());
    glMatrixMode(GL_MODELVIEW);
    glLoadMatrixf(view.pointer());
}

void Renderer::renderWorld(){

    auto sectors = m_pWorld->lock();
    foreach(it, (*sectors)){
        auto *sector = *it;
        auto blocks = sector->lockBlocks();
        for(int i=0;i<BLOCKS_PER_SECTOR;i++){
            auto block = &blocks[i];
            if (!block->isValid() || !block->isVisible()) {
                continue;
            }
            /* IF IN FRUSTUM OR LIKE SO, ELSE CONTIUNUE */
            renderBlock(block);
        }
        sector->unlockBlocks(blocks); //???
    }
    m_pWorld->unlock(sectors);

}

void Renderer::postRender(){
    m_pRenderStrategy->postRender();

}


void Renderer::addBlob(vec3i pos){
    m_blobSet.insert(pos);
}


#pragma warning( push )
#pragma warning( disable : 4244 )
// Some code
int drawSphere(double r, int lats, int longs) {

    int sphereList;
    sphereList = glGenLists(1);
    glNewList(sphereList, GL_COMPILE);

    int i, j;
    for(i = 0; i <= lats; i++) {
        double lat0 = 3.14 * (-0.5 + (double) (i - 1) / lats);
        double z0  = sin(lat0);
        double zr0 =  cos(lat0);
    
        double lat1 = 3.14 * (-0.5 + (double) i / lats);
        double z1 = sin(lat1);
        double zr1 = cos(lat1);
    
        glBegin(GL_QUAD_STRIP);
        for(j = 0; j <= longs; j++) {
            double lng = 2 * 3.14 * (double) (j - 1) / longs;
            double x = cos(lng);
            double y = sin(lng);

            glNormal3f(x * zr0, y * zr0, z0);
            glVertex3f(x * zr0, y * zr0, z0);
            glNormal3f(x * zr1, y * zr1, z1);
            glVertex3f(x * zr1, y * zr1, z1);
        }
        glEnd();
    }
    glEndList();
    return sphereList;
}


int drawCube(float scale, bool fill = false)
{
    int list = glGenLists(1);
    glNewList(list, GL_COMPILE);

    glColor3f(1.0f, 0.0f, 0.0f);
    if(!fill){
        glDisable(GL_CULL_FACE);
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    }
    glPushMatrix();
    glScalef(scale, scale, scale);
    glBegin(GL_QUADS);
    // Front Face
    glNormal3f( 0.0f, 0.0f, 0.5f);					
    glTexCoord2f(0.0f, 0.0f); glVertex3f(-1.0f, -1.0f,  1.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex3f( 1.0f, -1.0f,  1.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex3f( 1.0f,  1.0f,  1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex3f(-1.0f,  1.0f,  1.0f);
    // Back Face
    glNormal3f( 0.0f, 0.0f,-0.5f);					
    glTexCoord2f(1.0f, 0.0f); glVertex3f(-1.0f, -1.0f, -1.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex3f(-1.0f,  1.0f, -1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex3f( 1.0f,  1.0f, -1.0f);
    glTexCoord2f(0.0f, 0.0f); glVertex3f( 1.0f, -1.0f, -1.0f);
    // Top Face
    glNormal3f( 0.0f, 0.5f, 0.0f);					
    glTexCoord2f(0.0f, 1.0f); glVertex3f(-1.0f,  1.0f, -1.0f);
    glTexCoord2f(0.0f, 0.0f); glVertex3f(-1.0f,  1.0f,  1.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex3f( 1.0f,  1.0f,  1.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex3f( 1.0f,  1.0f, -1.0f);
    // Bottom Face
    glNormal3f( 0.0f,-0.5f, 0.0f);					
    glTexCoord2f(1.0f, 1.0f); glVertex3f(-1.0f, -1.0f, -1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex3f( 1.0f, -1.0f, -1.0f);
    glTexCoord2f(0.0f, 0.0f); glVertex3f( 1.0f, -1.0f,  1.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex3f(-1.0f, -1.0f,  1.0f);
    // Right Face
    glNormal3f( 0.5f, 0.0f, 0.0f);					
    glTexCoord2f(1.0f, 0.0f); glVertex3f( 1.0f, -1.0f, -1.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex3f( 1.0f,  1.0f, -1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex3f( 1.0f,  1.0f,  1.0f);
    glTexCoord2f(0.0f, 0.0f); glVertex3f( 1.0f, -1.0f,  1.0f);
    // Left Face
    glNormal3f(-0.5f, 0.0f, 0.0f);					
    glTexCoord2f(0.0f, 0.0f); glVertex3f(-1.0f, -1.0f, -1.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex3f(-1.0f, -1.0f,  1.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex3f(-1.0f,  1.0f,  1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex3f(-1.0f,  1.0f, -1.0f);
    glEnd();
    if(!fill){
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        glEnable(GL_CULL_FACE);
    }
    glPopMatrix();
    glEndList();
    return list;
}
#pragma warning( pop ) 

std::set<vec3i> Renderer::m_blobSet;
int sphereList = 0;
int cubeList = 0;
void Renderer::renderBlobs(){
    sphereList = sphereList ? sphereList : drawSphere(5.0, 20, 20);
    cubeList = cubeList ? cubeList : drawCube(4);
    foreach(iter, m_blobSet){
        auto pos = *iter;
        glPushMatrix();
        glTranslatef((f32)pos.X, (f32)pos.Y, (f32)pos.Z);
        //*
        glCallList(sphereList);
        glCallList(cubeList);
        //*/
        glPopMatrix();
    }
}



