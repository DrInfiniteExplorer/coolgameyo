import core.time, core.thread;
import std.container, std.concurrency, std.datetime;
import std.stdio, std.conv;
version(Windows) import std.c.windows.windows;

import world;
import util;

import modules;

struct Task {
    bool sync;
    bool syncsScheduler;
    void delegate(const World) run;
}

Task asyncTask(void delegate (const World) run) {
    return Task(false, false, run);
}
Task asyncTask(void delegate () run) {
    return Task(false, false, (const World){ run(); });
}
Task syncTask(void delegate (const World) run) {
    return Task(true, false, run);
}
Task syncTask(void delegate () run) {
    return Task(true, false, (const World){ run(); });
}

private Task sleepyTask(long usecs) {
    void asd(const World){
        //writeln("worker sleeping ", usecs, " usecs");
        Thread.sleep(dur!"usecs"(usecs));
    }
    return Task(false, false, &asd);
}

private Task syncTask() {
    return Task(true, true, null);
}



// THIS WILL PROBABLY NEED SOME FLESHING OUT...!!!
private void workerFun(shared Scheduler ssched) {
    try
    {
        auto sched = cast(Scheduler)ssched; // fuck the type system!
        setThreadName("Fun-worker thread");

        while (true) {
            // try to receive message?
            auto task = sched.getTask();
            task.run(sched.world);
        }
    }
    catch (Throwable o) // catch any uncaught exceptions
    {
        writeln("Thread exception!\n", o.toString());
        version(Windows) {
            MessageBoxA(null, cast(char *)o.toString(),
                    "Error", MB_OK | MB_ICONEXCLAMATION);
        }
    }
}

private long time() {
    return TickDuration.currSystemTick().usecs;
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
    long nextSync() @property const {
        return syncTime + (dur!"seconds"(1) / 30).total!"usecs"; // total???
    }


    private Task popAsync() {
        synchronized {
            if (async.empty) {
                state = State.async;
                return sleepyTask(nextSync - time());
            }
            return async.removeAny();
        }
    }

    this(World world_, int workerCount) {
        world = world_;
        sync = new Queue!Task;
        async = new Queue!Task;

        sync.insert(syncTask());

        foreach (x; 0 .. workerCount) {
            workers ~= spawn(&workerFun, cast(shared)this);
        }
        state = State.update;

        syncTime = time();
    }

    Task getTask() {
        synchronized {
            //writeln("scheduler state: ", to!string(state));
            switch (state) {
                case State.update:

                    //writeln("updating!");

                    syncTime = time();
                    world.update();
                    foreach (mod; modules) {
                        mod.update(world);
                    }

                    state = state.sync;

                    // fallin through...~~~~
                case State.sync:
                    auto t = sync.removeAny();

                    if (!t.syncsScheduler) return t;

                    state = State.forcedAsync;
                    asyncLeft = ASYNC_COUNT;
                    sync.insert(syncTask());
                    return getTask();

                case State.forcedAsync:
                    asyncLeft -= 1;
                    if (asyncLeft == 0) {
                        state = State.async;
                    }
                    return popAsync();

                case State.async:
                    if (time() > nextSync) {
                        state = State.update;
                        return getTask();
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
