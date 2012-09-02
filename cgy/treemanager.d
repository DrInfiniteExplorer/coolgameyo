module treemanager;

import std.exception;
import std.stdio;
import std.random;
import std.conv;
import std.math;
import std.array;

import graphics.debugging;
import stolen.aabbox3d;

import util.util;
import util.tileiterator;
import worldstate.worldstate;
import worldstate.sector;
import worldstate.block;
import entities.entity;
import entities.treelikeinstance;
import entitytypemanager;
import tiletypemanager;

class TreeManager {
    int THICKNESS_SCALE = 16;
    int NODE_DISTANCE_SCALE = 4;

    WorldState world;
    //public EntityType currentType;
    //Entity[] entities;

    Random gen;
    Random leafRandom;

    int debugIdCounter = 0;
    bool drawDebugLines = true;
    bool drawTiles = true;
    bool drawLeafs = true;
    bool[10] drawBranchId;
    //
    //int[] lineId;
    //int[] aabbId;

	this(WorldState w)
    {
		world = w;
        for (int i = 0; i < 10; i++) {
            drawBranchId[i] = true;
        }
	}

    //private void printAllFuckingEntities()
    //{
    //    msg("====================================================");
    //    foreach (Entity entity ; entities) {
    //        msg("---", entity.type.displayName,"---");
    //        foreach (BranchInstance branch ; entity.treelike.branches) {
    //            msg("...Branch ",branch.typeId,"...");
    //            foreach (NodeInstance node ; branch.nodes) {
    //                msg(node.debugId, " Node parent:",(node.parentNode!is(null)?node.parentNode.debugId:-1));          
    //            }
    //        }
    //    }
    //}


    //public void growTrees(int iterations = 1)
    //{
    //    msg("xxxxxxxxxxxxxxxxxx-growTrees()-xxxxxxxxxxxxxxxxxx");
    //    makeDebugLines();
    //
    //    foreach (entity ; entities) {
    //        foreach (branch ; entity.treelike.branches) {
    //            for (int i = 0; i < iterations; i++) {
    //                newBranch(entity, branch);
    //                increaseNodeDistance(entity, branch);
    //                increaseThickness(entity, branch);
    //                newNode(entity, branch);
    //            }
    //        }
    //        clearTiles(entity);
    //        makeTiles(entity);
    //    }
    //    foreach (entity ; entities) {
    //        makeLeafs(entity);
    //    }
    //    printAllFuckingEntities();
    //}

    public void growTree(Entity entity, int iterations = 1)
    {
        foreach (branch ; entity.treelike.branches) {
            for (int i = 0; i < iterations; i++) {
                newBranch(entity, branch);
                increaseNodeDistance(entity, branch);
                increaseThickness(entity, branch);
                newNode(entity, branch);
            }
        }
        clearTiles(entity);
        makeTiles(entity);
        makeLeafs(entity);
    }

    private void newBranch(Entity entity, BranchInstance parentBranch)
    {
        //msg("newBranch()");
        if (parentBranch.nrOfChildBranches >= parentBranch.branchesPerBranchTarget) {
            return;
        }
        foreach (ref branchType ; entity.type.treelike.branches) {
            if (branchType.growsOn == parentBranch.typeId) {
                ubyte preferredNodePos = to!(ubyte)((parentBranch.nodes.length-1) * branchType.posOnParent);
                NodeInstance bestNode;
                float bestNodeCost = 9000.1f; // the first valid node will be cheaper than this
                float currentNodeCost;
                for (int i = branchType.posOnParentMin; i < parentBranch.nodes.length; i++) {   // find the best node to spawn on
                    currentNodeCost = branchType.posOnParentDistanceCost * abs(preferredNodePos - i) + branchType.posOnParentCrowdedCost * parentBranch.nodes[i].nrOfChildBranches;
                    if (currentNodeCost + uniform(0.0f, branchType.posOnParentRandomness+0.00000001, gen) < bestNodeCost) {
                        bestNodeCost = currentNodeCost;
                        bestNode = parentBranch.nodes[i];
                    }
                }
                if ((branchType.spawnChance - bestNodeCost) > uniform(0.0f, 1.0f, gen)) {
                    entity.treelike.branches ~= createAndInitializeBranch(branchType, bestNode);
                    parentBranch.nrOfChildBranches++;
                    //msg("Spawned branch on ", cast(int)parentBranch.typeId);
                }
            }
        }

    }

