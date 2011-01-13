#include "RenderStrategy.h"
#include "Chunk.h"
#include "Block.h"
#include "Tile.h"

#pragma comment(lib, "opengl32.lib")

static_assert(sizeof(u8 ) == sizeof(GLubyte),       "Size of u8  != size of GLubyte !!!");
static_assert(sizeof(u16) == sizeof(GLushort),      "Size of u16 != size of GLushort!!!");
static_assert(sizeof(u32) == sizeof(GLuint),        "Size of u32 != size of GLuint  !!!");
static_assert(sizeof(f32) == sizeof(GLfloat),       "Size of f32 != size of GLfloat !!!");

RenderStrategy::RenderStrategy(IVideoDriver *pDriver)
    : m_pDriver(pDriver)
{
    gen = (PFNGLGENBUFFERSARBPROC)wglGetProcAddress("glGenBuffersARB");
    bind = (PFNGLBINDBUFFERARBPROC )wglGetProcAddress("glBindBufferARB");
    bufferdata = (PFNGLBUFFERDATAARBPROC)wglGetProcAddress("glBufferDataARB");
    del = (PFNGLDELETEBUFFERSARBPROC)wglGetProcAddress("glDeleteBuffersARB");

    getbufparam = (PFNGLGETBUFFERPARAMETERIVARBPROC)wglGetProcAddress("glGetBufferParameterivARB");
}


RenderStrategy::~RenderStrategy(void)
{
}

void RenderStrategy::renderChunk(Chunk *pChunk){
    auto *pBlocks = pChunk->lockBlocks();

    for (int c=0;c<BLOCKS_PER_CHUNK;c++) {
        Block *pBlock = &pBlocks[c];

        if (!pBlock->isVisible()) {
            continue;
        }
        renderBlock(pBlock);
    }

    pChunk->unlockBlocks(pBlocks);
}

static GLfloat cubeVertices[]={
    0, 0, 0,
    1, 0, 0,
    0, 0, 1,
    1, 0, 1,
    1, 1, 0,
    0, 1, 0,
    1, 1, 1,
    0, 1, 1
};
static unsigned int cubeVertexCount = sizeof(cubeVertices)/(sizeof(cubeVertices[0])*3);

static GLfloat cubeTextCoords[]={
    0
};

static GLubyte cubeIndices[]={
    0, 1, 2,
    1, 3, 2,
    4, 5, 6,
    5, 7, 6,
    1, 4, 3,
    4, 6, 3,

    5, 0, 7,
    0, 2, 7,
    2, 3, 7,
    3, 6, 7,
    1, 0, 4,
    0, 5, 4

};
static unsigned int cubeIndexCount = sizeof(cubeIndices)/sizeof(cubeIndices[0]);




RenderStrategySimple::RenderStrategySimple(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{

}

RenderStrategySimple::~RenderStrategySimple(){

}

void RenderStrategySimple::preRender(){
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(3, GL_FLOAT, 0, cubeVertices);
}
void RenderStrategySimple::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
}
void RenderStrategySimple::renderBlock(Block *pBlock){
    matrix4 blockOrigin;
    vec3i blockPos = pBlock->getPosition();

    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile &t = pBlock->getTile(vec3i(x,y,z));
        if(!TILE_VISIBLE(t) || t.type == ETT_AIR){
            continue;
        }
        blockOrigin.setTranslation(vec3f(
            (f32)(blockPos.X+x),
            (f32)(blockPos.Y+y),
            (f32)(blockPos.Z+z)
            ));

        m_pDriver->setTransform(ETS_WORLD, blockOrigin);
        SMaterial mat;
        m_pDriver->setMaterial(mat);

        glDrawElements(GL_TRIANGLES, sizeof(cubeIndices)/(sizeof(cubeIndices[0])), GL_UNSIGNED_BYTE, cubeIndices);
    }
    }
    }
}

RenderStrategyVBO::RenderStrategyVBO(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{
    gen(2, cubeVBO);

    bind(GL_ARRAY_BUFFER_ARB, cubeVBO[0]);
    bufferdata(GL_ARRAY_BUFFER_ARB, sizeof(cubeVertices), cubeVertices, GL_STATIC_DRAW_ARB);

    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, cubeVBO[1]);
    bufferdata(GL_ELEMENT_ARRAY_BUFFER_ARB, sizeof(cubeIndices), cubeIndices, GL_STATIC_DRAW_ARB);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
    
}

