#include "Renderer.h"
#include "World.h"
#include "Block.h"
#include "RenderStrategy.h"
#include "gl.h"


Renderer::Renderer(World *pWorld, IVideoDriver *pDriver)
    : m_pWorld(pWorld),
    m_pDriver(pDriver),
    m_pRenderStrategy(NULL)
{
    m_2dtex = m_TextureAtlas = 0;

    initGl();

    bool useArray = true;
    if(useArray){
        m_TextureAtlas = loadTextures(true);
    }else{
        m_2dtex = loadTextures(false);
    }

    //m_pRenderStrategy = new RenderStrategyVBOPerBlock(pDriver);   //Acceptable rates
    m_pRenderStrategy = new RenderStrategyVBOPerBlockSharedCubes(pDriver, m_2dtex == 0);  //Acceptable rates as well, less memory footprint
    
    bool persp_hint = false; //Settings
    if(persp_hint){
        glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST); GLERROR();
    }

    glDisable(GL_LIGHTING);
    glFrontFace(GL_CCW);

}


Renderer::~Renderer(void)
{
    delete m_pRenderStrategy;
}

u32 Renderer::loadTextures(bool textureArray){

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
    enforce(width*height != 0);

    GLenum target = textureArray ? GL_TEXTURE_2D_ARRAY : GL_TEXTURE_2D;
    u32 texture;

    glGenTextures(1, &texture); GLERROR();
    glBindTexture(target, texture); GLERROR();
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST); GLERROR();
    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST); GLERROR();
    glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); GLERROR(); //Like, why not? TODO: Think about it.
    glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); GLERROR();

    f32 aniso = 0; //Setting
    f32 max;
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &max); GLERROR();
    aniso = min(aniso, max);
    if(aniso){
        glTexParameterf(target, GL_TEXTURE_MAX_ANISOTROPY_EXT, max); GLERROR();
    }

    u32 mipmap_level=4; //Setting
    mipmap_level = min(mipmap_level, 4); //4 since 16->8->4->2->1 is 4 mipmap-levels.
    bool mipmap_speed_hint = false; //Setting
    if(mipmap_level){
        glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST); GLERROR(); //TODO: Check GL_NEAREST_MIPMAP_NEAREST / GL_NEAREST_CLIPMAP_NEAREST_SGIX
        glTexParameteri(target, GL_TEXTURE_MAX_LEVEL, mipmap_level);  GLERROR();// (2^10)/(2^6) = 2^4 = 16 yeah! tiles reduced to one pixel!
        if(mipmap_speed_hint){
            glHint(GL_GENERATE_MIPMAP_HINT, GL_FASTEST); GLERROR();
        }
        if(glVersion < 3.0){
            glTexParameteri(target, GL_GENERATE_MIPMAP, GL_TRUE); GLERROR();
        }
    }

    if(textureArray){
        glTexImage3D(target, 0, GL_RGBA8, width, height, ImgCnt, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL); GLERROR();
    }
    for(int i=0;i<ImgCnt;i++){
        if(pImages[i]){
            enforce(width == pImages[i]->getDimension().Width);
            enforce(height== pImages[i]->getDimension().Height);
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
            if(textureArray){
                glTexSubImage3D(target, 0, 0, 0, i, width, height, 1, format, GL_UNSIGNED_BYTE, pData); GLERROR();
            }else{
                glTexImage2D(target, 0, GL_RGBA8, width, height, 0, format, GL_UNSIGNED_BYTE, pData); GLERROR();
                pImages[i]->unlock();
                pImages[i]->drop();
                pImages[i] = NULL;
                break; //Break after first, or only generate first?
            }
            pImages[i]->unlock();
            pImages[i]->drop();
            pImages[i] = NULL;
        }
    }

    if(mipmap_level && glVersion >= 3.0){
        glGenerateMipmap(target); GLERROR();
    }
    return texture;
}



void Renderer::renderBlock(Block *block){
    m_pRenderStrategy->renderBlock(block);
}

#include "Camera.h"

void Renderer::preRender(Camera *pCamera){

    if(m_2dtex){
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, m_2dtex);
        glColor3f(1.f, 1.f, 1.f);
        m_pRenderStrategy->preRender(pCamera, m_2dtex);
    }else{    
        glBindTexture(GL_TEXTURE_2D_ARRAY_EXT, m_TextureAtlas);
        m_pRenderStrategy->preRender(pCamera, m_TextureAtlas);
    }
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



