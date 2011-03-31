import core.time, core.thread;
import std.container, std.concurrency, std.datetime;

import world;
import util;

struct Task {
    bool sync;
    bool syncsScheduler;
    void delegate(const World) run;
}

private Task sleepyTask(long hnsecs) {
    return Task(false, false, { Thread.sleep(dur!"hnsecs"(hnsecs)); });
}


// THIS WILL PROBABLY NEED SOME FLESHING OUT...!!!
private void workerFun(shared Scheduler ssched) {
    auto sched = cast(Scheduler)ssched; // fuck the type system!

    while (true) {
        // try to receive message?
        auto task = sched.getTask();
        task.run(sched.world);
    }
}

private long time() {
    return TickDuration.currSystemTick().hnsecs;
}

class Scheduler {
    enum State { update, sync, forcedAsync, async }
    enum ASYNC_COUNT = 23;

    World world;
    Module[] modules;

    Queue!Task sync, async;

    State state;

    Tid[] workers;

    long asyncLeft;

    long syncTime;
    long nextSync() @property const { return syncTime + 1000/30; }


    private Task popAsync() {
        synchronized {
            if (async.empty) {
                return sleepyTask(time() - syncTime);
            }
            return async.removeAny();
        }
    }

    this(World world_, int workerCount) {
        world = world_;
        sync = new Queue!Task;
        async = new Queue!Task;

        foreach (x; 0 .. workerCount) {
            workers ~= spawn(&workerFun, cast(shared)this);
        }
    }

    Task getTask() {
        synchronized {
            switch (state) {
                case State.update:

                    world.update();
                    foreach (mod; modules) {
                        mod.update(world);
                    }

                    state = state.sync;

                    // fallin through...~~~~
                case State.sync:
                    auto t = sync.removeAny();
                    if (t.syncsScheduler) {
                        state = State.forcedAsync;
                        asyncLeft = ASYNC_COUNT;
                    }
                    return t;

                case State.forcedAsync:
                    asyncLeft -= 1;
                    if (asyncLeft == 0) {
                        state = State.async;
                    } // fallin through..~~~
                case State.async:
                    if (time() > nextSync) {
                        state = State.update;
                        syncTime = time();
                    }
                    return popAsync();
            }
        }
    }

    void push(Task task) {
        synchronized {
            if (task.sync) {
                sync.insert(task);
            } else {
                async.insert(task);
            }
        }
    }
}