RenderStrategyVBO::~RenderStrategyVBO(){
    del(2, cubeVBO);
}


void RenderStrategyVBO::preRender(){
    bind(GL_ARRAY_BUFFER_ARB, cubeVBO[0]);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, cubeVBO[1]);
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(3, GL_FLOAT, 0, 0);
}
void RenderStrategyVBO::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
    bind(GL_ARRAY_BUFFER_ARB, 0);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
}
void RenderStrategyVBO::renderBlock(Block *pBlock){
    matrix4 blockOrigin;
    vec3i blockPos = pBlock->getPosition();


    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile &t = pBlock->getTile(vec3i(x,y,z));
        if(!TILE_VISIBLE(t) || t.type == ETT_AIR){
            continue;
        }
        blockOrigin.setTranslation(vec3f(
            (f32)(blockPos.X+x),
            (f32)(blockPos.Y+y),
            (f32)(blockPos.Z+z)
            ));
        m_pDriver->setTransform(ETS_WORLD, blockOrigin);
        SMaterial mat;
        m_pDriver->setMaterial(mat);

        glDrawElements(GL_TRIANGLES, sizeof(cubeIndices)/(sizeof(cubeIndices[0])), GL_UNSIGNED_BYTE, 0);
    }
    }
    }
}




////////////////////////////   RenderStrategyVBOPerBlock //////////////////


RenderStrategyVBOPerBlock::RenderStrategyVBOPerBlock(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{    
}

RenderStrategyVBOPerBlock::~RenderStrategyVBOPerBlock(){
}


void RenderStrategyVBOPerBlock::preRender(){
    glEnableClientState(GL_VERTEX_ARRAY);
}
void RenderStrategyVBOPerBlock::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
    bind(GL_ARRAY_BUFFER_ARB, 0);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
}
unsigned short RenderStrategyVBOPerBlock::uploadBlock(Block *pBlock){

    vec3f *vertPtr = (vec3f*)m_vertices;
    unsigned short *indPtr = m_indices;
    unsigned short idx = 0;
    unsigned short cnt=0;
    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile t = pBlock->getTile(vec3i(x, y, z));
        if(TILE_VISIBLE(t) && t.type != ETT_AIR){
            for(u32 i=0;i<cubeVertexCount;i++){
                vertPtr->set(cubeVertices[i*3+0]+x, cubeVertices[i*3+1]+y, cubeVertices[i*3+2]+z);
                vertPtr++;
            }
            for(u32 i=0;i<cubeIndexCount;i++){
                indPtr[i] = cubeIndices[i]+cubeVertexCount*cnt;
            }
            indPtr+=cubeIndexCount;
            idx+=cubeIndexCount;
            cnt++;
        }
    }
    }
    }

    int dataSize = sizeof(cubeVertices)*cnt;
    int indexSize = idx*sizeof(m_indices[0]); //sizeof(cubeIndices)*cnt <-- not that because cubeIndices is made of unsigned chars
    bufferdata(GL_ARRAY_BUFFER_ARB, dataSize, m_vertices, GL_STATIC_DRAW_ARB);
    bufferdata(GL_ELEMENT_ARRAY_BUFFER_ARB, indexSize, m_indices, GL_STATIC_DRAW_ARB);

    int bufferSize;
    getbufparam(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    assert(bufferSize == dataSize);
    getbufparam(GL_ELEMENT_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    assert(bufferSize == indexSize);
    //printf("%d\n%d\n", dataSize, indexSize);
    static int ccc=0;
    ccc++;
    static int sum = 0;
    sum += dataSize + indexSize;
    //printf("!%d %d %d\n", sum, sum/(1024*1024), ccc);

    pBlock->setClean(idx);
    return idx;
}
void RenderStrategyVBOPerBlock::renderBlock(Block *pBlock){
    unsigned short idxCnt;
    GLuint *vbo = pBlock->getVBO(idxCnt);
    if(!vbo[0]){
        gen(2, vbo);
    }

    bind(GL_ARRAY_BUFFER_ARB, vbo[0]);
    glVertexPointer(3, GL_FLOAT, 0, 0);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, vbo[1]);

    if(pBlock->isDirty()){
        idxCnt = uploadBlock(pBlock);
    }

    matrix4 blockOrigin;
    vec3i blockPos = pBlock->getPosition();

    blockOrigin.setTranslation(vec3f(
        (f32)(blockPos.X),
        (f32)(blockPos.Y),
        (f32)(blockPos.Z)
        ));
    m_pDriver->setTransform(ETS_WORLD, blockOrigin);
    glDrawElements(GL_TRIANGLES, idxCnt, GL_UNSIGNED_SHORT, 0);
}


