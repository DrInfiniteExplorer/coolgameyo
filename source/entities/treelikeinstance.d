module entities.treelikeinstance;



__gshared int debugIdCounter = 0;
__gshared bool drawDebugLines = true;
__gshared bool drawTiles = true;
__gshared bool drawLeafs = true;
__gshared bool[10] drawBranchId = true;

class NodeInstance {
    struct Inner {
        int debugId;
        byte[3] pos; // Pos is relative to the previous node. realPos = pos / NODE_DISTANCE_SCALE
        ubyte nrOfChildBranches; // help variable. This could be calculated when needed instead of storing here.
        ubyte angleHorizontal; // realAngle = angleHorizontal * 2 * PI / 250
        ubyte angleVertical;
        ubyte nodeDistance;
    }
    Inner inner;
    alias inner this;
    NodeInstance parentNode;
}

class BranchInstance {
    struct Inner {
        ubyte typeId;
        ubyte nrOfNodesTarget;
        ubyte nodeDistanceTarget;
        ubyte thickness; // realThickness = thickness / THICKNESS_SCALE
        ubyte thicknessTarget; // this is the first node on the branch. All other nodes gets their thickness after cost payment
        ubyte branchesPerBranchTarget;
        ubyte nrOfChildBranches; // help variable. This could be calculated when needed instead of storing here.
    }
    Inner inner;
    alias inner this;
    NodeInstance[] nodes; // all nodes of this branch. The order in the array = the order in game.
    // nodes[0] is always stationary. It is the root node.
    NodeInstance parentNode;

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

    import changes.worldproxy;

    import cgy.util.tileiterator;

    TreelikeInstance treelike;


    int THICKNESS_SCALE = 16;
    int NODE_DISTANCE_SCALE = 4;

    Random gen;
    Random leafRandom;

    int cnt = 24;
    void treelikeTick(WorldProxy proxy) {
        if((cnt % 75) == 23) {
            growTree(proxy);
        }
        cnt++;

    }

    void serializeBinaryTreelike(BinaryWriter writer) {

        int nodeCount = 0;
        int[NodeInstance] nodeMap = [null : -1];
        NodeInstance[] nodes;
        foreach(branch ; treelike.branches) {
            foreach(node ; branch.nodes) {
                if(node in nodeMap) continue;
                nodeMap[node] = nodeCount;
                nodes ~= node;
                nodeCount++;
            }
        }

        writer.write(treelike.isAlive);
        writer.write(nodeCount);
        foreach(node ; nodes) {
            writer.write(node.inner);
            writer.write(nodeMap[node.parentNode]);
        }

        writer.write(treelike.branches.length.to!int);
        foreach(branch ; treelike.branches) {
            writer.write(branch.inner);
            writer.write(nodeMap[branch.parentNode]);
            writer.write(branch.nodes.length.to!int);
            foreach(node ; branch.nodes) {
                writer.write(nodeMap[node]);
            }
        }
    }
    void deserializeBinaryTreelike(BinaryReader reader) {
        reader.read(treelike.isAlive);

        int nodeCount = reader.read!int;
        NodeInstance[] nodes;
        nodes.length = nodeCount;
        foreach(idx ; 0 .. nodeCount) {
            nodes[idx] = new NodeInstance;
        }
        foreach(node ; nodes) {
            reader.read(node.inner);
            int id = reader.read!int;
            if(id != -1) {
                node.parentNode = nodes[id];
            }
        }

        auto branchCount = reader.read!int;
        treelike.branches.length = branchCount;
        foreach(ref branch ; treelike.branches) {
            branch = new BranchInstance;
            reader.read(branch.inner);
            int parentId = reader.read!int;
            if(parentId != -1) {
                branch.parentNode = nodes[parentId];
            }
            int myNodeCount = reader.read!int;
            branch.nodes.length = myNodeCount;
            foreach(ref node ; branch.nodes) {
                int id = reader.read!int;
                if(id != -1) {
                    node = nodes[id];
                }
            }
        }
    }

    public void createTreeLikeEntity(WorldProxy proxy, int iterations)
    {
        BREAK_IF(treelike is null);

        auto rootNode = new NodeInstance;
        rootNode.nodeDistance = 1;
        rootNode.debugId = debugIdCounter++;
        treelike.branches ~= createAndInitializeBranch(type.treelikeType.branches[0], rootNode);
        //tree.branches[0].nodes.insertInPlace(0, rootNode);

        clearTiles(proxy);
        makeTiles(proxy);
        makeLeafs(proxy);
        growTree(proxy, iterations);
    }

