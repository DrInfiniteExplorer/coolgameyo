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

struct PathFindingState {
    Path path;

    // scores, etc.

    PathFindingState(vec3i from, vec3i to);

    void tick();
    bool finished();
};

typedef int PathFindingID;

class PathModule : Module {
    static PathFindingID id_counter; // probably not thread safe D:

    std::map<PathFindingID, PathFindingState*> active_states;

    std::map<PathFindingID, Path> finished_paths;
public:
    PathFindingID findPath(vec3i from, vec3i to);

    // inserts the finished path into path and returns true if it is finished,
    // otherwise returns false
    bool poll(PathFindingID id, Path& path);

    void tick();
};


