
import world;
import std.container;
import engine.irrlicht;
import util;

struct GraphicsRegion
{
	aabbox3d!double Region;	
	uint VBO;
	uint indexCount;
};

class VBOMaker : WorldListener
{	
    SList!GraphicsRegion regions;
    World world;
    
    this(World w)
    {
        world = w;
    }
    ~this()
    {
    }
    
    void notifySectorLoad(vec3i sectorPos)
    {
    }
    void notifySectorUnload(vec3i sectorPos)
    {
    }
    void notifyTileChange(vec3i tilePos)
    {
        
    }
}