    public void growTree(WorldProxy proxy, int iterations = 1) {
        foreach (i; 0 .. iterations) {
            foreach (branch; treelike.branches) {
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

    private void newBranch(BranchInstance parentBranch) {
        //msg("newBranch()");
        if (parentBranch.nrOfChildBranches >= parentBranch.branchesPerBranchTarget) {
            return;
        }
        foreach (ref branchType; type.treelikeType.branches) {
            if (branchType.growsOn == parentBranch.typeId) {
                ubyte preferredNodePos = cast(ubyte)((parentBranch.nodes.length-1) * branchType.posOnParent);
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
        node.debugId = debugIdCounter++;
        node.pos[0] = cast(byte)(1 * sin(angleVertical) * cos(angleHorizontal));
        node.pos[1] = cast(byte)(1 * sin(angleVertical) * sin(angleHorizontal));
        node.pos[2] = cast(byte)(1 * cos(angleVertical));
        node.nodeDistance = 1;
        node.angleHorizontal = getAngleUByteFromFloat(angleHorizontal);
        node.angleVertical = getAngleUByteFromFloat(angleVertical);
        node.parentNode = parentNode;
        parentNode.nrOfChildBranches++;
        branch.nodes = [parentNode, node];

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
                    branch.nodes[i].pos[0] = cast(byte)(branch.nodes[i].nodeDistance * sin(angleVertical) * cos(angleHorizontal));
                    branch.nodes[i].pos[1] = cast(byte)(branch.nodes[i].nodeDistance * sin(angleVertical) * sin(angleHorizontal));
                    branch.nodes[i].pos[2] = cast(byte)(branch.nodes[i].nodeDistance * cos(angleVertical));
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

        ubyte preferredNodePos = cast(ubyte)(branch.nodes.length * branchType.newNodePos);
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
            node.debugId = .debugIdCounter++;

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
            node.pos[0] = cast(byte)(1 * sin(angleVertical) * cos(angleHorizontal));
            node.pos[1] = cast(byte)(1 * sin(angleVertical) * sin(angleHorizontal));
            node.pos[2] = cast(byte)(1 * cos(angleVertical));
            node.nodeDistance = 1;

            insertInPlace(branch.nodes, bestNodePos, node);

            //msg("Added node on ", cast(int)branch.typeId, " at pos ", cast(int)bestNodePos);
        }
    }

    private byte getDistanceOfNode(NodeInstance node)
    {
        return cast(byte)(sqrt(cast(real)(NODE_DISTANCE_SCALE * (node.pos[0]^^2) + NODE_DISTANCE_SCALE * (node.pos[2]^^2) + NODE_DISTANCE_SCALE * (node.pos[2]^^2))) / NODE_DISTANCE_SCALE );
    }

    private ubyte getAngleUByteFromFloat(float f)
    {
        if (f < 0.0f) f += 2.0f * PI;
        if (f > 2.0f * PI) f -= 2.0f * PI;
        return cast(ubyte)(f * 250.0f / (2.0f * PI));
    }
    private float getAngleFloatFromUbyte(ubyte b)
    {
        return (b * 2.0f * PI / 250.0f);
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
        foreach (TilePos tilePos; ownedTiles) {
            Tile tile = Tile(TileTypeAir, TileFlags.valid, 0);
            proxy.setTile(tilePos, tile);
        }
        ownedTiles.length = 0;
    }

    private void makeTiles(WorldProxy proxy) {
        if (!drawTiles) return;

        foreach (branch; treelike.branches) {
            if (drawBranchId[branch.typeId]) {
                for (int b = 0; b < branch.nodes.length-1; b++) {
                    TilePos start = getTilePosOfNode(branch.nodes[b]);
                    TilePos end = getTilePosOfNode(branch.nodes[b+1]);

                    TilePos[] tilePosArray = getTilesBetween(proxy, start.value.convert!double, end.value.convert!double,
                            tileTypeManager.idByName(type.treelikeType.woodMaterial), tileTypeManager.idByName(type.treelikeType.leafMaterial));

                    for (int i = 0; i < tilePosArray.length; i++) {
                        Tile tile;
                        if (getThicknessOfNode(branch, branch.nodes[b+1], getBranchType(branch)) < THICKNESS_SCALE*1.0 &&
                                (proxy.getTile(tilePosArray[i]).type != tileTypeManager.idByName(type.treelikeType.woodMaterial))) {
                            auto tileType = tileTypeManager.byName(type.treelikeType.leafMaterial);
                            tile = Tile(tileType, TileFlags.valid);
                        }
                        else {
                            auto tileType = tileTypeManager.byName(type.treelikeType.woodMaterial);
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
    TilePos[] getTilesBetween(WorldProxy proxy, vec3d start, vec3d end, ushort acceptedTileType, ushort acceptedTileType2=0, int tileIter=255) {

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
        import cgy.math.math;

        if (drawLeafs == false) return;

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
                                            auto tileType = tileTypeManager.byName(this.type.treelikeType.leafMaterial);
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
                                            auto tileType = tileTypeManager.byName(this.type.treelikeType.leafMaterial);
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
        if (a < lower) return cast(ubyte)(lower);
        if (a > upper) return cast(ubyte)(upper);
        return cast(ubyte)(a);
    }

    private float getThicknessOfNode(BranchInstance branch, NodeInstance node, BranchType type)
    {
        foreach (i; 0 .. branch.nodes.length) {
            if (branch.nodes[i] == node) {
                return branch.thickness - cast(ubyte)(cast(float)(THICKNESS_SCALE) * cast(float)(type.thicknessDistanceCost)) * i;
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
        t.value.x += cast(int)(v.x/NODE_DISTANCE_SCALE);
        t.value.y += cast(int)(v.y/NODE_DISTANCE_SCALE);
        t.value.z += cast(int)(v.z/NODE_DISTANCE_SCALE);
        return t;
    }

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
}



