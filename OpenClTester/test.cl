#pragma OPENCL EXTENSION cl_khr_fp64 : enable

typedef double4 vec4d;
typedef float4 vec4f;

struct Camera {
    vec4d position;
    vec4d upperLeft;
    vec4d toRight;
    vec4d toDown;
    int width;
    int height;
};

__constant int4 sectorSize = (int4)(128, 128, 32, 1); //1 to prevent division with 0 :p
__constant int4 solidMapSize = (int4)(16, 128, 32, 1);

int4 getSectorRel(int4 tilePos) {
    const int4 b = sectorSize;
    return ((tilePos % b) + b) % b;
}

bool isSolid(int4 tilePos, __global const uchar* solidMap) {
    int4 rel = getSectorRel(tilePos);
    int x   = tilePos.x/8;
    int bit = tilePos.x%8;
    int y   = tilePos.y;
    int z   = tilePos.z;

    uchar byte = solidMap[x + solidMapSize.x * (y + solidMapSize.y * z)];
    return 0 != (byte & (1<<bit));

}

__kernel void castRay(
    __constant struct Camera* camera,
    __global const uchar* solidMap,
    __global double* outMap
)
{asd
    int i = get_global_id(0);
    int x = i % camera->width;
    int y = i / camera->width;
    float percentX = x / camera->width;
    float percentY = y / camera->height;
    vec4d rayDir = camera->upperLeft + percentX * camera->toRight + percentY * camera->toDown;
    
}