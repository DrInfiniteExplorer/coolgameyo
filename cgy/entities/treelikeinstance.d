module entities.treelikeinstance;

class NodeInstance {
    int debugId;
    byte[3] pos; // Pos is relative to the previous node. realPos = pos / NODE_DISTANCE_SCALE
    ubyte nrOfChildBranches; // help variable. This could be calculated when needed instead of storing here.
    ubyte angleHorizontal; // realAngle = angleHorizontal * 2 * PI / 250
    ubyte angleVertical;
    ubyte nodeDistance;
    NodeInstance parentNode;
}

class BranchInstance {
    ubyte typeId;
    ubyte nrOfNodesTarget;
    ubyte nodeDistanceTarget;
    ubyte thickness; // realThickness = thickness / THICKNESS_SCALE
    ubyte thicknessTarget; // this is the first node on the branch. All other nodes gets their thickness after cost payment
    ubyte branchesPerBranchTarget;
    NodeInstance[] nodes; // all nodes of this branch. The order in the array = the order in game.
    // nodes[0] is always stationary. It is the root node.
    NodeInstance parentNode;

    ubyte nrOfChildBranches; // help variable. This could be calculated when needed instead of storing here.

    /*BranchInstance copy()
    {
    return this; // lol, ska fixa senare
    }*/
}

class TreelikeInstance {
    BranchInstance[] branches;
    bool isAlive = true;
}

