module graphics.vbomaker;

import core.sync.mutex;

import std.algorithm;
import std.array;
import std.container;
import std.conv;
import std.exception;
import std.math;
import std.stdio;
version(Windows) import std.c.windows.windows; //TODO: What uses this?

import derelict.opengl.gl;
import derelict.opengl.glext;


import graphics.camera;
import graphics.debugging;
import graphics.renderer;
import modules.module_;
import pos;
import scheduler;
import settings;
import stolen.aabbox3d;
import util;
import world;


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

}

struct GraphicsRegion
{
    GraphRegionNum grNum;
    uint VBO = 0;
    uint quadCount = 0;
    GRFace[] faces;
}

struct GRVertex{
    vec3f vertex;
    vec3f texcoord;
};

struct GRFace{
    GRVertex[4] quad;
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

class VBOMaker : Module, WorldListener
{
    GraphRegionNum[] regionsToUpdate; //Only used in taskFunc and where we populate it, mutually exclusive locations.
    GraphicsRegion[GraphRegionNum] regions; //Accessed from getRegions and from taskFunc, could collide.
    GraphRegionNum[] dirtyRegions; //Can be updated by worker thread; Is read&cleared in render thread.
    Mutex dirtyMutex;
    Mutex regionMutex;
    Mutex updateMutex;

    World world;
    Camera camera;
    double minReUseRatio;

    this(World w, Scheduler s, Camera c)
    {
        world = w;
        camera = c;
        s.registerModule(this);
        world.addListener(this);
        minReUseRatio = 0.95;
        regionMutex = new Mutex;
        dirtyMutex = new Mutex;
        updateMutex = new Mutex;
    }
    
    void destroy() {
        world.removeListener(this);
        removeAllVBOs();
    }

    void removeAllVBOs(){
        foreach(region ; regions){
            glDeleteBuffers(1, &region.VBO);
        }
        regions = null;
    }