    private BranchInstance createAndInitializeBranch(BranchType type, NodeInstance parentNode)
    {
        //msg("createAndInitializeBranch()");
        BranchInstance branch = new BranchInstance;
        branch.typeId = type.id;

        branch.nrOfNodesTarget =    cap(type.nrOfNodesTarget +    uniform(-1.0f, 1.0f, gen) * type.nrOfNodesTargetVariation, 0, 255);
        branch.nodeDistanceTarget = cap(NODE_DISTANCE_SCALE * (type.nodeDistanceTarget + uniform(-1.0f, 1.0f, gen) * type.nodeDistanceTargetVariation), 0, 255);
        branch.thicknessTarget =    cap(THICKNESS_SCALE * (type.thicknessTarget +    uniform(-1.0f, 1.0f, gen) * type.thicknessTargetVariation), 0, 255);
        branch.branchesPerBranchTarget = cap(type.branchesPerBranchTarget + uniform(-1.0f, 1.0f, gen) * type.branchesPerBranchTargetVariation, 0, 255);

        branch.thickness = cap(THICKNESS_SCALE * type.thicknessStart, 0, 255);

        float angleVertical = type.angleFromParent + uniform(-1.0f, 1.0f, gen) * type.angleFromParentVariation;
        float angleHorizontal = uniform(0.0f, PI * 2.0f, gen);

        NodeInstance node = new NodeInstance;
        node.debugId = debugIdCounter++;
        node.pos[0] = to!(byte)(1 * sin(angleVertical) * cos(angleHorizontal));
        node.pos[1] = to!(byte)(1 * sin(angleVertical) * sin(angleHorizontal));
        node.pos[2] = to!(byte)(1 * cos(angleVertical));
        node.nodeDistance = 1;
        node.angleHorizontal = getAngleUByteFromFloat(angleHorizontal);
        node.angleVertical = getAngleUByteFromFloat(angleVertical);
        node.parentNode = parentNode;
        parentNode.nrOfChildBranches++;
        branch.nodes ~= parentNode;
        branch.nodes ~= node;

        return branch;
    }

    private void increaseNodeDistance(Entity entity, BranchInstance branch)
    {
        //msg("increaseNodeDistance()");
        BranchType branchType = getBranchType(entity, branch);
        ubyte nodeDistance;
        float angleVertical;
        float angleHorizontal;

        for (int i = 1; i < branch.nodes.length; i++) {
            if (branch.nodes[i].nodeDistance < branch.nodeDistanceTarget) {
                angleHorizontal = getAngleFloatFromUbyte(branch.nodes[i].angleHorizontal);
                angleVertical = getAngleFloatFromUbyte(branch.nodes[i].angleVertical);
                if (branchType.nodeDistanceIncreaseChace > uniform(0.0f, 1.0f, gen)) {
                    branch.nodes[i].nodeDistance++;
                    branch.nodes[i].pos[0] = to!(byte)(branch.nodes[i].nodeDistance * sin(angleVertical) * cos(angleHorizontal));
                    branch.nodes[i].pos[1] = to!(byte)(branch.nodes[i].nodeDistance * sin(angleVertical) * sin(angleHorizontal));
                    branch.nodes[i].pos[2] = to!(byte)(branch.nodes[i].nodeDistance * cos(angleVertical));
                    //msg("Increased node distance to ", cast(int)branch.nodes[i].nodeDistance);
                }
            }
        }
    }

    private void increaseThickness(Entity entity, BranchInstance branch)
    {
        //msg("increaseThickness()");
        if (branch.thickness < branch.thicknessTarget) {
            if (getBranchType(entity, branch).thicknessGrowth > uniform(0.0f, 1.0f, gen)) {
                branch.thickness++;
                //msg("Thickened ", cast(int)branch.typeId, " to ", cast(int)branch.thickness);
            }
        }
    }

