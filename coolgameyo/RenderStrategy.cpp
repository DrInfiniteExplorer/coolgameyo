#include "RenderStrategy.h"
#include "Chunk.h"
#include "Block.h"
#include "Tile.h"
#include "Camera.h"

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
    buffersubdata = (PFNGLBUFFERSUBDATAARBPROC)wglGetProcAddress("glBufferSubDataARB");
    del = (PFNGLDELETEBUFFERSARBPROC)wglGetProcAddress("glDeleteBuffersARB");

    createshader = (PFNGLCREATESHADERPROC)wglGetProcAddress("glCreateShader");
    shadersource = (PFNGLSHADERSOURCEPROC)wglGetProcAddress("glShaderSource");
    compileshader= (PFNGLCOMPILESHADERPROC)wglGetProcAddress("glCompileShader");
    getshaderiv = (PFNGLGETSHADERIVPROC)wglGetProcAddress("glGetShaderiv");
    getshaderinfolog = (PFNGLGETSHADERINFOLOGPROC)wglGetProcAddress("glGetShaderInfoLog");

    createprogram = (PFNGLCREATEPROGRAMPROC)wglGetProcAddress("glCreateProgram");
    attachshader = (PFNGLATTACHSHADERPROC)wglGetProcAddress("glAttachShader");
    linkprogram = (PFNGLLINKPROGRAMPROC)wglGetProcAddress("glLinkProgram");
    useprogram = (PFNGLUSEPROGRAMPROC)wglGetProcAddress("glUseProgram");
    getprogramiv = (PFNGLGETPROGRAMIVPROC)wglGetProcAddress("glGetProgramiv");

    getuniformlocation = (PFNGLGETUNIFORMLOCATIONPROC)wglGetProcAddress("glGetUniformLocation");
    uniform1i = (PFNGLUNIFORM1IPROC)wglGetProcAddress("glUniform1i");
    uniform3iv = (PFNGLUNIFORM3IVPROC)wglGetProcAddress("glUniform3iv");
    uniform3fv = (PFNGLUNIFORM3FVPROC)wglGetProcAddress("glUniform3fv");
    uniformmatrix4fv = (PFNGLUNIFORMMATRIX4FVPROC)wglGetProcAddress("glUniformMatrix4fv");

    getattriblocation = (PFNGLGETATTRIBLOCATIONPROC)wglGetProcAddress("glGetAttribLocation");
    vertexattribpointer = (PFNGLVERTEXATTRIBPOINTERPROC)wglGetProcAddress("glVertexAttribPointer");
    enablevertexattribarray = (PFNGLENABLEVERTEXATTRIBARRAYPROC)wglGetProcAddress("glEnableVertexAttribArray");
    disablevertexattribarray = (PFNGLDISABLEVERTEXATTRIBARRAYPROC)wglGetProcAddress("glDisableVertexAttribArray");

    getbufparam = (PFNGLGETBUFFERPARAMETERIVARBPROC)wglGetProcAddress("glGetBufferParameterivARB");

}


RenderStrategy::~RenderStrategy(void)
{
}

