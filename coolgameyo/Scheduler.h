#pragma once

#include <functional>
#include <deque>

#include "include.h"
#include "World.h"

struct Task
{
    bool isAsync;
    bool syncs;
    std::function<void ()> tick;
    Task(bool isAsync, bool syncs, std::function<void ()> tick)
        : isAsync(isAsync), syncs(syncs), tick(tick)
    {
    }
    Task() {};
};


class Scheduler {
    enum State { s_sync, s_forced_async, s_async };
    enum { ASYNC_COUNT = 23 };

    State state;

    std::deque<Task> sync;
    std::deque<Task> async;

    World* world;
    ITimer* timer;

    int async_left;

    u32 sync_time;

    Task popAsync();
    Task popSync();
public:
    u32 timeToNextSync() const;
    Scheduler(World* world, ITimer* timer);
    Task getTask();
    void push(Task task);
};