    private void newNode(Entity entity, BranchInstance branch)
    {
        //msg("newNode()");
        if (branch.nodes.length >= branch.nrOfNodesTarget) {
            return;
        }

        BranchType branchType = getBranchType(entity, branch);

        ubyte preferredNodePos = to!(ubyte)(branch.nodes.length * branchType.newNodePos);
        ubyte bestNodePos;
        float bestNodeCost = 9000.1f; // the first valid node will be cheaper than this
        float currentNodeCost;
        for (ubyte i = 0; i < branch.nodes.length + 1; i++) {   // find the best node to spawn on
            currentNodeCost = branchType.newNodePosDistanceCost * abs(preferredNodePos - i);
            if (currentNodeCost + uniform(0.0f, branchType.newNodePosRandomness+0.000001, gen) < bestNodeCost) {
                bestNodeCost = currentNodeCost;
                bestNodePos = i;
            }
        }
        if ((branchType.newNodeChance - bestNodeCost) > uniform(0.0f, 1.0f, gen)) {
            NodeInstance node = new NodeInstance;
            node.debugId = debugIdCounter++;

            if (bestNodePos == branch.nodes.length) {
                node.angleHorizontal = branch.nodes[branch.nodes.length-1].angleHorizontal;
                node.angleVertical = branch.nodes[branch.nodes.length-1].angleVertical;
                node.parentNode = branch.nodes[bestNodePos-1];
            }
            else if (bestNodePos == 0) {
                bestNodePos=1;
                node.angleHorizontal = branch.nodes[1].angleHorizontal;
                node.angleVertical = branch.nodes[1].angleVertical;
                node.parentNode = branch.nodes[1].parentNode;
                branch.nodes[1].parentNode = node;
            }
            else {
                node.angleHorizontal = branch.nodes[branch.nodes.length-1].angleHorizontal;
                node.angleVertical = branch.nodes[branch.nodes.length-1].angleVertical;
                node.parentNode = branch.nodes[bestNodePos-1];
                branch.nodes[bestNodePos].parentNode = node;
            }
            float angleHorizontal = getAngleFloatFromUbyte(node.angleHorizontal);
            float angleVertical = getAngleFloatFromUbyte(node.angleVertical);
            node.pos[0] = to!(byte)(1 * sin(angleVertical) * cos(angleHorizontal));
            node.pos[1] = to!(byte)(1 * sin(angleVertical) * sin(angleHorizontal));
            node.pos[2] = to!(byte)(1 * cos(angleVertical));
            node.nodeDistance = 1;

            branch.nodes.insertInPlace(bestNodePos, node);

            //msg("Added node on ", cast(int)branch.typeId, " at pos ", cast(int)bestNodePos);
        }
    }

    private byte getDistanceOfNode(NodeInstance node)
    {
        return to!(byte)(sqrt(cast(real)(NODE_DISTANCE_SCALE * (node.pos[0]^^2) + NODE_DISTANCE_SCALE * (node.pos[2]^^2) + NODE_DISTANCE_SCALE * (node.pos[2]^^2))) / NODE_DISTANCE_SCALE );
    }

    private ubyte getAngleUByteFromFloat(float f)
    {
        if (f < 0) f += 2*PI;
        if (f > 2*PI) f -= 2*PI;
        return to!(ubyte)(f * 250 / (2 * PI));
    }
    private float getAngleFloatFromUbyte(ubyte b)
    {
        return (b * 2 * PI / 250);
    }

    private BranchType getBranchType(Entity entity, BranchInstance branch)
    {
        foreach (ref type ; entity.type.treelike.branches) {
            if (type.id == branch.typeId) {
                return type;
            }
        }
        throw new Exception("Could not find branch type");
    }


    //public void setCurrentType(EntityType type)
    //{
    //    currentType = type;
    //}