mixin template TreeLike() {


    import std.array;
    import std.conv;
    import std.exception;
    import std.math;
    import std.random;
    //import std.stdio;

    import treemanager;
    import changes.worldproxy;

    TreelikeInstance treelike;


    int THICKNESS_SCALE = 16;
    int NODE_DISTANCE_SCALE = 4;

    //public EntityType currentType;
    //Entity[] entities;

    Random gen;
    Random leafRandom;

    //
    //int[] lineId;
    //int[] aabbId;


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

    int cnt = 24;
    void treelikeTick(WorldProxy proxy) {
        if((cnt % 1751) == 23) {
            growTree(proxy);
        }
        cnt++;

    }

    private void createTreeLikeEntity(WorldState world, WorldProxy proxy)
    {
        auto treeType = type;
        if(!treeType.hasTreelike) return;

        TreelikeInstance tree = new TreelikeInstance;
        NodeInstance rootNode = new NodeInstance;
        rootNode.nodeDistance = 1;
        rootNode.debugId = TreeManager().debugIdCounter++;
        tree.branches ~= createAndInitializeBranch(treeType.treelikeType.branches[0], rootNode);
        //tree.branches[0].nodes.insertInPlace(0, rootNode);
        treelike = tree;

        clearTiles(proxy);
        makeTiles(proxy);
        makeLeafs(proxy);
        growTree(proxy, 35);
        proxy.apply();
    }

    public void growTree(WorldProxy proxy, int iterations = 1)
    {
        for (int i = 0; i < iterations; i++) {
            foreach (branch ; treelike.branches) {    
                newBranch(branch);
                increaseNodeDistance(branch);
                increaseThickness(branch);
                newNode(branch);
            }
        }
        clearTiles(proxy);
        makeTiles(proxy);
        makeLeafs(proxy);
    }

    private void newBranch(BranchInstance parentBranch)
    {
        //msg("newBranch()");
        if (parentBranch.nrOfChildBranches >= parentBranch.branchesPerBranchTarget) {
            return;
        }
        foreach (ref branchType ; type.treelikeType.branches) {
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
                    treelike.branches ~= createAndInitializeBranch(branchType, bestNode);
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
        node.debugId = TreeManager().debugIdCounter++;
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

    private void increaseNodeDistance(BranchInstance branch)
    {
        //msg("increaseNodeDistance()");
        BranchType branchType = getBranchType(branch);
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

    private void increaseThickness(BranchInstance branch)
    {
        //msg("increaseThickness()");
        if (branch.thickness < branch.thicknessTarget) {
            if (getBranchType(branch).thicknessGrowth > uniform(0.0f, 1.0f, gen)) {
                branch.thickness++;
                //msg("Thickened ", cast(int)branch.typeId, " to ", cast(int)branch.thickness);
            }
        }
    }

    private void newNode(BranchInstance branch)
    {
        //msg("newNode()");
        if (branch.nodes.length >= branch.nrOfNodesTarget) {
            return;
        }

        BranchType branchType = getBranchType(branch);

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
            node.debugId = TreeManager().debugIdCounter++;

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

            insertInPlace(branch.nodes, bestNodePos, node);

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

    private BranchType getBranchType(BranchInstance branch)
    {
        foreach (ref type ; type.treelikeType.branches) {
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




    //public void plantTree(TilePos pos, EntityType treeType)
    //{
    //    entities ~= createTreeEntity(pos, treeType);
    //    makeDebugLines();
    //}

    private void clearTiles(WorldProxy proxy)
    {
        foreach (TilePos tilePos ; ownedTiles) {
            Tile tile = Tile(TileTypeAir, TileFlags.valid, 0);
            proxy.setTile(tilePos, tile);
        }
        ownedTiles.length = 0;
    }

    private void makeTiles(WorldProxy proxy)
    {
        if (TreeManager().drawTiles == false) return;

        auto drawBranchId = TreeManager().drawBranchId;

        foreach(branch ; treelike.branches) {
            if (drawBranchId[branch.typeId]) {
                for (int b = 0; b < branch.nodes.length-1; b++) {
                    TilePos start = getTilePosOfNode(branch.nodes[b]);
                    TilePos end = getTilePosOfNode(branch.nodes[b+1]);

                    TilePos[] tilePosArray = getTilesBetween(proxy, start.value.convert!double, end.value.convert!double,
                                                             proxy.tileTypeManager.idByName(type.treelikeType.woodMaterial), proxy.tileTypeManager.idByName(type.treelikeType.leafMaterial));

                    for (int i = 0; i < tilePosArray.length; i++) {
                        Tile tile;
                        if (getThicknessOfNode(branch, branch.nodes[b+1], getBranchType(branch)) < THICKNESS_SCALE*1.0 &&
                            (proxy.getTile(tilePosArray[i]).type != proxy.tileTypeManager.idByName(type.treelikeType.woodMaterial))) {
                                auto tileType = proxy.tileTypeManager.byName(type.treelikeType.leafMaterial);
                                tile = Tile(tileType, TileFlags.valid);
                            }
                        else {
                            auto tileType = proxy.tileTypeManager.byName(type.treelikeType.woodMaterial);
                            tile = Tile(tileType, TileFlags.valid);
                        }

                        proxy.setTile(tilePosArray[i], tile);
                        ownedTiles ~= tilePosArray[i];
                    }
                }
            }
        }
    }



    //Returns all tile that are on the line between start and end
    //Turn into an opApply perchance?
    TilePos[] getTilesBetween(WorldProxy proxy, vec3d start, vec3d end, ushort acceptedTileType, ushort acceptedTileType2=0, int tileIter=255)
    {
        import util.tileiterator;

        start += vec3d(0.5, 0.5, 0.5);
        end += vec3d(0.5, 0.5, 0.5);
        TilePos[] output;
        vec3d dir = (end-start).normalizeThis();
        foreach(tilePos ; TileIterator(start, dir, tileIter)) {
            auto tile = proxy.getTile(tilePos);
            if (tile.type == TileTypeAir || tile.type == acceptedTileType || (acceptedTileType2 != 0 && tile.type == acceptedTileType2)) {
                output ~= tilePos;
            }
            else {
                return output;
            }
            if (tilePos.value.getDistanceSQ(end.convert!int) < 1.0) {
                return output;
            }
        }
        return output;
    }

    void makeLeafs(WorldProxy proxy)
    {
        import math.math;

        if (TreeManager().drawLeafs == false) return;
        auto drawBranchId = TreeManager().drawBranchId;

        leafRandom.seed(0);
        BranchType type;
        int radius;
        foreach (branch ; treelike.branches) {
            if (drawBranchId[branch.typeId]) {
                type = getBranchType(branch);
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
                                            TilePos tilePos = getTilePosOfNode(branch.nodes[i]);
                                            tilePos.value.x += x;
                                            tilePos.value.y += y;
                                            tilePos.value.z += z;
                                            auto tile = proxy.getTile(tilePos);
                                            if (tile.type == TileTypeAir) {
                                                auto tileType = proxy.tileTypeManager.byName(this.type.treelikeType.leafMaterial);
                                                Tile newTile = Tile(tileType, TileFlags.valid);
                                                proxy.setTile(tilePos, newTile);
                                                ownedTiles ~= tilePos;
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
                                            TilePos tilePos = getTilePosOfNode(branch.nodes[i]);
                                            tilePos.value.x += x;
                                            tilePos.value.y += y;
                                            tilePos.value.z += z;
                                            auto tile = proxy.getTile(tilePos);
                                            if (tile.type == TileTypeAir) {
                                                auto tileType = proxy.tileTypeManager.byName(this.type.treelikeType.leafMaterial);
                                                Tile newTile = Tile(tileType, TileFlags.valid);
                                                proxy.setTile(tilePos, newTile);
                                                ownedTiles ~= tilePos;
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

    private TilePos getTilePosOfNode(NodeInstance node)
    {
        vec3i v;

        v.x = node.pos[0];
        v.y = node.pos[1];
        v.z = node.pos[2];

        NodeInstance n = node;
        while (n.parentNode !is null) {
            n = n.parentNode;
            v.x += n.pos[0];
            v.y += n.pos[1];
            v.z += n.pos[2];
        }

        auto t = entityData.pos.tilePos;
        t.value.x += to!(int)(v.x/NODE_DISTANCE_SCALE);
        t.value.y += to!(int)(v.y/NODE_DISTANCE_SCALE);
        t.value.z += to!(int)(v.z/NODE_DISTANCE_SCALE);
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

        v.x = node.pos[0];
        v.y = node.pos[1];
        v.z = node.pos[2];

        NodeInstance n = node;
        while (n.parentNode !is null) {
            n = n.parentNode;
            v.x += n.pos[0];
            v.y += n.pos[1];
            v.z += n.pos[2];
        }

        v /= NODE_DISTANCE_SCALE;
        v.x += entityData.pos.tilePos().value.x + 0.5;
        v.y += entityData.pos.tilePos().value.y + 0.5;
        v.z += entityData.pos.tilePos().value.z + 0.5;
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