////////////////////////////   RenderStrategyVBOPerBlockSharedCubes //////////////////


RenderStrategyVBOPerBlockSharedCubes::RenderStrategyVBOPerBlockSharedCubes(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{    
    float *vertices = new float[cubeVertexCount*3*TILES_PER_BLOCK];
    vec3f *vertPtr = (vec3f*)vertices;
    unsigned short cnt=0;
    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        for(u32 i=0;i<cubeVertexCount;i++){
            vertPtr->set(cubeVertices[i*3+0]+x, cubeVertices[i*3+1]+y, cubeVertices[i*3+2]+z);
            vertPtr++;
        }
    }
    }
    }

    int dataSize = sizeof(cubeVertices)*TILES_PER_BLOCK;

    gen(1, &m_cubesVBO);
    bind(GL_ARRAY_BUFFER_ARB, m_cubesVBO);
    bufferdata(GL_ARRAY_BUFFER_ARB, dataSize, vertices, GL_STATIC_DRAW_ARB);

    int bufferSize;
    getbufparam(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    assert(bufferSize == dataSize);

    delete [] vertices;
}

RenderStrategyVBOPerBlockSharedCubes::~RenderStrategyVBOPerBlockSharedCubes(){
}


void RenderStrategyVBOPerBlockSharedCubes::preRender(){
    bind(GL_ARRAY_BUFFER_ARB, m_cubesVBO);
    glVertexPointer(3, GL_FLOAT, 0, 0);
    glEnableClientState(GL_VERTEX_ARRAY);
}
void RenderStrategyVBOPerBlockSharedCubes::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
    bind(GL_ARRAY_BUFFER_ARB, 0);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
}
unsigned short RenderStrategyVBOPerBlockSharedCubes::uploadBlock(Block *pBlock){
    unsigned short *indPtr = m_indices;
    unsigned short idx = 0;
    unsigned short cnt=0;
    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile t = pBlock->getTile(vec3i(x, y, z));
        if(TILE_VISIBLE(t) && t.type != ETT_AIR){
            for(u32 i=0;i<cubeIndexCount;i++){
                indPtr[i] = cubeIndices[i]+cubeVertexCount*cnt;
            }
            indPtr+=cubeIndexCount;
            idx+=cubeIndexCount;
        }
        cnt++;
    }
    }
    }

    int indexSize = idx*sizeof(m_indices[0]); //sizeof(cubeIndices)*cnt;
    bufferdata(GL_ELEMENT_ARRAY_BUFFER_ARB, indexSize, m_indices, GL_STATIC_DRAW_ARB);

    static int ccc=0;
    ccc++;
    //printf("%d\n", ccc);

    int bufferSize;
    getbufparam(GL_ELEMENT_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    assert(bufferSize == indexSize);

    pBlock->setClean(idx);
    return idx;
}
void RenderStrategyVBOPerBlockSharedCubes::renderBlock(Block *pBlock){
    unsigned short idxCnt;
    GLuint *vbo = pBlock->getVBO(idxCnt);
    if(!vbo[0]){
        gen(1, vbo);
    }

    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, vbo[0]);

    if(pBlock->isDirty()){
        idxCnt = uploadBlock(pBlock);
    }

    matrix4 blockOrigin;
    vec3i blockPos = pBlock->getPosition();

    blockOrigin.setTranslation(vec3f(
        (f32)(blockPos.X),
        (f32)(blockPos.Y),
        (f32)(blockPos.Z)
        ));
    m_pDriver->setTransform(ETS_WORLD, blockOrigin);
    glDrawElements(GL_TRIANGLES, idxCnt, GL_UNSIGNED_SHORT, 0);
}