char *readFile(const char *filename){
    if(!filename){
        return NULL;
    }
    FILE *f = NULL;
    fopen_s(&f, filename, "rb");
    if(!f){
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    int size = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *ret = new char[size+1];
    ret[size] = 0;
    fread(ret, 1, size, f);
    fclose(f);
    return ret;
}

void RenderStrategy::printShaderError(u32 shader){
    s32 len, len2;
    getshaderiv(shader, GL_INFO_LOG_LENGTH, &len);
    if(len>0){
        char *arr = new char[len+1];
        arr[len]=0;
        getshaderinfolog(shader, len, &len2, arr);
        printf("!!! %s\n", arr);
        delete [] arr;
    }
}

u32 RenderStrategy::compileShader(const char *filename, GLenum type){
    const char *source = readFile(filename);
    s32 p;
    if(source){
        u32 shader = createshader(type);
        shadersource(shader, 1, &source, 0);
        compileshader(shader);
        delete [] source;
        getshaderiv(shader, GL_COMPILE_STATUS, &p);
        if(p != GL_TRUE){
            printShaderError(shader);
            BREAKPOINT; //Get error log
        }
        return shader;
    }
    return 0;
}

u32 RenderStrategy::makeProgram(const char *vert, const char *frag){
    int c=0;
    const char *fragSource = readFile(frag);
    s32 p;

    u32 vertShader = compileShader(vert, GL_VERTEX_SHADER);
    u32 fragShader = compileShader(frag, GL_FRAGMENT_SHADER);

    if(vertShader+fragShader == 0){ // <-- ASSUME that vert+frag <= wrap-around-limit(=>0)
        BREAKPOINT; //Yeah no shaders specifieced! :(
    }
    s32 program = createprogram();
    if(vertShader){
        attachshader(program, vertShader);
    }
    if(fragShader){
        attachshader(program, fragShader);
    }
    linkprogram(program);
    getprogramiv(program, GL_LINK_STATUS, &p);
    if(p != GL_TRUE){
        BREAKPOINT; //YAYA
    }

    //TODO: Add deleting and/or checking for already created programs.

    return program;
}

void RenderStrategy::preRender(Camera *pCamera){
    matrix4 projection, view;
    pCamera->getProjectionMatrix(projection);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glLoadMatrixf(projection.pointer());
    glMatrixMode(GL_MODELVIEW);
}

void RenderStrategy::renderChunk(Chunk *pChunk){
    auto *pBlocks = pChunk->lockBlocks();

    for (int c=0;c<BLOCKS_PER_CHUNK;c++) {
        Block *pBlock = &pBlocks[c];

        if (!pBlock->isValid() ||!pBlock->isVisible()) {
            continue;
        }
        renderBlock(pBlock);
    }

    pChunk->unlockBlocks(pBlocks);
}

void RenderStrategy::setPass(bool color, bool depth){
    GLbitfield flags = 0;
    if(color && depth){
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glDepthMask(GL_TRUE);
        glDepthFunc(GL_LESS);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    }else{
        if(color){
            glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
            glDepthMask(GL_FALSE);
            glDepthFunc(GL_EQUAL);
            glClear(GL_COLOR_BUFFER_BIT);
        }
        if(depth){
            glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
            glDepthMask(GL_TRUE);
            glDepthFunc(GL_LESS);
            glClear(GL_DEPTH_BUFFER_BIT);
        }
    }
}

static GLfloat cubeVertices[]={
    0, 0, 0,    // 0, 0
    1, 0, 0,    // 1, 0
    1, 0, 1,    // 1, 1
    0, 0, 1,    // 0, 1

    1, 0, 0,
    1, 1, 0,
    1, 1, 1,
    1, 0, 1,

    1, 1, 0,
    0, 1, 0,
    0, 1, 1,
    1, 1, 1,

    0, 1, 0,
    0, 0, 0,
    0, 0, 1,
    0, 1, 1,

    0, 0, 1,
    1, 0, 1,
    1, 1, 1,
    0, 1, 1,

    0, 1, 0,
    1, 1, 0,
    1, 0, 0,
    0, 0, 0

};
static unsigned int cubeVertexCount = sizeof(cubeVertices)/(sizeof(cubeVertices[0])*3);

const float pixelWidth = 1.0f/1024.0f;
const float tileWidth = 16;
//*
const float Z = 0.5f * pixelWidth;
const float O = (tileWidth-0.5f)*pixelWidth;
const float n = (tileWidth+0.5f)*pixelWidth;
const float N = (2*tileWidth-0.5f)*pixelWidth;
const float s = (2*tileWidth+0.5f)*pixelWidth;
const float S = (3*tileWidth-0.5f)*pixelWidth;
/*/
const float Z = 0;
const float O = (tileWidth)*pixelWidth;
const float n = (tileWidth)*pixelWidth;
const float N = (2*tileWidth)*pixelWidth;
const float s = (2*tileWidth)*pixelWidth;
const float S = (3*tileWidth)*pixelWidth;
//*/
static GLfloat cubeTextCoords[]={
    Z, O,
    O, O,
    O, Z,
    Z, Z,

    Z, O,
    O, O,
    O, Z,
    Z, Z,

    Z, O,
    O, O,
    O, Z,
    Z, Z,

    Z, O,
    O, O,
    O, Z,
    Z, Z,

    Z, N,
    O, N,
    O, n,
    Z, n,

    Z, S,
    O, S,
    O, s,
    Z, s,

};

static unsigned int cubeTexCoordElementCount = sizeof(cubeTextCoords)/sizeof(cubeTextCoords[0]);

static GLubyte cubeIndices[]={
     0,  1,  2,  3,
     4,  5,  6,  7,
     8,  9, 10, 11,
    12, 13, 14, 15,
    16, 17, 18, 19,
    20, 21, 22, 23
};
static unsigned int cubeIndexCount = sizeof(cubeIndices)/sizeof(cubeIndices[0]);


#pragma region RenderStrategySimple
RenderStrategySimple::RenderStrategySimple(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{

}

RenderStrategySimple::~RenderStrategySimple(){

}

void RenderStrategySimple::preRender(Camera *pCamera){
    RenderStrategy::preRender(pCamera);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glVertexPointer(3, GL_FLOAT, 0, cubeVertices);
    glTexCoordPointer(2, GL_FLOAT, 0, cubeTextCoords);

}
void RenderStrategySimple::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
}
void RenderStrategySimple::renderBlock(Block *pBlock){
    matrix4 blockOrigin;
    vec3i blockPos = pBlock->getPosition();

    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile &t = pBlock->getTile(vec3i(x,y,z));
        if(!t.isSeen() || t.type == ETT_AIR){
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

        glDrawElements(GL_QUADS, sizeof(cubeIndices)/(sizeof(cubeIndices[0])), GL_UNSIGNED_BYTE, cubeIndices);
    }
    }
    }
}

