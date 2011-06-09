import core.time;
import core.thread;

import std.exception;
import std.concurrency;
import std.conv;
import std.container;
import std.datetime;
import std.stdio;
import std.string;
import std.range;

version(Windows) import std.c.windows.windows;

import changelist;
import util;
import world;

import modules;

struct Task {
    bool sync;
    bool syncsScheduler;
    void delegate(const World, ChangeList changeList) run;
}

Task asyncTask(void delegate (const World) run) {
    return Task(false, false, (const World w, ChangeList changeList){run(w);});
}
Task asyncTask(void delegate () run) {
    return Task(false, false, (const World, ChangeList changeList){ run(); });
}

Task syncTask(void delegate (const World, ChangeList changeList) run) {
    return Task(true, false, run);
}
Task syncTask(void delegate (const World) run) {
    return Task(true, false, (const World w, ChangeList changeList){ run(w);});
}
Task syncTask(void delegate () run) {
    return Task(true, false, (const World, ChangeList changeList){ run(); });
}

private Task sleepyTask(long usecs) {
    enforce(usecs > 0 && usecs <= 1000000*15, "sleepyTask called with bad usec count:" ~to!string(usecs)); //Valid time and not more than 15 secs
    void asd(const World, ChangeList changeList){
        //writeln("worker sleeping ", usecs, " usecs");
        Thread.sleep(dur!"usecs"(usecs));
    }
    return Task(false, false, &asd);
}

private Task syncTask() {
    return Task(true, true, null);
}


enum TICKS_PER_SECOND = 15;

// THIS WILL PROBABLY NEED SOME FLESHING OUT...!!!
private void workerFun(shared Scheduler ssched) {
    try {
        auto sched = cast(Scheduler)ssched; // fuck the type system!
        setThreadName("Fun-worker thread");

        ChangeList changeList = new ChangeList;
        while (true) {
            // try to receive message?
            auto task = sched.getTask(changeList); //If scheduler syncs, this list is applied to the world.
            task.run(sched.world, changeList); //Fill changelist!!
        }
    } catch (Throwable o) {
        writeln("Thread exception!\n", o.toString());
        version(Windows) {
            MessageBoxA(null, cast(char *)toStringz(o.toString()),
                    "Error", MB_OK | MB_ICONEXCLAMATION);
        }
    }
}

class Scheduler {
    enum State { update, sync, forcedAsync, async }
    enum ASYNC_COUNT = 23;

    bool shouldSave;
    bool exiting;

    World world;
    Module[] modules;
    ChangeList changeList;

    Queue!Task sync, async;

    State state;

    Tid[] workers;

    long asyncLeft;

    long syncTime;
    long nextSync() @property const {
        return syncTime + (dur!"seconds"(1) / TICKS_PER_SECOND).total!"usecs"; // total???
    }


    //Parameter: see getTask
    private Task popAsync(ChangeList changeList) {
        synchronized(this) {
            if (async.empty) {
                state = State.async;
                auto usecs = nextSync - utime();
                if(usecs > 0){
                    return sleepyTask(usecs);
                }
                return getTask(changeList);
            }
            return async.removeAny();
        }
    }

    this(World world_) {
        world = world_;
        sync = new Queue!Task;
        async = new Queue!Task;

        sync.insert(syncTask());

        state = State.update;
    }

    void start(int workerCount=1) {
        foreach (x; 0 .. workerCount) {
            workers ~= spawn(&workerFun, cast(shared)this);
        }
        syncTime = utime();
    }


    void registerModule(Module mod) {
        synchronized(this){
            modules ~= mod;
        }
    }


    void serialize() {
        foreach (task; chain(sync[], async[])) {
            //task.writeTo(output);
        }
    }

    //If we synchronize threads, changelist is used and stuff. Otherwise it is ignored.
    Task getTask(ChangeList changeList) {
        synchronized(this) {
            //writeln("scheduler state: ", to!string(state));
            switch (state) {
                default:
                case State.update:

                    //writeln("updating!");
                    //TODO: Make threads wait and synchronize with each other before this phase!
                    //Important! :)

                    syncTime = utime();
                    changeList.apply(world);
                    world.update();
                    foreach (mod; modules) {
                        mod.update(world, this);
                    }
                    insertFrameTime();

                    if (shouldSave) {
                        world.serialize();
                        serialize();
                    }

                    state = state.sync;

                    // fallin through...~~~~
                case State.sync:
                    auto t = sync.removeAny();

                    if (!t.syncsScheduler) return t;

                    state = State.forcedAsync;
                    asyncLeft = ASYNC_COUNT;
                    sync.insert(syncTask());
                    return getTask(changeList);

                case State.forcedAsync:
                    asyncLeft -= 1;
                    if (asyncLeft == 0) {
                        state = State.async;
                    }
                    return popAsync(changeList);

                case State.async:
                    if (utime() > nextSync) {
                        state = State.update;
                        return getTask(changeList);
                    }
                    return popAsync(changeList);
            }
        }
    }

    void push(Task task) {
        synchronized(this) {
            if (task.sync) {
                sync.insert(task);
            } else {
                async.insert(task);
            }
        }
    }


    enum Frames = 3;
    long[Frames] frameTimes;
    long lastTime;
    ulong frameAvg;
    int frameId;
    void insertFrameTime(){
        long now = utime();
        long delta = now - lastTime;
        lastTime = now;
        frameTimes[frameId] = delta;
        frameId = (frameId+1)%Frames;
        frameAvg = 0;
        foreach(time ; frameTimes) {
            frameAvg += time;
        }
        frameAvg /= Frames;
    }

}
