#pragma once

#include "Sector.h"

vec3i GetBlockRelativeTilePosition  (const vec3i &tilePosition);
vec3i GetChunkRelativeBlockPosition (const vec3i &tilePosition);
vec3i GetSectorRelativeChunkPosition(const vec3i &tilePosition);

vec3i GetBlockWorldPosition (const vec3i &tilePosition);
vec3i GetChunkWorldPosition (const vec3i &tilePosition);
vec3i GetSectorWorldPosition(const vec3i &tilePosition);

vec3i GetBlockPosition (const vec3i &tilePosition);
vec3i GetChunkPosition (const vec3i &tilePosition);
vec3i GetSectorPosition(const vec3i &tilePosition);



