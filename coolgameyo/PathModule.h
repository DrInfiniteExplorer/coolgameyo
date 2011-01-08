#pragma once


#include "include.h"
#include "Module.h"

struct Path {
    std::vector<vec3i> nodes;

    Path() {}
    void swap(Path& other) {
        nodes.swap(other.nodes);
    }
};

class PathFindingState {

    vec3i from, goal;

    std::set<vec3i> openset;
    std::set<vec3i> closedset;
    std::map<vec3i, vec3i> came_from;

    std::map<vec3i, float> g_score;
    std::map<vec3i, float> f_score;

    bool _finished; // i dunno D:

    vec3i get_smallest();
    void finish_up(vec3i x);
    std::vector<vec3i> neighbor_nodes(World* world, vec3i a);

public:

    Path* path;

    PathFindingState(vec3i from, vec3i to);

    void tick(World* world);
    bool finished();
};

typedef int PathFindingID;

class PathModule : public Module {
    // DOESN'T C++0X INCLUDE ATOMIC STUFF FOR STUFF LIKE THIS???????
    static PathFindingID id_counter; // probably not thread safe D:

    std::map<PathFindingID, PathFindingState*> active_states;

    std::map<PathFindingID, Path*> finished_paths;
public:

    PathModule(World* world);

    PathFindingID findPath(vec3i from, vec3i to);

    // inserts the finished path into path and returns true if it is finished,
    // otherwise returns false
    bool poll(PathFindingID id, Path*& path);

    void tick();
};


