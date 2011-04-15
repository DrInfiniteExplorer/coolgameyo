module graphics.vbomaker;

import std.algorithm;
import std.container;
import std.conv;
import std.math;
import std.stdio;
version(Windows) import std.c.windows.windows;

import derelict.opengl.gl;
import derelict.opengl.glext;


import graphics.renderer;
import graphics.camera;
import world;
import scheduler;
import util;
import pos;
import stolen.aabbox3d;

private alias aabbox3d!double box;

//This is different from box.intersectsWithBox in that the upper ranges are strictly smaller than, making adjancent boxes not intersect.
//(I hope)
bool intersects(box a, box b){
    auto minx = max(a.MinEdge.X, b.MinEdge.X);
    auto miny = max(a.MinEdge.Y, b.MinEdge.Y);
    auto minz = max(a.MinEdge.Z, b.MinEdge.Z);
    auto maxx = min(a.MaxEdge.X, b.MaxEdge.X);
    auto maxy = min(a.MaxEdge.Y, b.MaxEdge.Y);
    auto maxz = min(a.MaxEdge.Z, b.MaxEdge.Z);

    return minx < maxx && miny<maxy && minz<maxz;

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
    GraphRegionNum grNum;
    uint VBO = 0;
    uint quadCount = 0;
}

struct Vertex{
    vec3f vertex;
    vec2f texcoord;
    uint type;
};


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
        assert(intersects(c, d) == bbb, "This should've been " ~ bbb);
        assert(intersects(d, c) == bbb, "This should've been " ~ bbb);
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
    GraphRegionNum[] regionsToUpdate;
    GraphicsRegion[GraphRegionNum] regions;
    World world;
    Scheduler scheduler;
    Camera camera;
    double minReUseRatio;

    this(World w, Scheduler s, Camera c)
    {
        world = w;
        scheduler = s;
        camera = c;
        world.addListener(this);
        minReUseRatio = 0.95;
    }

    const(GraphicsRegion)[GraphRegionNum] getRegions() const{
        return regions;
    }

    void removeAllVBOs(){
        foreach(region ; regions){
            glDeleteBuffers(1, &region.VBO);
        }
        regions = null;
    }

    struct Face{
        Vertex[4] quad;
        void type(uint t) @property {
            foreach(ref q; quad){
                q.type = t;
            }
        }
        uint type() const @property { return quad[0].type; }
    }

    //Floor/Roof-tiles.
    void buildGeometryZ(TilePos min, TilePos max, ref Face[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        bool onStrip;
        bool onHalf;
        Face newFace;

        ushort texId(const(Tile) t, bool upper){
            return upper ?
                world.tileSystem.byID(t.type).textures.top :
                world.tileSystem.byID(t.type).textures.bottom;
        }

        foreach(doUpper ; 0 .. 2){ //Most best piece of code ever to have been written.
            auto ett = 1-doUpper;
            auto noll = doUpper;
            foreach(z ; min.value.Z-1 .. max.value.Z){
                foreach(y ; min.value.Y .. max.value.Y){
                    onStrip = false;
                    onHalf = false;
                    float halfEtt;
                    float prevHalfEtt;
                    foreach(x; min.value.X .. max.value.X){
                        auto tileLower = world.getTile(tilePos(vec3i(x,y,z+noll)), false, false);
                        auto tileUpper = world.getTile(tilePos(vec3i(x,y,z+ett)), false, false);
                        auto transUpper = tileUpper.transparent;
                        auto transLower = tileLower.transparent;

                        auto bothValid = (tileUpper.valid && tileLower.valid) || renderSettings.renderInvalidTiles;

                        //If doing upper surface; if lower tile is half-surface
                        auto halfLower = doUpper == 0 && tileLower.halfstep;
                        auto halfSame = halfLower == onHalf;
                        prevHalfEtt = halfEtt;
                        halfEtt = halfLower ? 0.5 : 1.0;

                        //halfEtt = 1;
                        //prevHalfEtt = 1;

                        // TODO: Take into account the possibility of
                        // green glass on red glass on water; ought to render the intersecting surfaces, sortof?
                        // NO! transparent things are handled on their own, elsewhere, not defined where yet.

                        if(bothValid && transUpper && !transLower){ //Floor tile detected!
                            if(onStrip &&
                               (newFace.type != texId(tileLower, doUpper==0) ||
                               !halfSame)){
                                newFace.quad[2].vertex.set(x, y+noll, z+prevHalfEtt);
                                newFace.quad[3].vertex.set(x, y+ett, z+prevHalfEtt);
                                newFace.quad[2].texcoord.set(x, 1);
                                newFace.quad[3].texcoord.set(x, 0);
                                faceList ~= newFace;
                                onStrip = false;
                            }
                            if(!onStrip){ //Start of floooor
                                onStrip = true;
                                onHalf = halfLower;
                                newFace.quad[0].vertex.set(x, y+ett, z+halfEtt);
                                newFace.quad[1].vertex.set(x, y+noll, z+halfEtt);
                                newFace.quad[0].texcoord.set(x, 0);
                                newFace.quad[1].texcoord.set(x, 1);
                                newFace.type = texId(tileLower, doUpper == 0);
                            }else {} //if onStrip && same, continue
                        }else if(onStrip){ //No floor :(
                            //End current strip.
                            newFace.quad[2].vertex.set(x, y+noll, z+prevHalfEtt);
                            newFace.quad[3].vertex.set(x, y+ett, z+prevHalfEtt);
                            newFace.quad[2].texcoord.set(x, 1);
                            newFace.quad[3].texcoord.set(x, 0);
                            faceList ~= newFace;
                            onStrip = false;
                        }
                    }
                    if(onStrip){ //No floor :(
                        //End current strip.
                        newFace.quad[2].vertex.set(max.value.X, y+noll, z+halfEtt);
                        newFace.quad[3].vertex.set(max.value.X, y+ett, z+halfEtt);
                        newFace.quad[2].texcoord.set(max.value.X, 1);
                        newFace.quad[3].texcoord.set(max.value.X, 0);
                        faceList ~= newFace;
                        onStrip = false;
                   }
                }
            }
        }
    }
    void buildGeometryY(TilePos min, TilePos max, ref Face[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        bool onStrip;
        bool onHalf;
        Face newFace;
        ushort texId(const(Tile) t){
            return world.tileSystem.byID(t.type).textures.side;
        }

        foreach(doUpper ; 0 .. 2){ //Most best piece of code ever to have been written.
            auto ett = 1-doUpper;
            auto noll = doUpper;
            foreach(y ; min.value.Y-1 .. max.value.Y){
                foreach(z ; min.value.Z .. max.value.Z){
                    onStrip = false;
                    float halfEtt;
                    float prevHalfEtt;
                    float halfNoll;
                    float prevHalfNoll;
                    foreach(x; min.value.X .. max.value.X){
                        auto tileLower = world.getTile(tilePos(vec3i(x,y+noll,z)), false, false);
                        auto tileUpper = world.getTile(tilePos(vec3i(x,y+ett,z)), false, false);
                        auto transUpper = tileUpper.transparent || tileUpper.halfstep;
                        auto transLower = tileLower.transparent;

                        auto bothValid = (tileUpper.valid && tileLower.valid) || renderSettings.renderInvalidTiles;

                        bool halfLower = tileLower.halfstep;
                        bool halfSame = onHalf == halfLower;

                        prevHalfEtt = halfEtt;
                        prevHalfNoll = halfNoll;
                        halfEtt = to!float(ett) * (halfLower ? 0.5 : 1.0);
                        halfNoll = to!float(noll) * (halfLower ? 0.5 : 1.0);

                        if(bothValid && transUpper && !transLower && !(tileUpper.halfstep && tileLower.halfstep)){ //Floor tile detected!
                            if(onStrip &&
                               (newFace.type != texId(tileLower) ||
                                !halfSame)){
                                newFace.quad[2].vertex.set(x, y+1, z+prevHalfEtt);
                                newFace.quad[3].vertex.set(x, y+1, z+prevHalfNoll);
                                newFace.quad[2].texcoord.set(x, noll);
                                newFace.quad[3].texcoord.set(x, ett);
                                faceList ~= newFace;
                                onStrip = false;
                            }
                            if(!onStrip){ //Start of floooor
                                onStrip = true;
                                onHalf = halfLower;
                                newFace.quad[0].vertex.set(x, y+1, z+halfNoll);
                                newFace.quad[1].vertex.set(x, y+1, z+halfEtt);
                                newFace.quad[0].texcoord.set(x, ett);
                                newFace.quad[1].texcoord.set(x, noll);
                                newFace.type = texId(tileLower);
                            }else {} //if onStrip && same, continue
                        }else if(onStrip){ //No floor :(
                            //End current strip.
                            newFace.quad[2].vertex.set(x, y+1, z+prevHalfEtt);
                            newFace.quad[3].vertex.set(x, y+1, z+prevHalfNoll);
                            newFace.quad[2].texcoord.set(x, noll);
                            newFace.quad[3].texcoord.set(x, ett);
                            faceList ~= newFace;
                            onStrip = false;
                        }
                    }
                    if(onStrip){ //No floor :(
                        //End current strip.
                        newFace.quad[2].vertex.set(max.value.X, y+1, z+halfEtt);
                        newFace.quad[3].vertex.set(max.value.X, y+1, z+halfNoll);
                        newFace.quad[2].texcoord.set(max.value.X, noll);
                        newFace.quad[3].texcoord.set(max.value.X, ett);
                        faceList ~= newFace;
                        onStrip = false;
                   }
                }
            }
        }
    }

    void buildGeometryX(TilePos min, TilePos max, ref Face[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        bool onStrip;
        bool onHalf;
        Face newFace;
        ushort texId(const(Tile) t){
            return world.tileSystem.byID(t.type).textures.side;
        }

        foreach(doUpper ; 0 .. 2){ //Most best piece of code ever to have been written.
            auto ett = 1-doUpper;
            auto noll = doUpper;
            foreach(x ; min.value.X-1 .. max.value.X){
                foreach(z ; min.value.Z .. max.value.Z){
                    onStrip = false;
                    float halfEtt;
                    float prevHalfEtt;
                    float halfNoll;
                    float prevHalfNoll;
                    foreach(y; min.value.Y .. max.value.Y){
                        auto tileLower = world.getTile(tilePos(vec3i(x+noll,y,z)), false, false);
                        auto tileUpper = world.getTile(tilePos(vec3i(x+ett,y,z)), false, false);
                        auto transUpper = tileUpper.transparent || tileUpper.halfstep;
                        auto transLower = tileLower.transparent;

                        auto bothValid = (tileUpper.valid && tileLower.valid) || renderSettings.renderInvalidTiles;

                        bool halfLower = tileLower.halfstep;
                        bool halfSame = onHalf == halfLower;

                        prevHalfEtt = halfEtt;
                        prevHalfNoll = halfNoll;
                        halfEtt = to!float(ett) * (halfLower ? 0.5 : 1.0);
                        halfNoll = to!float(noll) * (halfLower ? 0.5 : 1.0);

                        if(bothValid && transUpper && !transLower && !(tileUpper.halfstep && tileLower.halfstep)){ //Floor tile detected!
                            if(onStrip &&
                               (newFace.type != texId(tileLower) ||
                                !halfSame)){
                                newFace.quad[2].vertex.set(x+1, y, z+prevHalfNoll);
                                newFace.quad[3].vertex.set(x+1, y, z+prevHalfEtt);
                                newFace.quad[2].texcoord.set(y, ett);
                                newFace.quad[3].texcoord.set(y, noll);
                                faceList ~= newFace;
                                onStrip = false;
                            }
                            if(!onStrip){ //Start of floooor
                                onStrip = true;
                                onHalf = halfLower;
                                newFace.quad[0].vertex.set(x+1, y, z+halfEtt);
                                newFace.quad[1].vertex.set(x+1, y, z+halfNoll);
                                newFace.quad[0].texcoord.set(y, noll);
                                newFace.quad[1].texcoord.set(y, ett);
                                newFace.type = texId(tileLower);
                            }else {} //if onStrip && same, continue
                        }else if(onStrip){ //No floor :(
                            //End current strip.
                            newFace.quad[2].vertex.set(x+1, y, z+prevHalfNoll);
                            newFace.quad[3].vertex.set(x+1, y, z+prevHalfEtt);
                            newFace.quad[2].texcoord.set(y, ett);
                            newFace.quad[3].texcoord.set(y, noll);
                            faceList ~= newFace;
                            onStrip = false;
                        }
                    }
                    if(onStrip){ //No floor :(
                        //End current strip.
                        newFace.quad[2].vertex.set(x+1, max.value.Y, z+halfNoll);
                        newFace.quad[3].vertex.set(x+1, max.value.Y, z+halfEtt);
                        newFace.quad[2].texcoord.set(max.value.Y, ett);
                        newFace.quad[3].texcoord.set(max.value.Y, noll);
                        faceList ~= newFace;
                        onStrip = false;
                   }
                }
            }
        }
    }

    void buildVBO(ref GraphicsRegion region, Face[] faces){
        auto primitiveCount = faces.length;
        auto geometrySize = primitiveCount * Face.sizeof;
        region.quadCount = primitiveCount;
        if(region.VBO){
            //See if VBO is reusable.
            int bufferSize;
            glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
            glGetBufferParameteriv(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);

            double ratio = to!double(geometrySize)/to!double(bufferSize);
            if(minReUseRatio <= ratio && ratio <= 1){
                glBufferSubData(GL_ARRAY_BUFFER, 0, geometrySize, faces.ptr);
                return;
            }else{
                //Delete old vbo
                glBindBuffer(GL_ARRAY_BUFFER, 0);
                glDeleteBuffers(1, &region.VBO);
                region.VBO = 0; //For all it's worth. Will create new one just below. :P
            }
        }
        if(geometrySize > 0){
            glGenBuffers(1, &region.VBO);
            glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
            glBufferData(GL_ARRAY_BUFFER, geometrySize, faces.ptr, GL_STATIC_DRAW);
        }
    }

    void buildGraphicsRegion(ref GraphicsRegion region){
        version(Windows) auto start = GetTickCount();
        Face[] faces;
        auto min = region.grNum.min();
        auto max = region.grNum.max();
        buildGeometryX(min, max, faces);
        buildGeometryY(min, max, faces);
        //Floor
        buildGeometryZ(min, max, faces);

        foreach(ref face ; faces) {
            foreach(ref vert ; face.quad) {
                vert.vertex -= util.convert!float(min.value);
            }
        }
        version(Windows) auto d1 = GetTickCount() - start;
        buildVBO(region, faces);
        version(Windows) auto d2 = GetTickCount() - start - d1;

        version(Windows) writeln("It took ", d1, " ms to build the geometry and ", d2, " ms to build the vbo (total of ", d1+d2, " ms)");

    }

    void taskFunc() {
        assert(regionsToUpdate.length > 0, "Error in VBOMaker.taskFunc; Got nothing to do!!");

        double computeValue(GraphRegionNum num) {
            const auto graphRegionAcross = sqrt(to!double(  GraphRegionSize.x*GraphRegionSize.x +
                                                            GraphRegionSize.y*GraphRegionSize.y +
                                                            GraphRegionSize.z*GraphRegionSize.z));
            auto camDir = util.convert!double(camera.getTargetDir());
            auto camPos = camera.getPosition() - camDir * graphRegionAcross;
            vec3d toBlock = util.convert!double(num.toTilePos().value) - camPos;
            double distSQ = toBlock.getLengthSQ();
            if(camDir.dotProduct(toBlock) < 0) {
                distSQ = -distSQ;
            }
            return distSQ;
        }

        schwartzSort!(computeValue, "a>b")(regionsToUpdate);
        auto num = regionsToUpdate[$-1];
        regionsToUpdate.length -= 1;

        auto grPtr = num in regions;
        if(grPtr) {
            buildGraphicsRegion(*grPtr);
        } else{
            auto ny = GraphicsRegion();
            ny.grNum = num;
            buildGraphicsRegion(ny);
            regions[num] = ny;
        }

        if(regionsToUpdate.length != 0){
            scheduler.push(asyncTask(&taskFunc));
        }
    }

    void notifySectorLoad(SectorNum sectorNum)
    {
        //version(Windows) auto start = GetTickCount();
        auto grNumMin = sectorNum.toTilePos().getGraphRegionNum();
        sectorNum.value += vec3i(1,1,1);
        auto tmp = sectorNum.toTilePos();
        tmp.value -= vec3i(1,1,1);
        auto grNumMax = tmp.getGraphRegionNum();
        grNumMax.value += vec3i(1,1,1);
        sectorNum.value -= vec3i(1,1,1);

        //ASSUMES THAT WE ARE IN THE UPDATE PHASE, OTHERWISE THIS MAY INTRODUCE PROBLEMS AND SUCH. :)
        /*
        if(regionsToUpdate.length == 0){
            scheduler.push(asyncTask(&taskFunc));
        }
        foreach(pos ; RangeFromTo(grNumMin.value, grNumMax.value)) {
            auto grNum = graphRegionNum(pos);
            regionsToUpdate ~= grNum;
        }
        */
        foreach(pos ; RangeFromTo(grNumMin.value, grNumMax.value)) {
            auto grNum = graphRegionNum(pos);
            if (grNum in regions) {
                buildGraphicsRegion(regions[grNum]);
            } else {
                auto ny = GraphicsRegion();
                ny.grNum = grNum;
                buildGraphicsRegion(ny);
                regions[grNum] = ny;
            }
        }
        // */
        //version(Windows) writeln("It took ", GetTickCount() - start, " ms to geometricize a region");
    }
    void notifySectorUnload(SectorNum sectorNum)
    {
        auto sectorAABB = sectorNum.getAABB();

        foreach(region ; regions){
            if(intersects(sectorAABB, region.grNum.getAABB())){
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
            if(intersects(region.grNum.getAABB(), tileAABB)){
                writeln("Update this region!!");
                cnt ++;
                asm{ int 3; }
            }
        }
        assert(cnt == 1, cnt == 0 ?
               "Seems we were told to update a tile we dont have a graphics region for yet" :
               "Seems we have more than one graphics region that claims to own a tile");
    }
}

