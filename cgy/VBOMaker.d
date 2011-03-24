
import std.stdio;
import std.container;

import engine.irrlicht;

import world;
import util;

private alias aabbox3d!double box;

//This is different from box.intersectsWithBox in that the upper ranges are strictly smaller than, making adjancent boxes not intersect.
//(I hope)
bool intersects(box a, box b){
    if(a.MinEdge<b.MinEdge){
        box c = a;
        a = b;
        b = c;
    }
    return (a.MinEdge.X < b.MaxEdge.X && a.MinEdge.Y < b.MaxEdge.Y && a.MinEdge.Z < b.MaxEdge.Z &&
        a.MaxEdge.X >= b.MinEdge.X && a.MaxEdge.Y >= b.MinEdge.Y && a.MaxEdge.Z >= b.MinEdge.Z);    
}

struct GraphicsRegion
{
	aabbox3d!double aabb;	
	uint VBO = 0;
	uint indexCount = 0;
}

unittest{
    //alias aabbox3d!double box;
    auto a = box(-1, -1, -1, 1, 1, 1);
    auto b = box(-2, -2, -2, 2, 2, 2);    
    assert(intersects(b, a) == true, "Intersectswithbox doesnt seem to account for wholly swallowed boxes");
    assert(intersects(b, a) == true, "Intersectswithbox doesnt seem to account for wholly bigger boxes");    
    assert(intersects(a, a) == true, "Intersection when exactly the same wvaluated to false");

    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0, 0, 0, 2, 2, 2)) == true, "This shouldve been true");
    assert(intersects(box(0, 0, 0, 2, 2, 2), box(0, 0, 0, 1, 1, 1)) == true, "This shouldve been true");
    
    //This makes the ones below this for redundant, i think and hope and such
    auto c = box(0, 0, 0, 1, 1, 1);
    foreach(p ; RangeFromTo(-1, 2, -1, 2, -1, 2)){
        auto d = c;
        d.MinEdge += util.convert!double(p);
        d.MaxEdge += util.convert!double(p);
        bool bbb = p == vec3i(0,0,0);
        assert(intersects(c, d) == bbb, "This should've been "~bbb);
        assert(intersects(d, c) == bbb, "This should've been "~bbb);
    }
    
    //We dont want boxes that are lining up to intersect with each other...
    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0-1, 0, 0, 1-1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x-.");
    assert(intersects(box(0-1, 0, 0, 1-1, 1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x-(2).");
    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0+1, 0, 0, 1+1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x+.");
    assert(intersects(box(0+1, 0, 0, 1+1, 1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x+(2).");

    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0, 0-1, 0, 1, 1-1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y-.");
    assert(intersects(box(0, 0-1, 0, 1, 1-1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y-(2).");
    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0, 0+1, 0, 1, 1+1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y+.");
    assert(intersects(box(0, 0+1, 0, 1, 1+1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y+(2).");

    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0, 0, 0-1, 1, 1, 1-1)) == false, "Seems that boxes next to each other intersect. Sadface in z-.");
    assert(intersects(box(0, 0, 0-1, 1, 1, 1-1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in z-(2).");
    assert(intersects(box(0, 0, 0, 1, 1, 1), box(0, 0, 0+1, 1, 1, 1+1)) == false, "Seems that boxes next to each other intersect. Sadface in z+.");
    assert(intersects(box(0, 0, 0+1, 1, 1, 1+1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in z+(2).");

}

class VBOMaker : WorldListener
{	
    GraphicsRegion[] regions;
    World world;
    
    this(World w)
    {
        world = w;
        world.addListener(this);
    }
    ~this()
    {
        removeAllVBOs();
    }
    
    void removeAllVBOs(){
        foreach(region ; regions){
            assert(0, "Remove vbo");
        }
        regions.length=0;
    }
    
    struct Face{
        vec3i[4] vertices;
        TileType type;
    }
    
    void buildGeometry(TilePos min, TilePos max)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        Tile tmp;//Do i even need this one?
        bool onStrip;
        Face newFace;
        Face[] faceList;
        for(int z = min.value.Z-1; z < max.value.Z; z++){
            for(int y = min.value.Y; y < max.value.Y; y++){
                onStrip = false;
                for(int x = min.value.X; x < max.value.X; x++){
                    auto tileLower = world.getTile(tilePos(vec3i(x,y,z)));
                    auto tileUpper = world.getTile(tilePos(vec3i(x,y,z+1)));
                    auto transUpper = tileUpper.transparent;
                    auto transLower = tileLower.transparent;
                    
                    if(transUpper && !transLower){ //Floor tile detected!
                        if(onStrip && tmp.type != tileLower.type){
                            newFace.vertices[2].set(x+1, y, z+1);
                            newFace.vertices[3].set(x+1, y+1, z+1);
                            faceList ~= newFace;
                            onStrip = false;
                        }
                        if(!onStrip){ //Start of floooor
                            onStrip = true;
                            tmp = tileLower;
                            newFace.vertices[0].set(x, y+1, z+1);
                            newFace.vertices[1].set(x, y, z+1);
                            newFace.type = tmp.type;
                        }else {} //if onStrip && same, continue
                    }else if(onStrip){ //No floor :(
                        //End current strip.
                        newFace.vertices[2].set(x+1, y, z+1);
                        newFace.vertices[3].set(x+1, y+1, z+1);
                        faceList ~= newFace;
                        onStrip = false;
                    }                    
                }
                if(onStrip){ //No floor :(
                    //End current strip.
                    newFace.vertices[2].set(max.value.X+1, y, z+1);
                    newFace.vertices[3].set(max.value.X+1, y+1, z+1);
                    faceList ~= newFace;
                    onStrip = false;            
               }
            }
        }
    }
    
    void notifySectorLoad(SectorNum sectorNum)
    {
        assert(0, "Implement VBOMaker.notifySectorLoad");
    }
    void notifySectorUnload(SectorNum sectorNum)
    {
        auto sectorAABB = sectorNum.getAABB();
        
        foreach(region ; regions){
            if(intersects(sectorAABB, region.aabb)){
                writeln("Unload stuff oh yeah!!");
                writeln("Perhaps.. Should we.. Maybe.. Stora data on disk? We'll see how things turn out.");
                //How to do stuff, et c?
            }
        }
    }
    void notifyTileChange(TilePos tilePos)
    {               
        auto tileAABB = tilePos.getAABB();
        int cnt=0;
        foreach(region ; regions){
            if(intersects(region.aabb, tileAABB)){
                writeln("Update this region!!");
                cnt ++;
            }
        }
        assert(cnt == 1, cnt == 0 ?
               "Seems we were told to update a tile we dont have a graphics region for yet" :
               "Seems we have more than one graphics region that claims to own a tile");
    }
}