#pragma endregion

#pragma region RenderStrategyVBO
RenderStrategyVBO::RenderStrategyVBO(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{
    gen(2, cubeVBO);

    bind(GL_ARRAY_BUFFER_ARB, cubeVBO[0]);
    bufferdata(GL_ARRAY_BUFFER_ARB, sizeof(cubeVertices)+sizeof(cubeTextCoords), 0, GL_STATIC_DRAW_ARB);
    buffersubdata(GL_ARRAY_BUFFER_ARB, 0, sizeof(cubeVertices), cubeVertices);
    buffersubdata(GL_ARRAY_BUFFER_ARB, sizeof(cubeVertices), sizeof(cubeTextCoords), cubeTextCoords);

    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, cubeVBO[1]);
    bufferdata(GL_ELEMENT_ARRAY_BUFFER_ARB, sizeof(cubeIndices), cubeIndices, GL_STATIC_DRAW_ARB);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
    
}

RenderStrategyVBO::~RenderStrategyVBO(){
    del(2, cubeVBO);
}


void RenderStrategyVBO::preRender(Camera *pCamera){
    RenderStrategy::preRender(pCamera);
    bind(GL_ARRAY_BUFFER_ARB, cubeVBO[0]);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, cubeVBO[1]);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glVertexPointer(3, GL_FLOAT, 0, 0);
    glTexCoordPointer(2, GL_FLOAT, 0, (void*)sizeof(cubeVertices));
}
void RenderStrategyVBO::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
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
        if(!t.isSeen() || t.type == ETT_AIR){
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

        glDrawElements(GL_QUADS, sizeof(cubeIndices)/(sizeof(cubeIndices[0])), GL_UNSIGNED_BYTE, 0);
    }
    }
    }
}

#pragma endregion


