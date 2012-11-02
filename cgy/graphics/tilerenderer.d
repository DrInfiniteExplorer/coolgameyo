

module graphics.tilerenderer;

import std.conv;
import std.math;

import graphics.camera;
import graphics.ogl;
import graphics.shader;
import graphics.tilegeometry;

import util.pos;
import statistics;
import util.rangefromto;
import util.util;
import worldstate.sizes;


class TileRenderer {

    class Mutex {};

    struct RenderInfo {
        uint vbo = 0;
        uint quadCount = 0;
    }
    alias ShaderProgram!("offset", "VP", "atlas", "SkyColor") TileProgram;

    private TileProgram tileProgram;
    private RenderInfo[GraphRegionNum] vertexBuffers;

    private GraphRegionNum[] toRemove;
    private TileFaces[GraphRegionNum] toUpload;
    private Mutex toRemoveMutex;
    private Mutex toUploadMutex;

    private double minReUseRatio = 0.95;

    this() {
        toRemoveMutex = new Mutex;
        toUploadMutex = new Mutex;
    }

    void init() {
        tileProgram = new TileProgram("shaders/renderGR.vert", "shaders/renderGR.frag");
        tileProgram.bindAttribLocation(0, "position");
        tileProgram.bindAttribLocation(1, "texcoord");
        tileProgram.bindAttribLocation(2, "light");
        tileProgram.bindAttribLocation(3, "sunLight");
        tileProgram.bindAttribLocation(4, "normal");
        tileProgram.link();
        tileProgram.offset      = tileProgram.getUniformLocation("offset");
        tileProgram.VP          = tileProgram.getUniformLocation("VP");
        tileProgram.atlas       = tileProgram.getUniformLocation("atlas");
        tileProgram.SkyColor    = tileProgram.getUniformLocation("SkyColor");
        tileProgram.use();
        tileProgram.setUniform(tileProgram.atlas, 0); //Texture atlas will always reside in texture unit 0 yeaaaah

    }

    bool destroyed = false;
    void destroy() {

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        foreach(renderInfo ; vertexBuffers) {
            glDeleteBuffers(1, &renderInfo.vbo);
        }


        destroyed = true;
    }

    ~this() {
        BREAK_IF(!destroyed);
    }


    void updateGeometry(GraphRegionNum grNum, TileFaces geometry) {
        synchronized(toUploadMutex) {
            toUpload[grNum] = geometry;
        }
    }

    void removeSector(SectorNum sectorNum) {

        GraphRegionNum[] remove;
        auto min = sectorNum.toTilePos().getGraphRegionNum().value;
        auto max = TilePos(SectorNum(sectorNum.value+vec3i(1,1,1)).toTilePos().value-vec3i(1,1,1)).getGraphRegionNum().value;

        foreach(pos ; RangeFromTo(min, max)) {
            remove ~= GraphRegionNum(pos);
        }

        if(remove.length) {
            synchronized(toRemoveMutex) {
                toRemove ~= remove;
                remove = null;
            }
        }

        msg("Implement removeSector");
    }

    RenderInfo doUpload(RenderInfo *oldInfo, TileFaces geometry) {
        RenderInfo info;

        auto primitiveCount = geometry.faces.length;
        auto geometrySize = primitiveCount * GRFace.sizeof;
        info.quadCount = primitiveCount;
        scope(exit) geometry.clear();

        if(oldInfo !is null && oldInfo.vbo){
            //See if VBO is reusable.
            int bufferSize;
            glBindBuffer(GL_ARRAY_BUFFER, oldInfo.vbo);
            glGetBufferParameteriv(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);

            double ratio = to!double(geometrySize)/to!double(bufferSize);
            if(minReUseRatio <= ratio && ratio <= 1){
                glBufferSubData(GL_ARRAY_BUFFER, 0, geometrySize, geometry.faces.ptr);
                info.vbo = oldInfo.vbo;
                return info;
            }else{
                //Delete old vbo
                glBindBuffer(GL_ARRAY_BUFFER, 0);
                glDeleteBuffers(1, &oldInfo.vbo);
            }
        }
        if(geometrySize > 0){
            glGenBuffers(1, &info.vbo);
            glBindBuffer(GL_ARRAY_BUFFER, info.vbo);
            glBufferData(GL_ARRAY_BUFFER, geometrySize, geometry.faces.ptr, GL_STATIC_DRAW);
        } else {
            //msg("GOT NOTHING FROM GRAPHREGION! >:( ", region.grNum);
            //addAABB(region.grNum.getAABB());
        }
        return info;
    }

    void uploadGeometry() {
        //Check this before locking, dont need exactly-on-creation-frame-speed.
        if(toUpload.length > 0) {
            //Lock toUpload &scope exit
            synchronized(toUploadMutex) {
                foreach(grNum, geometry ; toUpload) {
                    RenderInfo *oldInfo = grNum in vertexBuffers;
                    RenderInfo newInfo = doUpload(oldInfo, geometry);
                    if(oldInfo !is null && newInfo.vbo == 0) {
                        vertexBuffers.remove(grNum);
                    } else if(newInfo.vbo != 0){
                        vertexBuffers[grNum] = newInfo; 
                    }
                }
                toUpload.clear();
            }
        }

        if(toRemove.length > 0) {
            //Lock & scopeexit
            synchronized(toRemoveMutex) {
                foreach(grNum ; toRemove) {
                    RenderInfo *renderInfo = grNum in vertexBuffers;
                    if(renderInfo is null) continue;
                    glBindBuffer(GL_ARRAY_BUFFER, 0);
                    glDeleteBuffers(1, &renderInfo.vbo);
                    vertexBuffers.remove(grNum);
                }
                toRemove = null;
            }
        }

    }

    void render(Camera camera, vec3f skyColor) {
        uploadGeometry();

        tileProgram.use();
        glEnableVertexAttribArray(0); glError();
        glEnableVertexAttribArray(1); glError();
        glEnableVertexAttribArray(2); glError();
        glEnableVertexAttribArray(3); glError();
        glEnableVertexAttribArray(4); glError();

        auto transform = camera.getProjectionMatrix() * camera.getTargetMatrix();
        tileProgram.setUniform(tileProgram.VP, transform);
        tileProgram.setUniform(tileProgram.SkyColor, skyColor);

        auto camPos = camera.getPosition();

        foreach(grNum, renderInfo ; vertexBuffers){
            if(camera.inFrustum(grNum.getAABB())){

                //TODO: Do the pos-camerapos before converting to float, etc
                auto dPos = grNum.min().value.convert!double();
                auto fPos = (dPos - camPos).convert!float();
                tileProgram.setUniform(tileProgram.offset, fPos);

                glBindBuffer(GL_ARRAY_BUFFER, renderInfo.vbo); glError();
                glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, GRVertex.sizeof, null /* offset in vbo */); glError();
                glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)GRVertex().texcoord.offsetof); glError();
                glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)GRVertex().lightValue.offsetof); glError();
                glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)GRVertex().sunLightValue.offsetof); glError();
                glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, GRVertex.sizeof, cast(void*)GRVertex().normal.offsetof); glError();
                glDrawArrays(GL_QUADS, 0, renderInfo.quadCount*4); glError();
                triCount += renderInfo.quadCount*2;
            }
        }
        //Get list of vbo's
        //Do culling    
        //Render vbo's.
        glDisableVertexAttribArray(0); glError();
        glDisableVertexAttribArray(1); glError();
        glDisableVertexAttribArray(2); glError();
        glDisableVertexAttribArray(3); glError();
        glDisableVertexAttribArray(4); glError();
        tileProgram.use(false);
    }



}



