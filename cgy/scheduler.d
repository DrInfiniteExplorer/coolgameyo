import core.time, core.thread;
import std.container, std.concurrency, std.datetime;

import world;

struct Task {
    bool sync;
    bool syncsScheduler;
    void delegate() run;
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
        task.run();
    }
}

private long time() {
    return TickDuration.currSystemTick().hnsecs;
}

class Scheduler {
    enum State { sync, forcedAsync, async }
    enum ASYNC_COUNT = 23;

    State state;

    Queue!Task sync, async;

    World world;

    long asyncLeft;

    long syncTime;
    long nextSync() @property const { return syncTime + 1000/30; }

    Tid[] workers;

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
                        state = State.sync;
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