    //Floor/Roof-tiles.
    void buildGeometryZ(TilePos min, TilePos max, ref GRFace[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        GRFace newFace;

        void fixTex(ref GRFace f, const(Tile) t, bool upper){
            auto p = upper ?
                world.tileTypeManager.byID(t.type).textures.top :
                world.tileTypeManager.byID(t.type).textures.bottom;
            
            vec3f tileTexSize = settings.getTileCoordSize();
            vec3f tileTexCoord = settings.getTileCoords(p);
            foreach(ref vert ; f.quad){
                vert.texcoord = vert.texcoord * tileTexSize + tileTexCoord;
            }
        }
        
        
        foreach(doUpper ; 0 .. 2){ //Most best piece of code ever to have been written.
            auto ett = 1-doUpper;
            auto noll = doUpper;
            foreach(z ; min.value.Z-1 .. max.value.Z){
                foreach(y ; min.value.Y .. max.value.Y){
                    float halfEtt;
                    foreach(x; min.value.X .. max.value.X){

                        auto tileLower = world.getTile(TilePos(vec3i(x,y,z+noll)), false, false);
                        auto tileUpper = world.getTile(TilePos(vec3i(x,y,z+ett)), false, false);
                        auto transUpper = tileUpper.transparent;
                        auto transLower = tileLower.transparent;
                        if(ett == 1) {
                            transUpper |= tileLower.halfstep;
                        } else {
                            transUpper |= tileUpper.halfstep;
                        }

                        auto bothValid = (tileUpper.valid && tileLower.valid) || renderSettings.renderInvalidTiles;

                        //If doing upper surface; if lower tile is half-surface
                        auto halfLower = doUpper == 0 && tileLower.halfstep;
                        halfEtt = halfLower ? 0.5 : 1.0;

                        if(bothValid && transUpper && !transLower){ //Floor tile detected!
                            newFace.quad[0].vertex.set(x, y+ett, z+halfEtt);
                            newFace.quad[1].vertex.set(x, y+noll, z+halfEtt);
                            newFace.quad[2].vertex.set(x+1, y+noll, z+halfEtt);
                            newFace.quad[3].vertex.set(x+1, y+ett, z+halfEtt);
                            newFace.quad[0].texcoord.set(0, 0, 0);
                            newFace.quad[1].texcoord.set(0, 1, 0);
                            newFace.quad[2].texcoord.set(1, 1, 0);
                            newFace.quad[3].texcoord.set(1, 0, 0);
                            //enforce(0, "Calculate texture coordinates 'offline'");
                            //newFace.type = texId(tileLower, doUpper == 0);
                            fixTex(newFace, tileLower, doUpper == 0);
                            faceList ~= newFace;
                        }
                    }
                }
            }
        }
    }


    //Dont generate half-sized "back-sides", behind half-tiles; if we have a halftile, it'd break a quad for us.
    //That'd make us cry.
    void buildGeometryY(TilePos min, TilePos max, ref GRFace[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        bool onStrip;
        bool onHalf;
        GRFace newFace;
        void fixTex(ref GRFace f, const(Tile) t){
            vec3f tileTexSize = settings.getTileCoordSize();
            vec3f tileTexCoord = settings.getTileCoords(world.tileTypeManager.byID(t.type).textures.side);
            foreach(ref vert ; f.quad){
                vert.texcoord = vert.texcoord * tileTexSize + tileTexCoord;
            }
        }

        foreach(doUpper ; 0 .. 2) { //Most best piece of code ever to have been written.
            auto ett = 1-doUpper;
            auto noll = doUpper;
            auto neg = noll ? 1 : -1;
            foreach(y ; min.value.Y-1 .. max.value.Y) {
                foreach(z ; min.value.Z .. max.value.Z) {
                    onStrip = false;
                    float halfEtt;
                    float halfNoll;
                    foreach(x; min.value.X .. max.value.X){

                        auto tileLower = world.getTile(TilePos(vec3i(x,y+noll,z)), false, false);
                        auto tileUpper = world.getTile(TilePos(vec3i(x,y+ett,z)), false, false);
                        auto transUpper = tileUpper.transparent || tileUpper.halfstep;
                        auto transLower = tileLower.transparent;

                        auto bothValid = (tileUpper.valid && tileLower.valid) || renderSettings.renderInvalidTiles;

                        bool halfLower = tileLower.halfstep;

                        halfEtt = to!float(ett) * (halfLower ? 0.5 : 1.0);
                        halfNoll = to!float(noll) * (halfLower ? 0.5 : 1.0);

                        if(bothValid && transUpper && !transLower && !(tileUpper.halfstep && tileLower.halfstep)){ //Floor tile detected!
                            newFace.quad[0].vertex.set(x, y+1, z+halfNoll);
                            newFace.quad[1].vertex.set(x, y+1, z+halfEtt);
                            newFace.quad[2].vertex.set(x+1, y+1, z+halfEtt);
                            newFace.quad[3].vertex.set(x+1, y+1, z+halfNoll);
                            newFace.quad[0].texcoord.set(0, ett, 0);
                            newFace.quad[1].texcoord.set(0, noll, 0);
                            newFace.quad[2].texcoord.set(1, noll, 0);
                            newFace.quad[3].texcoord.set(1, ett, 0);
                            //enforce(0, "Calculate texture coordinates 'offline'");
                            //newFace.type = texId(tileLower);
                            fixTex(newFace, tileLower);
                            faceList ~= newFace;
                        }
                    }
                }
            }
        }
    }

    void buildGeometryX(TilePos min, TilePos max, ref GRFace[]faceList)
    in{
        assert(min.value.X < max.value.X);
        assert(min.value.Y < max.value.Y);
        assert(min.value.Z < max.value.Z);
    }
    body{
        //Make floor triangles
        GRFace newFace;
        void fixTex(ref GRFace f, const(Tile) t){
            vec3f tileTexSize = settings.getTileCoordSize();
            vec3f tileTexCoord = settings.getTileCoords(world.tileTypeManager.byID(t.type).textures.side);
            foreach(ref vert ; f.quad){
                vert.texcoord = vert.texcoord * tileTexSize + tileTexCoord;
            }
        }

        foreach(doUpper ; 0 .. 2){ //Most best piece of code ever to have been written.
            auto ett = 1-doUpper;
            auto noll = doUpper;
            auto neg = ett ? 1 : -1;
            foreach(x ; min.value.X-1 .. max.value.X){
                foreach(z ; min.value.Z .. max.value.Z){

                    float halfEtt;
                    float halfNoll;
                    foreach(y; min.value.Y .. max.value.Y){
                        auto tileLower = world.getTile(TilePos(vec3i(x+noll,y,z)), false, false);
                        auto tileUpper = world.getTile(TilePos(vec3i(x+ett,y,z)), false, false);
                        auto transUpper = tileUpper.transparent || tileUpper.halfstep;
                        auto transLower = tileLower.transparent;

                        auto bothValid = (tileUpper.valid && tileLower.valid) || renderSettings.renderInvalidTiles;

                        bool halfLower = tileLower.halfstep;

                        halfEtt = to!float(ett) * (halfLower ? 0.5 : 1.0);
                        halfNoll = to!float(noll) * (halfLower ? 0.5 : 1.0);

                        if(bothValid && transUpper && !transLower && !(tileUpper.halfstep && tileLower.halfstep)){ //Floor tile detected!
                            newFace.quad[0].vertex.set(x+1, y, z+halfEtt);
                            newFace.quad[1].vertex.set(x+1, y, z+halfNoll);
                            newFace.quad[2].vertex.set(x+1, y+1, z+halfNoll);
                            newFace.quad[3].vertex.set(x+1, y+1, z+halfEtt);
                            newFace.quad[0].texcoord.set(0, noll, 0);
                            newFace.quad[1].texcoord.set(0, ett, 0);
                            newFace.quad[2].texcoord.set(1, ett, 0);
                            newFace.quad[3].texcoord.set(1, noll, 0);
                            //enforce(0, "Calculate texture coordinates 'offline'");
                            fixTex(newFace, tileLower);
                            //newFace.type = texId(tileLower);
                            faceList ~= newFace;
                        }
                    }
                }
            }
        }
    }



    const(GraphicsRegion)[GraphRegionNum] getRegions(){
        {
            dirtyMutex.lock();
            scope(exit) dirtyMutex.unlock();
            foreach(num; dirtyRegions){
                regionMutex.lock();
                scope(exit) regionMutex.unlock();
                buildVBO(regions[num]);
            }
            dirtyRegions.length = 0;
        }

        return regions;
    }

    void buildVBO(ref GraphicsRegion region){
        auto primitiveCount = region.faces.length;
        auto geometrySize = primitiveCount * GRFace.sizeof;
        region.quadCount = primitiveCount;

        scope(exit) region.faces.length = 0;
        if(region.VBO){
            //See if VBO is reusable.
            int bufferSize;
            glBindBuffer(GL_ARRAY_BUFFER, region.VBO);
            glGetBufferParameteriv(GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB, &bufferSize);

            double ratio = to!double(geometrySize)/to!double(bufferSize);
            if(minReUseRatio <= ratio && ratio <= 1){
                glBufferSubData(GL_ARRAY_BUFFER, 0, geometrySize, region.faces.ptr);
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
            glBufferData(GL_ARRAY_BUFFER, geometrySize, region.faces.ptr, GL_STATIC_DRAW);
        } else {
            msg("GOT NOTHING FROM GRAPHREGION! >:( ", region.grNum);
        }
        //addAABB(region.grNum.getAABB());
    }

    void buildGraphicsRegion(GraphicsRegion region){
        StopWatch sw;
        sw.start();
        //Face[] faces;
        auto min = region.grNum.min();
        auto max = region.grNum.max();
        buildGeometryX(min, max, region.faces);
        buildGeometryY(min, max, region.faces);
        //Floor
        buildGeometryZ(min, max, region.faces);

        foreach(ref face ; region.faces) {
            foreach(ref vert ; face.quad) {
                vert.vertex -= util.convert!float(min.value);
            }
        }

        //Ordering the other way around caused race condition where the render-thread tried to build num X before it's data had been set.
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            regions[region.grNum] = region;
        }
        {
            dirtyMutex.lock();
            scope(exit) dirtyMutex.unlock();
            dirtyRegions ~= region.grNum;
        }

        sw.stop();
        //msg("It took ", sw.peek().msecs, " ms to build the geometry");
    }

    void taskFunc(const(World) world, GraphRegionNum num) {
        GraphicsRegion reg;
        reg.grNum = num;
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            if(num in regions) {
                reg = regions[num];
                if(reg.faces.length > 0){ //If was duplicate and/or quickly reinserted, but not yet rendered, do not blargh the blargh again
                    return;
                }
            }
        }
        buildGraphicsRegion(reg);
    }

    override void update(World world, Scheduler scheduler) {
        updateMutex.lock();
        scope(exit) updateMutex.unlock();

        if(regionsToUpdate.length == 0){
            return;
        }

        double computeValue(GraphRegionNum num) {
            const auto graphRegionAcross = sqrt(to!double(  GraphRegionSize.x*GraphRegionSize.x +
                                                            GraphRegionSize.y*GraphRegionSize.y +
                                                            GraphRegionSize.z*GraphRegionSize.z));
            auto camDir = util.convert!double(camera.getTargetDir());
            auto camPos = camera.getPosition() - camDir * graphRegionAcross;
            vec3d toBlock = util.convert!double(num.toTilePos().value) - camPos;
            double distSQ = toBlock.getLengthSQ();
            if(camDir.dotProduct(toBlock) < 0) {
                distSQ +=1000; //Stuff behind our backs are considered as important as stuff a kilometer ahead of us. ? :)
            }
            return distSQ;
        }

        //TODO: Do not sort every tick in the future.
        schwartzSort!(computeValue, "a>b")(regionsToUpdate);
        //writeln("before ", regionsToUpdate.length);
        regionsToUpdate = array(uniq(regionsToUpdate));
        //writeln("after ", regionsToUpdate.length);        
        
        enum GraphRegionsPerTick = 2;
        auto cnt = min(regionsToUpdate.length, GraphRegionsPerTick);
        assert(cnt > 0, "derp derp derp");
        auto nums = regionsToUpdate[$-cnt .. $];
        regionsToUpdate.length -= cnt;
        foreach(num ; nums) {
            //Trixy trick below; if we dont do this, the value num will be shared by all pushed tasks.
            (GraphRegionNum num){
                scheduler.push(asyncTask(
                    (const(World) world){
                        taskFunc(world, num);
                    }));
            }(num);
        }        
    }
    
    
    bool hasContent(GraphRegionNum grNum) {
        auto minBlockNum = grNum.min.getBlockNum();
        BlockNum maxBlockNum = grNum.max.getBlockNum();
        int seenCount;
        foreach(rel ; RangeFromTo(minBlockNum.value, maxBlockNum.value)) {

            auto num = BlockNum(rel);
            auto block = world.getBlock(num, false, false);
            if(block.seen){
                auto a=true;
                seenCount++;
                if(block.sparse && block.sparseTileTransparent) {
                    seenCount--;
                    a=false;
                }
                if(a){
                    //addAABB(num.getAABB(), vec3f(0.f, 1.f, 0.f));
                }
            }
        }
        return seenCount != 0;
    }

    void onAddUnit(SectorNum, Unit*) { }

    void onSectorLoad(SectorNum sectorNum)
    {
        //version(Windows) auto start = GetTickCount();
        auto grNumMin = sectorNum.toTilePos().getGraphRegionNum();
        sectorNum.value += vec3i(1,1,1);
        auto tmp = sectorNum.toTilePos();
        tmp.value -= vec3i(1,1,1);
        auto grNumMax = tmp.getGraphRegionNum();
        grNumMax.value += vec3i(1,1,1);
        sectorNum.value -= vec3i(1,1,1);

        //TODO: figure out what kind of problems i was referring to.
        //ASSUMES THAT WE ARE IN THE UPDATE PHASE, OTHERWISE THIS MAY INTRODUCE PROBLEMS AND SUCH. :)
        //*
        GraphRegionNum[] newRegions;
        foreach(pos ; RangeFromTo(grNumMin.value, grNumMax.value)) {
            auto grNum = GraphRegionNum(pos);
            if(hasContent(grNum)){
                //msg("Has content;", grNum);
                newRegions ~= grNum;
            }
        }
        if(newRegions.length != 0){
            updateMutex.lock();
            scope(exit) updateMutex.unlock();
            regionsToUpdate ~= newRegions;
        }
    }
    
    void onSectorUnload(SectorNum sectorNum)
    {
        auto sectorAABB = sectorNum.getAABB();
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            foreach(region ; regions){
                if(intersects(sectorAABB, region.grNum.getAABB())){
                    msg("Unload stuff oh yeah!!");
                    msg("Perhaps.. Should we.. Maybe.. Stora data on disk? We'll see how things turn out.");
                    //How to do stuff, et c?
                }
            }
        }
        enforce("Implement");
    }
    void onTileChange(TilePos tilePos)
    {
        GraphRegionNum[] newRegions;
        auto tileAABB = tilePos.getAABB();
        {
            regionMutex.lock();
            scope(exit) regionMutex.unlock();
            foreach(region ; regions){
                if(tileAABB.intersectsWithBox(region.grNum.getAABB())){
                    newRegions ~= region.grNum;
                }
            }
        }

        //Example, we dug into a yet invisible area.
        //Maybe let the floodfill take care of it instead, somehow?
        //dunno. think it's needed here as well.
        if(newRegions.length == 0) {
            newRegions ~= tilePos.getGraphRegionNum(); //Check neighboring graphregions as well.
        }
        updateMutex.lock();
        scope(exit) updateMutex.unlock();
        regionsToUpdate ~= newRegions;
    }
}

