
module graphics.raycastgpu;



import std.conv;
import std.exception;
import std.file;
import std.math;
import std.stdio;


import win32.windows;

import opencl.all;
pragma(lib, "cl4d.lib");
pragma(lib, "opencl.lib");

import graphics.camera;
import graphics.ogl;
import graphics.image;
import light;
import world.ambient;
import settings;
import statistics;
import util.math;
import util.rangefromto;
import util.util;
import world.world;

//enum TileMemoryLocation = "global";
//enum TileMemoryLocation = "constant";
enum TileMemoryLocation = "texture";

enum MaxLightTraceDistance = 100;

struct CLCamera {
    float[4] position;
    float[4] upperLeft;
    float[4] toRight;
    float[4] toDown;
    int width;
    int height;
};

struct CLLight {
    float[4] position;
    int[4] strength;
};

__gshared CLProgram g_traceRaysProgram;
__gshared CLKernel g_kernel;
__gshared CLBuffer g_cameraBuffer;
static if(TileMemoryLocation == "texture") {
    __gshared CLImage3D g_tileBuffer;
} else {
    __gshared CLBuffer g_tileBuffer;
}



void initInteractiveComputeYourFather(){
    auto content = readText("opencl/yourfather.cl");

    string defines = "";

    static if(TileMemoryLocation == "constant") {
        defines ~= " -D TileStorageLocation=__constant";
    } else static if (TileMemoryLocation == "global"){
        defines ~= " -D TileStorageLocation=__global";
    } else static if (TileMemoryLocation == "texture") {
        defines ~= " -D UseTexture";
    } else {
        static assert(0, "No u");
    }

    static assert(SolidMap.sizeY == 128);
    static assert(SolidMap.sizeZ == 32);
    static if(PackInInt) {
        static assert(SolidMap.sizeX == 4);
        defines ~= " -D TileStorageType=uint -D TileStorageBitCount=32 -D SolidMapSize=4,128,32";

    } else {
        static assert(SolidMap.sizeX == 16);
        defines ~= " -D TileStorageType=uchar -D TileStorageBitCount=8 -D SolidMapSize=16,128,32";
    }

    g_traceRaysProgram = g_clContext.createProgram(content);

    try{
        g_traceRaysProgram.build("-w -Werror " ~ defines);
    }catch(Throwable t){
    }

    string errors = g_traceRaysProgram.buildLog(g_clContext.devices[0]);
    writeln(errors);
    if(errors.length > 2) {
        MessageBox(null, toStringz("!"~errors~"!?!"), "", 0);
    }

    g_cameraBuffer = CLBuffer(g_clContext, CL_MEM_READ_ONLY, CLCamera.sizeof, null);

    g_kernel = CLKernel(g_traceRaysProgram, "castRays");

    static if(TileMemoryLocation == "texture") {
        static if(PackInInt) {
            auto format = cl_image_format(CL_R, CL_UNSIGNED_INT32);
        } else {
            auto format = cl_image_format(CL_R, CL_UNSIGNED_INT8);
        }
        g_tileBuffer = CLImage3D(g_clContext,
                                    CL_MEM_READ_ONLY,
                                    format,
                                    SolidMap.sizeX*3, SolidMap.sizeY*3, SolidMap.sizeZ*3, //*3*3*3
                                    0, 0,
                                    null
                                    );
    } else {
        g_tileBuffer = CLBuffer(g_clContext, CL_MEM_READ_ONLY, SolidMap.sizeof*27, null);
    }
}



void deinitInteractiveComputeYourFather(){
}

void reloadOpenCl() {
    auto content = readText("opencl/yourfather.cl");

    string defines = "";

    static if(TileMemoryLocation == "constant") {
        defines ~= " -D TileStorageLocation=__constant";
    } else static if (TileMemoryLocation == "global"){
        defines ~= " -D TileStorageLocation=__global";
    } else static if (TileMemoryLocation == "texture") {
        defines ~= " -D UseTexture";
    } else {
        static assert(0, "No u");
    }

    static assert(SolidMap.sizeY == 128);
    static assert(SolidMap.sizeZ == 32);
    static if(PackInInt) {
        static assert(SolidMap.sizeX == 4);
        defines ~= " -D TileStorageType=uint -D TileStorageBitCount=32 -D SolidMapSize=4,128,32";

    } else {
        static assert(SolidMap.sizeX == 16);
        defines ~= " -D TileStorageType=uchar -D TileStorageBitCount=8 -D SolidMapSize=16,128,32";
    }

    g_traceRaysProgram = g_clContext.createProgram(content);

    try{
        g_traceRaysProgram.build("-w -Werror " ~ defines);
    }catch(Throwable t){}

    string errors = g_traceRaysProgram.buildLog(g_clContext.devices[0]);
    writeln(errors);
    if(errors.length > 2) {
        MessageBox(null, toStringz("!"~errors~"!?!"), "", 0);
    }
    g_kernel = CLKernel(g_traceRaysProgram, "castRays");
}


