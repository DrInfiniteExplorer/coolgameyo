
//#define UseTexture

#ifndef MaxLightTraceDistance
#define MaxLightTraceDistance 100.f
#endif

#ifndef FadeLightTraceDistance
#define FadeLightTraceDistance 90.f
#endif

#ifndef TileStorageLocation
#define TileStorageLocation texture
#endif

#ifndef TileStorageType
#define TileStorageType uint
#endif

#ifndef SolidMapSize
#define SolidMapSize 4,128,32
#endif

#ifndef UsePackedData
#define UsePackedData 1
#endif

#ifndef TileStorageBitCount
#define TileStorageBitCount 32
#endif

// TileStorageLocation passed as define from host
// TileStorageType passed as define from host
// SolidMapSize passed as define from host in format %d,%d,%d
// UsePackedData derp derp guess what???

//  #pragma OPENCL EXTENSION cl_khr_fp64 : enable
typedef float4 vec4f;

#define MAXLIGHTDIST 8

const sampler_t tileImageSampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_REPEAT | CLK_FILTER_NEAREST;
const sampler_t depthImageSampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_REPEAT | CLK_FILTER_NEAREST;

struct Camera {
    vec4f position;
    vec4f upperLeft;
    vec4f toRight;
    vec4f toDown;
    int width;
    int height;
};

