module graphics.tilecompute;

import cgy.math.vector;
import graphics.camera;
import graphics.ogl;
import graphics.tilerenderer;
import graphics.tilegeometry; // OR NOT? IM NOT SURE?
import graphics.shader;

import cgy.util.util;
import worldstate.worldstate;


class TileCompute : WorldStateListener {

    WorldState worldState;

    ShaderProgram!() scanCompute;

    RenderInfo[GraphRegionNum] regions;
    bool dirty = false;



    this(WorldState _worldState) {
        worldState = _worldState;

        scanCompute = new ShaderProgram!();
        scanCompute.compileCompute(scanComputeShader);
        scanCompute.link();
        scanCompute.use();

    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        scanCompute.destroy();
        destroyed = true;
    }


    static immutable string scanComputeShader = q{
        #version 430
        layout(local_size_x = 16 , local_size_y = 16, local_size_z = 1) in;

        layout(binding=0, r32f) readonly uniform image2D height;
        layout(binding=1, r32f) readonly uniform image2D water;
        layout(binding=2, r32f) uniform image2D distance;
        layout(binding=3, r32f) uniform image2D road;

        uniform ivec3 range;

        struct Tile {
            unsigned short type;
            unsigned short flags;
            unsigned char hitpoints;
            unsigned char derppoints;
            unsigned char lightValues;
            unsigned char otherThings;
        };

        layout(std140, binding=0) buffer tileBuffer {
            struct Tile tiles[];
        };
        layout(std140, binding=1) buffer scanBuffer {
            unsigned char scanValues[];
        };

        void main() {
            int myIdx = gl_GlobalInvocationID.x;
            int myX = myIdx % range.y;
            int tmp = myIdx / range.y;
            int myY = tmp % range.z;
            int myZ = tmp / range.z;



        }
    };


    void createGeometry(GraphRegionNum grNum) {

        auto tileStart = (grNum.toTilePos.value-vec3i(1)).TilePos;
        auto tileEnd = (tileStart.value + vec3i(GraphRegionSize.x+2, GraphRegionSize.y+2, GraphRegionSize.z+2)).TilePos;
        auto tileRange = (tileEnd.value - tileStart.value);

        auto tiles = worldState.getTiles(tileStart, tileEnd);
        scope(exit) delete tiles;

        uint tileBufferSize = cast(uint)(tiles.length * tiles[0].sizeof);
        uint tileBuffer = CreateBuffer(BufferType.ShaderStorage, tileBufferSize, tiles.ptr, GL_STATIC_DRAW);
        scope(exit) ReleaseBuffer(tileBuffer);

        uint scanBufferSize = char.sizeof * cast(uint)tiles.length;
        uint scanBuffer = CreateBuffer(BufferType.ShaderStorage, scanBufferSize, null, GL_STATIC_DRAW);
        scope(exit) ReleaseBuffer(scanBuffer);

        scanCompute.use();
        scanCompute.uniform.range = tileRange - vec3i(2);

        //glBindImageTexture(0, water, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, tileBuffer, 0, tileBufferSize);
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 1, scanBuffer, 0, scanBufferSize);
        glDispatchCompute(1, 1, 1); glError();
        glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
        scanCompute.use(false);

        
        
        // Use solidmap(s?) to determine where is solid, output scan array
        // analyze scan array; make index array and allocate buffer
        // Fill the buffer
        // Done
    }

    void updateGeometry() {
        if(!dirty) return;
    }

    void render(Camera camera, vec3f skyColor) {
        updateGeometry();


    }

    void onAddUnit(SectorNum, Unit) { }
    void onAddEntity(SectorNum, Entity) { }

    // Only called when lighting conditions have changed, for now.
    override void onUpdateGeometry(TilePos tilePos) {
    }

    // Only called after onLoadSector, when a sector is loaded in loadSector
    override void onBuildGeometry(SectorNum sectorNum) {
    }

    // When a tile has been changed
    override void onTileChange(TilePos tilePos) {
        onUpdateGeometry(tilePos);
    }
    // When a sector has been loaded, or when it has been filled with tiles.
    override void onSectorLoad(SectorNum sectorNum) {
        onBuildGeometry(sectorNum);
    }
    void onSectorUnload(SectorNum sectorNum) {
    }

}

