
import std.container;

import engine.irrlicht;

import world;
import util;

/*
struct GraphicsRegion
{
	aabbox3d!double Region;	
	uint VBO;
	uint indexCount;
}
*/

class VBOMaker : WorldListener
{	
//    SList!GraphicsRegion regions;
    World world;
    
    this(World w)
    {
        world = w;
    }
    ~this()
    {
    }
    
    void notifySectorLoad(SectorNum sectorPos)
    {
    }
    void notifySectorUnload(SectorNum sectorPos)
    {
    }
    void notifyTileChange(TilePos tilePos)
    {
        
    }
}