void uploadTileData(World world, Camera camera) {
    auto sectorNum = UnitPos(camera.getPosition).getSectorNum();
    foreach(num ; RangeFromTo(sectorNum.value - vec3i(1,1,1), sectorNum.value + vec3i(1,1,1))){
        SolidMap* tileMap = world.getSolidMap(SectorNum(num).toTilePos());
        if(tileMap is null) {
            continue;
        }
        vec3i rel = vec3i(
                          posMod(num.X, 3),
                          posMod(num.Y, 3),
                          posMod(num.Z, 3)
                          );        
        static if(TileMemoryLocation == "texture") {
            rel *= vec3i(SolidMap.sizeX, SolidMap.sizeY, SolidMap.sizeZ);
            const size_t[3] origin = [rel.X,rel.Y,rel.Z];
            const size_t[3] region = [SolidMap.sizeX, SolidMap.sizeY, SolidMap.sizeZ];
            g_clCommandQueue.enqueueWriteImage(g_tileBuffer, CL_TRUE, origin, region, tileMap.data.ptr);
        } else {
            int idx = rel.X + 3*rel.Y + 9*rel.Z;
            g_clCommandQueue.enqueueWriteBuffer(g_tileBuffer, CL_TRUE, idx*SolidMap.sizeof, tileMap.data.sizeof, tileMap.data.ptr);
        }
    }
}


void interactiveComputeYourFather(World world, Camera camera) {
    vec3d upperLeft, toRight, toDown, dir, startPos;
    startPos = camera.getPosition();
    camera.getRayParameters(upperLeft, toRight, toDown);
    CLCamera clCamera;
    clCamera.position   = [startPos.X, startPos.Y, startPos.Z, 0];
    clCamera.upperLeft  = [upperLeft.X, upperLeft.Y, upperLeft.Z, 0];
    clCamera.toRight    = [toRight.X, toRight.Y, toRight.Z, 0];
    clCamera.toDown     = [toDown.X, toDown.Y, toDown.Z, 0];
    clCamera.width = renderSettings.windowWidth;
    clCamera.height= renderSettings.windowHeight;
    g_clCommandQueue.enqueueWriteBuffer(g_cameraBuffer, CL_TRUE, 0, clCamera.sizeof, &clCamera);


    LightSource[] lights;

    //World.LightPropagationData[] lights;
    lights = world.getLightsInRadius(UnitPos(startPos), MaxLightTraceDistance);
//    world.getLightsWithin(TilePos(vec3i(-100, -100, -100)), TilePos(vec3i(100, 100, 100)), lights);
    if(lights.length == 0) {
        return;
    }
    CLLight[] clLight;
    clLight.length = lights.length;
    for (int i = 0; i < lights.length; i++) {
        clLight[i].position = [
            lights[i].position.value.X,
            lights[i].position.value.Y,
            lights[i].position.value.Z, 0];
        clLight[i].strength = lights[i].strength;
    }

    uploadTileData(world, camera);

    //Need to create often. Not really, could reuse and make code to recognize and such!
    auto lightBuffer = CLBuffer(g_clContext, CL_MEM_READ_ONLY, clLight.length * clLight[0].sizeof + int.sizeof, null);
    int cnt = clLight.length;
    g_clCommandQueue.enqueueWriteBuffer(lightBuffer, CL_TRUE, 0, cnt.sizeof, &cnt);
    g_clCommandQueue.enqueueWriteBuffer(lightBuffer, CL_TRUE, cnt.sizeof, clLight.length * clLight[0].sizeof, clLight.ptr);

    g_kernel.setArgs(g_cameraBuffer, lightBuffer, g_tileBuffer, g_clDepthBuffer, g_clResultTexture);

    auto range	= NDRange(renderSettings.windowWidth, renderSettings.windowHeight);

	glFinish();
	g_clCommandQueue.enqueueAcquireGLObjects(g_clRayCastMemories);
    {
        //mixin(Time!("writeln(\"Takes time: \", usecs/1000);"));
        CLEvent execEvent = g_clCommandQueue.enqueueNDRangeKernel(g_kernel, range);
        g_clCommandQueue.flush();
        // wait for the kernel to be executed
        execEvent.wait();
    }
	g_clCommandQueue.enqueueReleaseGLObjects(g_clRayCastMemories);
	g_clCommandQueue.finish();


}




