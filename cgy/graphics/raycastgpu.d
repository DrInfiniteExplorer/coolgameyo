
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
import graphics.image;
import light;
import settings;
import statistics;
import util.util;
import world.world;


CLContext       clContext;
CLCommandQueue clCommandQueue;

CLProgram traceRaysProgram;

//enum TileMemoryLocation = "global";
enum TileMemoryLocation = "constant";
//enum TileMemoryLocation = "texture";

static bool inited = false;
void initOpenCL() {
    inited = true; //And now just disregard initedness...
	auto platforms = CLHost.getPlatforms();
	auto platform = platforms[0];
	auto devices = platform.allDevices;
	clContext = CLContext(devices);
    clCommandQueue = CLCommandQueue(clContext, devices[0]);

    auto content = readText("opencl/yourfather.cl");

    string defines = "";

    static if(TileMemoryLocation == "constant") {
        defines ~= " -D TileStorageLocation=__constant";
    } else static if (TileMemoryLocation == "global"){
        defines ~= " -D TileStorageLocation=__global";
    } else static if (TileMemoryLocation == "texture") {
        defines ~= " -D UseTexture";
    } else {
        derp=2;
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

    traceRaysProgram = clContext.createProgram(
        content
    );
    try{
        traceRaysProgram.build("-w -Werror " ~ defines);
    }catch(Throwable t){}
    string errors = traceRaysProgram.buildLog(devices[0]);
    writeln(errors);
    if(errors.length > 2) {
        MessageBox(null, toStringz("!"~errors~"!?!"), "", 0);
    }

}

struct CLCamera {
    float[4] position;
    float[4] upperLeft;
    float[4] toRight;
    float[4] toDown;
    int width;
    int height;
};

void computeYourFather(World world, Image img, Camera camera) {
    initOpenCL();

    vec3d upperLeft, toRight, toDown, dir, startPos;
    startPos = camera.getPosition();
    camera.getRayParameters(upperLeft, toRight, toDown);
    CLCamera clCamera;
    clCamera.position   = [startPos.X, startPos.Y, startPos.Z, 0];
    clCamera.upperLeft  = [upperLeft.X, upperLeft.Y, upperLeft.Z, 0];
    clCamera.toRight    = [toRight.X, toRight.Y, toRight.Z, 0];
    clCamera.toDown     = [toDown.X, toDown.Y, toDown.Z, 0];
    clCamera.width = img.imgWidth;
    clCamera.height= img.imgHeight;

    SolidMap tileMap = world.getSolidMap(UnitPos(camera.getPosition).tilePos);
    enforce(tileMap.hasContent(vec3i(0,0,0), vec3i(SectorSize.x-1, SectorSize.y-1, SectorSize.z-1)), "Derp");
    //tileMap.set(vec3i(1,1,1), false);

    static if(TileMemoryLocation == "texture") {
        static if(PackInInt) {
            auto format = cl_image_format(CL_R, CL_UNSIGNED_INT32);
        } else {
            auto format = cl_image_format(CL_R, CL_UNSIGNED_INT8);
        }
        auto tileBuffer = CLImage3D(clContext,
            CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
            format,
            tileMap.sizeX, tileMap.sizeY, tileMap.sizeZ,
            0, 0,
            tileMap.data.ptr
        );
    } else {
        auto tileBuffer = CLBuffer(clContext, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, tileMap.sizeof, tileMap.data.ptr);
    }

    auto constantBuffer = CLBuffer(clContext, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, clCamera.sizeof, &clCamera);
    writeln("derp, ", tileMap.sizeof);
    int imgSize = img.imgWidth * img.imgHeight * 4;
    auto outputBuffer = CLBuffer(clContext, CL_MEM_WRITE_ONLY, imgSize, null);

    auto kernel = CLKernel(traceRaysProgram, "castRays");
    //auto kernel = CLKernel(traceRaysProgram, "writeWhite");
    kernel.setArgs(constantBuffer, tileBuffer, outputBuffer);
    //kernel.setArgs(outputBuffer);

    // Run the kernel on specific ND range
    auto global	= NDRange(img.imgWidth, img.imgHeight);

    {
        mixin(Time!("writeln(\"Takes time: \", usecs/1000);"));
        foreach(x ; 0 .. 1)
        {
            CLEvent execEvent = clCommandQueue.enqueueNDRangeKernel(kernel, global);
            clCommandQueue.flush();
            // wait for the kernel to be executed
            execEvent.wait();
        }
    }

    clCommandQueue.enqueueReadBuffer(outputBuffer, CL_TRUE, 0, imgSize, img.imgData.ptr);

    //world.intersectTile
}




