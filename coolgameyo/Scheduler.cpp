

#include "Scheduler.h"

namespace {
    Task synchronizing_task() {
        return Task(true, true, 0);
    }
    Task sleepy_task(u32 t) {
        return Task(false, false, [t]() { Sleep(t); });
    }

}

Scheduler::Scheduler(World* world, ITimer* timer) 
    : state(s_sync), world(world), timer(timer), async_left(0)
{
    sync.push_back(synchronizing_task());
    sync_time = timer->getTime();
}

Task Scheduler::popAsync() {
    if (async.empty()) return sleepy_task(timeToNextSync());
    auto ret = async.front();
    async.pop_front();
    return ret;
}
Task Scheduler::popSync() {
    auto ret = sync.front();
    sync.pop_front();
    return ret;
}

u32 Scheduler::timeToNextSync() const {
    auto dt = timer->getTime() - sync_time;
    return max(1000/30 - dt, 0);
}

Task Scheduler::getTask()
{
    Task t;
    switch (state) {
    case s_sync:
        t = popSync();
        if (t.syncs) {
            state = s_forced_async;
            async_left = ASYNC_COUNT;
            sync.push_back(synchronizing_task());
            return getTask();
        } else {
            return t;
        }
        break;

    case s_forced_async:
        async_left -= 1;
        if (async_left == 0 || async.empty()) {
            async_left = 0;
            return sleepy_task(timeToNextSync());
        }
    case s_async:
        return popAsync();
        break;
    }
}
void Scheduler::push(Task task) {
    if (task.isAsync) {
        async.push_back(task);
    } else {
        sync.push_back(task);
    }
}