////////////////////////////   RenderStrategyVBOPerBlock //////////////////
#pragma region RenderStrategyVBOPerBlock
RenderStrategyVBOPerBlock::RenderStrategyVBOPerBlock(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{    
    m_pVertices = new float[sizeof(cubeVertices)*TILES_PER_BLOCK];
    m_pTexCoords= new float[sizeof(cubeTextCoords)*TILES_PER_BLOCK];
    m_pIndices  = new u16[sizeof(cubeIndices)*TILES_PER_BLOCK];
}

RenderStrategyVBOPerBlock::~RenderStrategyVBOPerBlock(){
    delete [] m_pVertices;
    delete [] m_pTexCoords;
    delete [] m_pIndices;
}


void RenderStrategyVBOPerBlock::preRender(Camera *pCamera){
    RenderStrategy::preRender(pCamera);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
}
void RenderStrategyVBOPerBlock::postRender(){
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    bind(GL_ARRAY_BUFFER_ARB, 0);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
}
unsigned short RenderStrategyVBOPerBlock::uploadBlock(Block *pBlock){

    vec3f *vertPtr = (vec3f*)m_pVertices;
    float *texCoordPtr = m_pTexCoords;
    unsigned short *indPtr = m_pIndices;
    unsigned short idx = 0;
    unsigned short cnt=0;
    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile t = pBlock->getTile(vec3i(x, y, z));
        if(t.isSeen() && t.type != ETT_AIR){
            for(u32 i=0;i<cubeVertexCount;i++){
                vertPtr->set(cubeVertices[i*3+0]+x, cubeVertices[i*3+1]+y, cubeVertices[i*3+2]+z);
                vertPtr++;
            }
            for(u32 i=0;i<cubeTexCoordElementCount;i++){
                *texCoordPtr = cubeTextCoords[i];
                texCoordPtr++;
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

    m_vertSize = sizeof(cubeVertices)*cnt;
    m_vertOffset = 0;
    m_texSize  = sizeof(cubeTextCoords)*cnt;
    m_texOffset = m_vertOffset + m_vertSize;
    m_indSize  = idx*sizeof(m_pIndices[0]); //sizeof(cubeIndices)*cnt <-- not that because cubeIndices is made of unsigned chars

    bufferdata(GL_ARRAY_BUFFER_ARB, m_vertSize+m_texSize, 0, GL_STATIC_DRAW_ARB);
    buffersubdata(GL_ARRAY_BUFFER_ARB, m_vertOffset, m_vertSize, m_pVertices);
    buffersubdata(GL_ARRAY_BUFFER_ARB, m_texOffset, m_texSize, m_pVertices);
    bufferdata(GL_ELEMENT_ARRAY_BUFFER_ARB, m_indSize, m_pIndices, GL_STATIC_DRAW_ARB);

    int bufferSize;
    getbufparam(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    ASSERT(bufferSize == m_vertSize+m_texSize);
    getbufparam(GL_ELEMENT_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    ASSERT(bufferSize == m_indSize);
    //printf("%d\n%d\n", dataSize, indexSize);
    static int ccc=0;
    ccc++;
    static int sum = 0;
    sum += m_vertSize + m_texSize + m_indSize;
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
    glVertexPointer(3, GL_FLOAT, 0, (void*)m_vertOffset);
    glTexCoordPointer(3, GL_FLOAT, 0, (void*)m_texOffset);
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
    glDrawElements(GL_QUADS, idxCnt, GL_UNSIGNED_SHORT, 0);
}

#pragma endregion

////////////////////////////   RenderStrategyVBOPerBlockSharedCubes //////////////////

#pragma region RenderStrategyVBOPerBlockSharedCubes
RenderStrategyVBOPerBlockSharedCubes::RenderStrategyVBOPerBlockSharedCubes(IVideoDriver *pDriver)
    : RenderStrategy(pDriver)
{    
    m_fullProgram = makeProgram(
        "shaders/RS_VBO_PerBlockSharedCubes.vert",
        "shaders/RS_VBO_PerBlockSharedCubes.frag"
        );    

    m_loc_MVP =     getuniformlocation(m_fullProgram, "MVP");
    m_loc_textureAtlas = getuniformlocation(m_fullProgram, "textureAtlas");
    m_loc_blockPosition = getuniformlocation(m_fullProgram, "blockPos");
    m_loc_vertex =  getattriblocation(m_fullProgram, "in_vertex");
    m_loc_tex =     getattriblocation(m_fullProgram, "in_texcoord");

    m_loc_blockSeen = getuniformlocation(m_fullProgram, "derp");

    m_pIndices  = new u16[sizeof(cubeIndices)*TILES_PER_BLOCK];

    float *vertices = new float[cubeVertexCount*3*TILES_PER_BLOCK];
    float *texcoords= new float[cubeTexCoordElementCount*TILES_PER_BLOCK];
    float *texPtr = texcoords;
    vec3f *vertPtr = (vec3f*)vertices;
    unsigned short cnt=0;
    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        for(u32 i=0;i<cubeVertexCount;i++){
            vertPtr->set(cubeVertices[i*3+0]+x, cubeVertices[i*3+1]+y, cubeVertices[i*3+2]+z);
            vertPtr++;
        }
        for(u32 i=0;i<cubeTexCoordElementCount;i++){
            *texPtr = cubeTextCoords[i];
            texPtr++;
        }
    }
    }
    }

    m_vertOffset = 0;
    m_vertSize = sizeof(cubeVertices)*TILES_PER_BLOCK;
    m_texOffset = m_vertSize;
    m_texSize = sizeof(cubeTextCoords)*TILES_PER_BLOCK;

    gen(1, &m_cubesVBO);
    bind(GL_ARRAY_BUFFER_ARB, m_cubesVBO);
    bufferdata(GL_ARRAY_BUFFER_ARB, m_vertSize+m_texSize, 0, GL_STATIC_DRAW_ARB);
    buffersubdata(GL_ARRAY_BUFFER_ARB, m_vertOffset, m_vertSize, vertices);
    buffersubdata(GL_ARRAY_BUFFER_ARB, m_texOffset, m_texSize, texcoords);

    int bufferSize;
    getbufparam(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    assert(bufferSize == m_vertSize + m_texSize);

    delete [] texcoords;
    delete [] vertices;
}

RenderStrategyVBOPerBlockSharedCubes::~RenderStrategyVBOPerBlockSharedCubes(){
    delete [] m_pIndices;
}


void RenderStrategyVBOPerBlockSharedCubes::preRender(Camera *pCamera){
    //RenderStrategy::preRender(pCamera);  <-- No U :D
    bind(GL_ARRAY_BUFFER_ARB, m_cubesVBO);

    vertexattribpointer(m_loc_vertex, 3, GL_FLOAT, GL_FALSE, 0, (void*)m_vertOffset);
    vertexattribpointer(m_loc_tex, 2, GL_FLOAT, 0, 0, (void*)m_texOffset);
    enablevertexattribarray(m_loc_vertex);
    enablevertexattribarray(m_loc_tex);

    useprogram(m_fullProgram);
    uniform1i(m_loc_textureAtlas, 0);
    matrix4 proj;
    matrix4 view;
    matrix4 projView;
    pCamera->getProjectionMatrix(proj);
    pCamera->getViewMatrix(view);
    projView = proj*view;
    uniformmatrix4fv(m_loc_MVP, 1, GL_FALSE, projView.pointer());
}

void RenderStrategyVBOPerBlockSharedCubes::postRender(){
    bind(GL_ARRAY_BUFFER_ARB, 0);
    bind(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
    useprogram(0);
}
unsigned short RenderStrategyVBOPerBlockSharedCubes::uploadBlock(Block *pBlock){
    unsigned short *indPtr = m_pIndices;
    unsigned short idx = 0;
    unsigned short cnt=0;
    for(int x=0;x<BLOCK_SIZE_X;x++){
    for(int y=0;y<BLOCK_SIZE_Y;y++){
    for(int z=0;z<BLOCK_SIZE_Z;z++){
        const Tile t = pBlock->getTile(vec3i(x, y, z));
        if(t.isSeen() && t.type != ETT_AIR){
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

    int indSize = idx*sizeof(m_pIndices[0]); //sizeof(cubeIndices)*cnt;
    bufferdata(GL_ELEMENT_ARRAY_BUFFER_ARB, indSize, m_pIndices, GL_STATIC_DRAW_ARB);

    static int ccc=0;
    ccc++;
    //printf("%d\n", ccc);

    int bufferSize;
    getbufparam(GL_ELEMENT_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);
    assert(bufferSize == indSize);

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

    vec3i blockPos = pBlock->getPosition();
    //m_pDriver->setTransform(ETS_WORLD, blockOrigin);
    uniform3iv(m_loc_blockPosition, 1, &blockPos.X);
    int isSeen = pBlock->isSeen() ? 1 : 0;
    uniform1i(m_loc_blockSeen, isSeen);
    glDrawElements(GL_QUADS, idxCnt, GL_UNSIGNED_SHORT, 0);
}

#pragma endregion


