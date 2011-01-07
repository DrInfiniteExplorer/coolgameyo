
#include "PathModule.h"

PathFindingState::PathFindingState(vec3i from, vec3i to)
{
    // initialize stuff!!~~
}
void PathFindingState::tick()
{
    // do a smallest possible step in the pathfinding algorithm, ish.
    // WOo!!!
}
bool PathFindingState::finished()
{
    return false;
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
    // foreach (id, state; active_states) WOULDN'T THAT BE COOL?!?!??
    for (auto it = active_states.begin(); it != active_states.end(); ++it) {
        auto id = it->first;
        auto state = it->second;

        state->tick();

        if (state->finished()) {
            active_states.erase(it);

            finished_paths[id] = Path();

            state->path.swap(finished_paths[id]);

            delete state;
        }
    }
}