    private Entity createTreeEntity(TilePos pos, EntityType treeType)
    {
        Entity entity = newEntity();
        entity.pos = pos.toEntityPos;
        entity.type = treeType;

        TreelikeInstance tree = new TreelikeInstance;

        NodeInstance rootNode = new NodeInstance;
        rootNode.nodeDistance = 1;
        rootNode.debugId = debugIdCounter++;
        tree.branches ~= createAndInitializeBranch(treeType.treelike.branches[0], rootNode);
        //tree.branches[0].nodes.insertInPlace(0, rootNode);
        entity.treelike = tree;

        clearTiles(entity);
        makeTiles(entity);
        makeLeafs(entity);


        return entity;
    }

    //public void plantTree(TilePos pos, EntityType treeType)
    //{
    //    entities ~= createTreeEntity(pos, treeType);
    //    makeDebugLines();
    //}

    private void clearTiles(Entity entity)
    {
        foreach (TilePos tilePos ; entity.ownedTiles) {
            Tile tile = Tile(TileTypeAir, TileFlags.valid);
            world.unsafeSetTile(tilePos, tile);
        }
        entity.ownedTiles.length = 0;
    }

    private void makeTiles(Entity entity)
    {
        if (drawTiles == false) return;

        foreach(branch ; entity.treelike.branches) {
            if (drawBranchId[branch.typeId]) {
                for (int b = 0; b < branch.nodes.length-1; b++) {
                    TilePos start = getTilePosOfNode(entity, branch.nodes[b]);
                    TilePos end = getTilePosOfNode(entity, branch.nodes[b+1]);

                    TilePos[] tilePosArray = getTilesBetween(toVec3d(start.value), toVec3d(end.value),
                                                             world.tileTypeManager.idByName(entity.type.treelike.woodMaterial), world.tileTypeManager.idByName(entity.type.treelike.leafMaterial));

                    for (int i = 0; i < tilePosArray.length; i++) {
                        Tile tile;
                        if (getThicknessOfNode(branch, branch.nodes[b+1], getBranchType(entity, branch)) < THICKNESS_SCALE*1.0 &&
                            (world.getTile(tilePosArray[i], false).type != world.tileTypeManager.idByName(entity.type.treelike.woodMaterial))) {
                                auto tileType = world.tileTypeManager.idByName(entity.type.treelike.leafMaterial);
                                tile = Tile(tileType, TileFlags.valid);
                            }
                        else {
                            auto tileType = world.tileTypeManager.idByName(entity.type.treelike.woodMaterial);
                            tile = Tile(tileType, TileFlags.valid);
                        }

                        world.unsafeSetTile(tilePosArray[i], tile);
                        entity.ownedTiles ~= tilePosArray[i];
                    }
                }
            }
        }
    }



    //Returns all tile that are on the line between start and end
    TilePos[] getTilesBetween(vec3d start, vec3d end, ushort acceptedTileType, ushort acceptedTileType2=0, int tileIter=255)
    {
        start += vec3d(0.5, 0.5, 0.5);
        end += vec3d(0.5, 0.5, 0.5);
        TilePos[] output;
        vec3d dir = (end-start).normalize();
        foreach(tilePos ; TileIterator(start, dir, tileIter)) {
            auto tile = world.getTile(tilePos, false);
            if (tile.type == TileTypeAir || tile.type == acceptedTileType || (acceptedTileType2 != 0 && tile.type == acceptedTileType2)) {
                output ~= tilePos;
            }
            else {
                return output;
            }
            if (getDistanceSQ(tilePos.value, end) < 1.0) {
                return output;
            }
        }
        return output;
    }