struct Light {
	vec4f position;
	float strength;
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

//Gets "27 sectors" relative position
int4 getSectorRel27(int4 tilePos) {
    const int4 b = sectorSize*(int4)(3,3,3,0);
    return ((tilePos % b) + b) % b;
    //return tilePos - getSectorNum(tilePos)*sectorSize;
}


#ifdef UseTexture
bool isSolid(int4 tilePos,
    __read_only image3d_t tileMap
    ) {
    int4 rel = getSectorRel27(tilePos);
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
    int x   = rel.x/TileStorageBitCount;
    int bit = rel.x%TileStorageBitCount;
    int y   = rel.y;
    int z   = rel.z;

    TileStorageType byte = solidMap[x + solidMapSize.x * (y + solidMapSize.y * z)];
    return 0 != (byte & (1<<bit));
}
#endif

int4 getTilePos(vec4f tilePos) {
    return convert_int4(floor(tilePos));
}

// Makes starting position floating. Alltsa tMax
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

/*
tMax - tid for att komma till nasta
tMin - tid for att komma till denna
tilePos - den tilen vi hamnar i denna gangen
tDelta - tid att aka over en tile (alltid positiv)
dir - den faktiska riktningen vi aker i
*/
void stepIter(const int4 dir, int4* tilePos, float4* tMax, const float4 tDelta, float *tMin) {
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

const void getDaPoint(
	__constant struct Camera* camera,
#ifdef UseTexture
    __read_only image3d_t solidMap,
#else
    TileStorageLocation const TileStorageType* solidMap,
#endif
	vec4f* daPoint
) {
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
    while(c < 300 && !isSolid(tilePos, solidMap)) {
        c++;
        stepIter(dir, &tilePos, &tMax, tDelta, &time);
    }
	
	*daPoint = camera->position + rayDir * time*0.99999;
}

__constant vec4f normalDirections[6] = {
    (vec4f)( 1, 0, 0, 0),
    (vec4f)(-1, 0, 0, 0),
    (vec4f)( 0, 1, 0, 0),
    (vec4f)( 0,-1, 0, 0),
    (vec4f)( 0, 0, 1, 0),
    (vec4f)( 0, 0,-1, 0)
};

const void getDaPoint2(
	__constant struct Camera* camera,
#ifdef UseTexture
    __read_only image3d_t solidMap,
#else
    TileStorageLocation const TileStorageType* solidMap,
#endif
    __read_only image2d_t depth,
	vec4f* daPoint
) {
	int x = get_global_id(0);
    int y = get_global_id(1);

    vec4f pos = read_imagef(depth, depthImageSampler, (int2)(x,camera->height-y-1));
	*daPoint = pos;
}




bool equals(int4 a, int4 b) {
	return 	a.x==b.x &&
			a.y==b.y &&
			a.z==b.z &&
			a.w==b.w;
}

float calculateLightInPoint(
	vec4f daPoint,
	__constant struct Light* lights,
	const int nrOfLights,
#ifdef UseTexture
    __read_only image3d_t solidMap
#else
    TileStorageLocation const TileStorageType* solidMap
#endif
    ,__read_only image2d_t depth
) {
    
    
	float lightValue = 0.f;
	int i;
	vec4f rayDir;
	int4 lightPos;
	int4 tilePos;
	int4 dir;
	vec4f tDelta;
	vec4f tMax;
	float time;
	int c;
    vec4f normalDir;
    int normalIndex = (int)daPoint.w;
    daPoint.w = 0;
    switch(normalIndex) {
        case 0: normalDir = normalDirections[0]; break;
        case 1: normalDir = normalDirections[1]; break;
        case 2: normalDir = normalDirections[2]; break;
        case 3: normalDir = normalDirections[3]; break;
        case 4: normalDir = normalDirections[4]; break;
        case 5: normalDir = normalDirections[5]; break;        
    }
    daPoint += normalDir * 0.01;

    //if( dot(normalDirections[4], normalDirections[4]) > 0) return 0x00FF;
    //wtf varför går det inte att slå upp normaldirection :(
    
	for (i = 0; i < nrOfLights; i++) {
		lightPos = getTilePos(lights[i].position);
		tilePos  = getTilePos(daPoint);
        float strength = lights[i].strength;
		
		if (equals(tilePos, lightPos)) {
			// *7 does it so it is 0-240 for 2 lights (16*15=240)
            lightValue += clamp(
                strength/(distance(daPoint, strength)+0.1f) - 0.2f,
                0.f,
                strength);
		}
		else {
			rayDir = lights[i].position-daPoint;
            if(dot(rayDir, rayDir) > MAXLIGHTDIST*MAXLIGHTDIST) {
                continue;
            }
            rayDir =normalize(rayDir);
            if(dot(rayDir, convert_float4(normalDir)) <= 0) { //Surface is hidden, ignore
                continue;
            }
			dir = convert_int4(sign(rayDir));
            
			
			tDelta.x = fabs(1.f / rayDir.x);
			tDelta.y = fabs(1.f / rayDir.y);
			tDelta.z = fabs(1.f / rayDir.z);
			
			tMax.x = initStuff(daPoint.x, rayDir.x, tDelta.x);
			tMax.y = initStuff(daPoint.y, rayDir.y, tDelta.y);
			tMax.z = initStuff(daPoint.z, rayDir.z, tDelta.z);
			
			stepIter(dir, &tilePos, &tMax, tDelta, &time);
			while(time < MAXLIGHTDIST && !isSolid(tilePos, solidMap)) {
				if (equals(tilePos, lightPos)) {
					// *7 does it so it is 0-240 for 2 lights (16*15=240)
//					lightValue += (MAXLIGHTDIST-time)*7;
                    lightValue += clamp(
                        strength/time - 0.2f,
                        0.f,
                        strength);
                            break;
                        }
				
				stepIter(dir, &tilePos, &tMax, tDelta, &time);
			}
		}
	}
	if (lightValue > 255) lightValue = 255;
	return lightValue;
}


__kernel void castRays(
    __constant struct Camera* camera,
	__constant int* _lights,
#ifdef UseTexture
    __read_only image3d_t solidMap,
#else
    TileStorageLocation const TileStorageType* solidMap,
#endif
    __read_only image2d_t depth,
    __write_only image2d_t output
)
{
	int x = get_global_id(0);
    int y = get_global_id(1);
    
    

/*
    float time = read_imagef(depth, depthImageSampler, (int2)(x,camera->height-y-1)).x;
    write_imagef(output, (int2)(x,y), (float4)(0.f, 0.f, time/16.f ,1.0));
    return;
*/

    vec4f daPoint;
	getDaPoint2(camera, solidMap, depth, &daPoint);

/*
    daPoint.w=0;
    vec4f daPoint2;
	getDaPoint(camera, solidMap, &daPoint2);
    write_imagef(output, (int2)(x,camera->height-1-y), (float4)(0.f, 0.f, length(daPoint-daPoint2)/3.f ,1.0));
    return;
//*/	

	int nrOfLights=_lights[0];
	__constant struct Light *lights = (__constant struct Light*)(&_lights[1]);


	int val = (int)calculateLightInPoint(daPoint, lights, nrOfLights, solidMap, depth);
	
    //int val = 16777215 -  (int)((((float)daPoint.x) / 300.f) * (16777215.f)); 
    //int val = (int)((((float)time) / 150.f) * (255)); 

    //outMap[get_global_id(0) + (camera->height-1-get_global_id(1)) * camera->width] = val;
    int r = (val >> 16) & 0xFF;
    int g = (val >> 8 ) & 0xFF;
    int b = (val      ) & 0xFF;
    //write_imageui(output, (int2)(x,y), (uint4)(r,g,b,255));
    //write_imageui(output, (int2)(x,y), (uint4)(65535, 0, 0 ,255));
    write_imagef(output, (int2)(x,camera->height-1-y), (float4)(r/255, g/255.f, b/255.f ,1.0));

    
    int4 checkPosition = (int4)(3, 4, 5, 0);
    //outMap[get_global_id(0) + (camera->height-1-get_global_id(1)) * camera->width] = isSolid(checkPosition, solidMap) ? 0xFFFFFFFF : 0x0;
}

