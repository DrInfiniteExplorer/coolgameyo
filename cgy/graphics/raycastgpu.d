
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

enum MaxLightTraceDistance = 100f;
enum FadeLightTraceDistance = 90f;   //Start fading lightstrength at this distance,
//so it is 0 at MaxLightTraceDistance

struct CLCamera {
    float[4] position;
    float[4] upperLeft;
    float[4] toRight;
    float[4] toDown;
    int width;
    int height;
    int windowWidth;
    int windowHeight;
};

struct CLLight {
    float[4] position;
    float strength;
    float[3] color;
};

static assert(CLLight.sizeof == 32, "Error, will not match opencl size!");

__gshared CLProgram g_traceRaysProgram;
__gshared CLKernel g_kernel;
__gshared CLBuffer g_cameraBuffer;
__gshared CLImage3D g_tileBuffer;



void initInteractiveComputeYourFather(){
    reloadOpenCl();
    g_cameraBuffer = CLBuffer(g_clContext, CL_MEM_READ_ONLY, CLCamera.sizeof, null);

    auto format = cl_image_format(CL_R, CL_UNSIGNED_INT32);
    g_tileBuffer = CLImage3D(g_clContext,
            CL_MEM_READ_ONLY,
            format,
            SolidMap.sizeX*3, SolidMap.sizeY*3, SolidMap.sizeZ*3, //*3*3*3
            0, 0,
            null
            );
    startTime = Clock.currTime();
}



void deinitInteractiveComputeYourFather(){
}

void reloadOpenCl() {
    auto content = readText("opencl/yourfather.cl");

    string defines = "";
    defines ~= " -D MaxLightTraceDistance=" ~ to!string(MaxLightTraceDistance) ~ ".0f";
    defines ~= " -D FadeLightTraceDistance=" ~ to!string(FadeLightTraceDistance) ~ ".0f";

    defines ~= " -D RayCastPixelSkip="~to!string(renderSettings.raycastPixelSkip);
    writeln(defines);


    static assert(SolidMap.sizeX == 4);
    static assert(SolidMap.sizeY == 128);
    static assert(SolidMap.sizeZ == 2*32);

    g_traceRaysProgram = g_clContext.createProgram(content);

    try{
        g_traceRaysProgram.build("-w -Werror " ~ defines);
    }catch(Throwable t){}

    string errors = g_traceRaysProgram.buildLog(g_clContext.devices[0]);
    writeln(errors);
    if(errors.length > 2) {
        writeln(content[0 .. 256]);
        MessageBox(null, toStringz("!"~errors~"!?!"), "", 0);
    }
    g_kernel = CLKernel(g_traceRaysProgram, "castRays");
}

static SectorNum[3][3][3] oldSectorNum;
void uploadTileData(World world, Camera camera) {
    SectorNum startNum = UnitPos(camera.getPosition).getSectorNum();
    foreach(num ; RangeFromTo(startNum.value - vec3i(1,1,1), startNum.value + vec3i(1,1,1))){
        SectorNum sectorNum = SectorNum(num);
        SolidMap* tileMap = world.getSolidMap(sectorNum.toTilePos());
        if(tileMap is null) {
            continue;
        }
        bool dirty = tileMap.dirty;

        vec3i rel = vec3i(
                posMod(num.X, 3),
                posMod(num.Y, 3),
                posMod(num.Z, 3)
                );

        bool sameSector = oldSectorNum
            [rel.X]
            [rel.Y]
            [rel.Z] == sectorNum;
        if(!dirty && sameSector) { //If not dirty and same sector
            continue;
        }
        writeln("Uploading sector data! ", to!string(sectorNum));
        tileMap.dirty = false;
        oldSectorNum
            [rel.X]
            [rel.Y]
            [rel.Z] = sectorNum;

        rel *= vec3i(SolidMap.sizeX, SolidMap.sizeY, SolidMap.sizeZ);
        const size_t[3] origin = [rel.X,rel.Y,rel.Z];
        const size_t[3] region = [SolidMap.sizeX, SolidMap.sizeY, SolidMap.sizeZ];
        g_clCommandQueue.enqueueWriteImage(g_tileBuffer, CL_TRUE, origin, region, tileMap.data.ptr);
    }
}


SysTime startTime;