    void makeLeafs(Entity entity)
    {
        if (drawLeafs == false) return;
        leafRandom.seed(0);
        BranchType type;
        int radius;
        foreach (branch ; entity.treelike.branches) {
            if (drawBranchId[branch.typeId]) {
                type = getBranchType(entity, branch);
                radius = cast(int)type.leafRadius;

                if (type.pineShape) {
                    for (int i = 0; i < branch.nodes.length-1; i++) {
                        for (int z = 0; z < cast(int)(branch.nodes[i+1].pos[2]/NODE_DISTANCE_SCALE+1); z++) {
                            float r = getThicknessOfNode(branch, branch.nodes[i+1], type) - getThicknessOfNode(branch, branch.nodes[i], type);
                            r = r / (branch.nodes[i+1].pos[2]/NODE_DISTANCE_SCALE);
                            r = getThicknessOfNode(branch, branch.nodes[i], type) + z * r;
                            r = r / (THICKNESS_SCALE*type.thicknessTarget);
                            r = clamp(r, 0.0f, 1.0f);
                            msg("id:",type.id," i:",i," z:",z," pos:",branch.nodes[i].pos[2]," r:",r,);
                            for (int x = -radius; x <= radius; x++) {
                                for (int y = -radius; y <= radius; y++) {
                                    if ((x*x+y*y) < type.leafRadius*type.leafRadius*r*r &&
                                        uniform(0.0, 1.0, leafRandom) < type.leafDensity) {
                                            TilePos tilePos = getTilePosOfNode(entity, branch.nodes[i]);
                                            tilePos.value.X += x;
                                            tilePos.value.Y += y;
                                            tilePos.value.Z += z;
                                            auto tile = world.getTile(tilePos, false);
                                            if (tile.type == TileTypeAir) {
                                                auto tileType = world.tileTypeManager.idByName(entity.type.treelike.leafMaterial);
                                                Tile tile = Tile(tileType, TileFlags.valid);
                                                world.unsafeSetTile(tilePos, tile);
                                                entity.ownedTiles ~= tilePos;
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                else {
                    for (int i = 1; i < branch.nodes.length; i++) {
                        float r = (getThicknessOfNode(branch, branch.nodes[i], type)-THICKNESS_SCALE*type.thicknessStart) / (THICKNESS_SCALE*type.thicknessTarget-THICKNESS_SCALE*type.thicknessStart) + 0.3;
                        r = clamp(r, 0.0f, 1.0f);
                        for (int x = -radius; x <= radius; x++) {
                            for (int y = -radius; y <= radius; y++) {
                                for (int z = -radius; z <= radius; z++) {
                                    if ((x*x+y*y+z*z) < type.leafRadius*type.leafRadius*r*r &&
                                        uniform(0.0, 1.0, leafRandom) < type.leafDensity) {
                                            TilePos tilePos = getTilePosOfNode(entity, branch.nodes[i]);
                                            tilePos.value.X += x;
                                            tilePos.value.Y += y;
                                            tilePos.value.Z += z;
                                            auto tile = world.getTile(tilePos, false);
                                            if (tile.type == TileTypeAir) {
                                                auto tileType = world.tileTypeManager.idByName(entity.type.treelike.leafMaterial);
                                                Tile tile = Tile(tileType, TileFlags.valid);
                                                world.unsafeSetTile(tilePos, tile);
                                                entity.ownedTiles ~= tilePos;
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }


    }

    vec3d toVec3d(vec3i v)
    {
        vec3d r;
        r.X = v.X;
        r.Y = v.Y;
        r.Z = v.Z;
        return r;
    }

    double getDistanceSQ(vec3i a, vec3d b)
    {
        return (a.X-b.X)*(a.X-b.X) + (a.Y-b.Y)*(a.Y-b.Y) + (a.Z-b.Z)*(a.Z-b.Z);
    }

    ubyte cap(float a, int lower, int upper)
    {
        if (a < lower) return to!(ubyte)(lower);
        if (a > upper) return to!(ubyte)(upper);
        return to!(ubyte)(a);
    }

    private float getThicknessOfNode(BranchInstance branch, NodeInstance node, BranchType type)
    {
        for (int i = 0; i < branch.nodes.length; i++) {
            if (branch.nodes[i] == node) {
                return branch.thickness - to!(ubyte)(to!(float)(THICKNESS_SCALE) * to!(float)(type.thicknessDistanceCost)) * i;
            }
        }
        throw new Exception("Could not find node on branch");
    }

    private TilePos getTilePosOfNode(Entity entity, NodeInstance node)
    {
        vec3i v;

        v.X = node.pos[0];
        v.Y = node.pos[1];
        v.Z = node.pos[2];

        NodeInstance n = node;
        while (n.parentNode !is null) {
            n = n.parentNode;
            v.X += n.pos[0];
            v.Y += n.pos[1];
            v.Z += n.pos[2];
        }

        TilePos t = entity.pos.tilePos();
        t.value.X += to!(int)(v.X/NODE_DISTANCE_SCALE);
        t.value.Y += to!(int)(v.Y/NODE_DISTANCE_SCALE);
        t.value.Z += to!(int)(v.Z/NODE_DISTANCE_SCALE);
        return t;
    }


    //private void makeDebugLines()
    //{
    //    foreach (ref line ; lineId) {
    //        removeLine(line);
    //    }
    //    foreach (ref aabb ; aabbId) {
    //        removeAABB(aabb);
    //    }
    //
    //    if (drawDebugLines == false) return;
    //
    //    vec3d[2] points;
    //    foreach (entity ; entities) {
    //        foreach (branch ; entity.treelike.branches) {
    //            if (drawBranchId[branch.typeId]) {
    //                for (int i = 0; i < branch.nodes.length; i++) {
    //                    points[0] = getPosOfNode(entity, branch.nodes[i]); 
    //                    if (i < branch.nodes.length - 1) {
    //                        points[1] = getPosOfNode(entity, branch.nodes[i + 1]);
    //                        lineId ~= addLine(points, vec3f(1, 0, 0));
    //                    }
    //                    aabbd aabb = aabbox3d!double(points[0] - vec3d(0.2, 0.2, 0.2), points[0] + vec3d(0.2, 0.2, 0.2));
    //                    aabbId ~= addAABB(aabb);
    //                }
    //            }
    //        }
    //    }
    //}

    private vec3d getPosOfNode(Entity entity, NodeInstance node)
    {
        vec3d v;

        v.X = node.pos[0];
        v.Y = node.pos[1];
        v.Z = node.pos[2];

        NodeInstance n = node;
        while (n.parentNode !is null) {
            n = n.parentNode;
            v.X += n.pos[0];
            v.Y += n.pos[1];
            v.Z += n.pos[2];
        }

        v /= NODE_DISTANCE_SCALE;
        v.X += entity.pos.tilePos().value.X + 0.5;
        v.Y += entity.pos.tilePos().value.Y + 0.5;
        v.Z += entity.pos.tilePos().value.Z + 0.5;
        return v;
    }


    //public void toggleDrawTiles()
    //{
    //    drawTiles = !drawTiles;
    //    foreach (entity ; entities) {
    //        clearTiles(entity);
    //        makeTiles(entity);
    //        makeLeafs(entity);
    //    }
    //    printAllFuckingEntities();
    //    msg("Toggle DrawTiles ",drawTiles);
    //}
    //public void toggleDrawLeafs()
    //{
    //    drawLeafs = !drawLeafs;
    //    foreach (entity ; entities) {
    //        clearTiles(entity);
    //        makeTiles(entity);
    //        makeLeafs(entity);
    //    }
    //    printAllFuckingEntities();
    //    msg("Toggle DrawLeafs ",drawLeafs);
    //}
    //public void toggleDrawDebugLines()
    //{
    //    drawDebugLines = !drawDebugLines;
    //    makeDebugLines();
    //    printAllFuckingEntities();
    //    msg("Toggle DrawDebugLines ",drawDebugLines);
    //}
    //public void toggleDrawBranchId(int id)
    //{
    //    drawBranchId[id] = !drawBranchId[id];
    //    foreach (entity ; entities) {
    //        clearTiles(entity);
    //        makeTiles(entity);
    //        makeLeafs(entity);
    //    }
    //    makeDebugLines();
    //    printAllFuckingEntities();
    //    msg("Toggle DrawBranchId[",id,"] ",drawBranchId[id]);
    //}


}


