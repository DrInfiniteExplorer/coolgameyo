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