void interactiveComputeYourFather(World world, Camera camera) {
    Duration duration = Clock.currTime() - startTime;
    long currentTime = duration.total!"msecs"();



    vec3d upperLeft, toRight, toDown, dir, startPos;
    startPos = camera.getPosition();
    int width = renderSettings.windowWidth / renderSettings.raycastPixelSkip;
    int height = renderSettings.windowHeight / renderSettings.raycastPixelSkip;

    camera.getRayParameters(upperLeft, toRight, toDown);
    CLCamera clCamera;
    clCamera.position   = [startPos.X, startPos.Y, startPos.Z, 0];
    clCamera.upperLeft  = [upperLeft.X, upperLeft.Y, upperLeft.Z, 0];
    clCamera.toRight    = [toRight.X, toRight.Y, toRight.Z, 0];
    clCamera.toDown     = [toDown.X, toDown.Y, toDown.Z, 0];
    clCamera.width = width;
    clCamera.height= height;
    clCamera.windowWidth = renderSettings.windowWidth;
    clCamera.windowHeight= renderSettings.windowHeight;
    g_clCommandQueue.enqueueWriteBuffer(g_cameraBuffer, CL_TRUE, 0, clCamera.sizeof, &clCamera);


    LightSource[] lights;
    lights = world.getLightsInRadius(UnitPos(startPos), MaxLightTraceDistance);
    if(lights.length == 0) {
        return;
    }
    CLLight[] clLight;
    clLight.length = lights.length;
    for (int i = 0; i < lights.length; i++) {
        long currentTimePosition = currentTime+ cast(long)((lights[i].position.value.X + lights[i].position.value.Y)*1000);

        clLight[i].position = [
            lights[i].position.value.X + 0.05f * sin(currentTimePosition/300f)^^3,
            lights[i].position.value.Y + 0.05f * cos(currentTimePosition/500f)^^3,
            lights[i].position.value.Z + 0.05f * sin(currentTimePosition/700f)^^3, 0];
        
        float asdf = sin(cast(float)(currentTimePosition)/400f);
        float fdsa = sin(cast(float)(currentTimePosition)/100f);
        float flickerRatio =
                        ((abs(asdf) * 0.4f + 0.6f) +
                         (abs(fdsa) * 0.2f + 0.8f)) / 2f;
        
        float dist = lights[i].position.value.getDistanceFrom(startPos);
        if(dist > FadeLightTraceDistance) {
            float range = (MaxLightTraceDistance - FadeLightTraceDistance);
            float fadeRatio = 1f - (dist - FadeLightTraceDistance) / range;
            clLight[i].strength = (cast(float)lights[i].strength) * fadeRatio * flickerRatio;
        } else {
            clLight[i].strength = lights[i].strength * flickerRatio;
        }
        clLight[i].color[0] = lights[i].tint.X / 255f;
        clLight[i].color[1] = lights[i].tint.Y / 255f;
        clLight[i].color[2] = lights[i].tint.Z / 255f;
    }

    uploadTileData(world, camera);

    //Need to create often. Not really, could reuse and make code to recognize and such!
    int cnt = clLight.length;
    static assert(cnt.sizeof == 4);
    auto lightBuffer = CLBuffer(g_clContext, CL_MEM_READ_ONLY, clLight.length * clLight[0].sizeof + 4, null);
    g_clCommandQueue.enqueueWriteBuffer(lightBuffer, CL_TRUE, 0, cnt.sizeof, &cnt);
    g_clCommandQueue.enqueueWriteBuffer(lightBuffer, CL_TRUE, 4, clLight.length * clLight[0].sizeof, clLight.ptr);
 
    g_kernel.setArgs(g_cameraBuffer, lightBuffer, g_tileBuffer, g_clDepthBuffer, g_clRayCastOutput);

/*
    writeln("g_kernel" ~ to!string(g_kernel));
    writeln("g_cameraBuffer" ~ to!string(g_cameraBuffer));
    writeln("lightBuffer" ~ to!string(lightBuffer));
    writeln("g_tileBuffer" ~ to!string(g_tileBuffer));
    writeln("g_clDepthBuffer" ~ to!string(g_clDepthBuffer ));
    writeln("g_clRayCastOutput" ~ to!string(g_clRayCastOutput));
    The reference count for depthbuffer & output never decreases.
*/


    auto range	= NDRange(width, height); 

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




