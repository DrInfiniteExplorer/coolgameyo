


// TileStorageLocation passed as define from host
// TileStorageType passed as define from host
// SolidMapSize passed as define from host in format %d,%d,%d
// UsePackedData derp derp guess what???

//  #pragma OPENCL EXTENSION cl_khr_fp64 : enable
typedef float4 vec4f;

const sampler_t tileImageSampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_REPEAT | CLK_FILTER_NEAREST;

struct Camera {
    vec4f position;
    vec4f upperLeft;
    vec4f toRight;
    vec4f toDown;
    int width;
    int height;
};

__constant int4 sectorSize = (int4)(128, 128, 32, 1); //1 to prevent division with 0 :p
__constant int4 solidMapSize = (int4)(SolidMapSize, 1);

int4 getSectorNum(int4 tilePos) {
    float4 temp = convert_float4(tilePos);
    temp = temp / sectorSize;
    return convert_int4(floor(temp));
}

int4 getSectorRel(int4 tilePos) {
    const int4 b = sectorSize;
    return ((tilePos % b) + b) % b;
    //return tilePos - getSectorNum(tilePos)*sectorSize;
}

#ifdef UseTexture
bool isSolid(int4 tilePos,
    __read_only image3d_t tileMap
    ) {
    int4 rel = getSectorRel(tilePos);
    int bit = rel.x%TileStorageBitCount;
    int4 pos = (int4)(rel.x/TileStorageBitCount, rel.y, rel.z, 0);

    TileStorageType byte = read_imageui(tileMap, tileImageSampler, pos).x;
    return 0 != (byte & (1<<bit));
}
#else

//IF NOT TEXTURE
bool isSolid(int4 tilePos,
    TileStorageLocation const TileStorageType* solidMap
    ) {
    int4 rel = getSectorRel(tilePos);
    int x   = tilePos.x/TileStorageBitCount;
    int bit = tilePos.x%TileStorageBitCount;
    int y   = tilePos.y;
    int z   = tilePos.z;

    TileStorageType byte = solidMap[x + solidMapSize.x * (y + solidMapSize.y * z)];
    return 0 != (byte & (1<<bit));
}
#endif

int4 getTilePos(vec4f tilePos) {
    return convert_int4(floor(tilePos));
}

float initStuff(float start, float vel, float delta) {
    if( ((int)start) == start) {
        if (vel > 0.f) {
            return delta;
        }
        return 0.f;
    }
    float stop = start+sign(vel); //Take one step in the direction we want to move in
    //Depending on direction we move in, find floor or ceil to get
    //distance to next stop/step
    if(vel > 0) {                
        stop = floor(stop);
    } else {
        stop = ceil(stop);
    }
    float dist = stop-start;
    return dist / vel;
}

void stepIter(int4 dir, int4* tilePos, float4* tMax, float4 tDelta, float *tMin) {
    *tMin = min(tMax->x, min(tMax->y, tMax->z));
    if(tMax->x < tMax->y) {
        if(tMax->x < tMax->z) {
            tilePos->x += dir.x;
            tMax->x += tDelta.x;
        } else {
            tilePos->z += dir.z;
            tMax->z += tDelta.z;
        }
    } else {
        if(tMax->y < tMax->z) {
            tilePos->y += dir.y;
            tMax->y += tDelta.y;
        } else {
            tilePos->z += dir.z;
            tMax->z += tDelta.z;
        }
    }
}

__kernel void castRays(
    __constant struct Camera* camera,
#ifdef UseTexture
    __read_only image3d_t solidMap,
#else
    TileStorageLocation const TileStorageType* solidMap,
#endif
    __global int* outMap
)
{
    int x = get_global_id(0);
    int y = get_global_id(1);
    float percentX = ((float)x) / ((float)camera->width);
    float percentY = ((float)y) / ((float)camera->height);
    vec4f rayDir = normalize(camera->upperLeft + percentX * camera->toRight + percentY * camera->toDown);

    int4 tilePos    = getTilePos(camera->position);
    int4 dir      = convert_int4(sign(rayDir));;
    vec4f tDelta;
    tDelta.x        = fabs(1.f / rayDir.x);
    tDelta.y        = fabs(1.f / rayDir.y);
    tDelta.z        = fabs(1.f / rayDir.z);
    //tDelta = tDelta * sign(tDelta); //Make absolute value ;)
    
    vec4f tMax;
    tMax.x = initStuff(camera->position.x, rayDir.x, tDelta.x);
    tMax.y = initStuff(camera->position.y, rayDir.y, tDelta.y);
    tMax.z = initStuff(camera->position.z, rayDir.z, tDelta.z);

    float time;
    stepIter(dir, &tilePos, &tMax, tDelta, &time);
    int c = 0;
    while(c < 16 && !isSolid(tilePos, solidMap)) {
        c++;
        stepIter(dir, &tilePos, &tMax, tDelta, &time);
    }

    int val = 16777215 -  (int)((((float)c) / 300.f) * (16777215.f)); 
    //int val = (int)((((float)time) / 150.f) * (255)); 

    outMap[get_global_id(0) + (camera->height-1-get_global_id(1)) * camera->width] = val;
    
    int4 checkPosition = (int4)(1, 1, 1, 0);
    //outMap[get_global_id(0) + (camera->height-1-get_global_id(1)) * camera->width] = isSolid(checkPosition, solidMap) ? 0xFFFFFFFF : 0x0;
}

