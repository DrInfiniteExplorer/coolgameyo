
module world.sizes;

import std.math;

enum BlockSize {
    x = 8,
    y = 8,
    z = 8,
    total = x*y*z
}
alias BlockSize TilesPerBlock;

enum BlocksPerSector {
    x = 16,
    y = 16,
    z = 4,
    total = x*y*z
}

enum SectorSize {
    x = BlockSize.x * BlocksPerSector.x,
    y = BlockSize.y * BlocksPerSector.y,
    z = BlockSize.z * BlocksPerSector.z,
    total = x*y*z
}

//TODO: UPDATE THESE MEASUREMENT VALUES
//We may want to experiment with these values, or even make it a user settingable setting. Yeah.
// blocksize * 2 gives ~30 ms per block and a total of ~3500-3700 per sector
// blocksize * 4 gives ~500 ms per block and a total of ~3500 per sector
// blocksize * 2 seems more do-want-able since its faster when updating, yeah.
enum GraphRegionSize {
    x = BlockSize.x*2,
    y = BlockSize.y*2,
    z = BlockSize.z*2,
    total = x*y*z,
}

static assert(SectorSize.x % GraphRegionSize.x == 0, "Sector not evenly divisible by graph regions!");
static assert(SectorSize.y % GraphRegionSize.y == 0, "Sector not evenly divisible by graph regions!");
static assert(SectorSize.z % GraphRegionSize.z == 0, "Sector not evenly divisible by graph regions!");

enum HeightMapSampleDistance = SectorSize.x / 4; // samples per sector
