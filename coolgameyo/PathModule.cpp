
#include "PathModule.h"


static float heuristic(vec3i a, vec3i b) {
    return a.getDistanceFrom(b);
}
static float dist_between(vec3i a, vec3i b) {
    return heuristic(a,b);
}

vec3i PathFindingState::get_smallest()
{
    auto it = openset.begin();
    float smallest_f_score = f_score[*it];
    vec3i smallest = *it;

    for (++it; it != openset.end(); ++it) {
        if (f_score[*it] < smallest_f_score) {
            smallest_f_score = f_score[*it];
            smallest = *it;
        }
    }
    return smallest;
}
void PathFindingState::finish_up(vec3i x)
{
    auto push = [&](vec3i a) { path.nodes.push_back(a); };

    push(x);
    
    while (true) {
        auto it = came_from.find(x);

        if (it == came_from.end()) { break; }

        x = it->second;
        push(x);
    }
}

std::vector<vec3i> PathFindingState::neighbor_nodes(World* world, vec3i a)
{
    BREAKPOINT;
    std::vector<vec3i> ret;
    return ret;
}


PathFindingState::PathFindingState(vec3i from, vec3i to)
    : from(from), goal(to)
{
    openset.insert(from);
    g_score[from] = 0;
    f_score[from] = heuristic(from, to);
}
void PathFindingState::tick(World* world)
{
    // do a smallest possible step in the pathfinding algorithm, ish.

    if (openset.empty()) { // we failed, ish!
        _finished = true;
        return;
    }

    auto x = get_smallest();

    if (x == goal) {
        return finish_up(x);
    }

    closedset.insert(x);

    auto neighbors = neighbor_nodes(world, x);
    foreach (it, neighbors) {
        auto y = *it;

        auto tentative = g_score[x] + dist_between(x,y);

        auto inserted = openset.insert(y);

        bool was_inserted = inserted.second;
        bool tentative_is_better = was_inserted || tentative < g_score[y];

        if (tentative_is_better) {
            came_from[y] = x;
            g_score[y] = tentative;
            f_score[y] = tentative + heuristic(y, goal);
        }
    }
}
bool PathFindingState::finished()
{
    return _finished;
}









PathModule::PathModule(World* world)
    : Module(world)
{
}

PathFindingID PathModule::id_counter; // probably not thread safe D:


PathFindingID PathModule::findPath(vec3i from, vec3i to)
{
    auto id = ++id_counter;
    active_states[id] = new PathFindingState(from, to);
    return id;
}

bool PathModule::poll(PathFindingID id, Path& path)
{
    auto a = finished_paths.find(id);

    if (a == finished_paths.end()) { return false; }

    path.swap(a->second);

    finished_paths.erase(a);

    return true;
}

void PathModule::tick()
{
    foreach (it, active_states) {
        auto id = it->first;
        auto state = it->second;

        state->tick(world);

        if (state->finished()) {
            active_states.erase(it);

            finished_paths[id] = Path();

            state->path.swap(finished_paths[id]);

            delete state;
        }
    }
}

