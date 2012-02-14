module scheduler;

import core.time;
import core.thread;

import std.algorithm;
import std.exception;
import std.c.stdlib;
import std.concurrency;
import std.conv;
import std.container;
import std.datetime;
import std.stdio;
import std.string;
import std.range;

version(Windows) import std.c.windows.windows;

public import changes.changelist;
import statistics;

import world.time;
import world.world;

import modules.module_;
import util.util;
import util.queue;

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
        //msg("worker sleeping ", usecs, " usecs");
        Thread.sleep(dur!"usecs"(usecs));
    }
    return Task(false, false, &asd);
}

private Task syncTask() {
    return Task(true, true, null);
}


// THIS WILL PROBABLY NEED SOME FLESHING OUT...!!!
private void workerFun(shared Scheduler ssched) {
    bool exit;
    try {
        thread_attachThis();
        auto sched = cast(Scheduler)ssched; // fuck the type system!
        setThreadName("Fun-worker thread");

        ChangeList changeList = new ChangeList;
        Task task;
        while (!exit) {
            exit = !sched.getTask(task, changeList);
            if(!exit) {
                // try to receive message?
                //If scheduler syncs, this list is applied to the world.
                task.run(sched.world, changeList); //Fill changelist!!
            }
        }
    } catch (Throwable o) {
        msg("Thread exception!\n", o.toString());
        version(Windows) {
            MessageBoxA(null, cast(char *)toStringz(o.toString()),
                    "Error", MB_OK | MB_ICONEXCLAMATION);
        }
    }
    if (!exit) {
        MessageBoxA(null, "A worker thread exited prematurely. Emergency application crash!", "And the world was on fire!", 0);
        std.c.stdlib.exit(1);
    }
}

class Scheduler {
    enum State { update, sync, forcedAsync, async }
    enum ASYNC_COUNT = 23;

    bool shouldSerialize;
    bool exiting;
    
    private StopWatch tickWatch;

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

    private Task popAsync(ChangeList changeList) {
        synchronized(this) {
            if (async.empty) {
                state = State.async;
                auto usecs = nextSync - utime();
                if(usecs > 0){
                    return sleepyTask(usecs);
                }
                Task t;
                getTask(t, changeList);
                return t;
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
        workerCount--;
        foreach (x; 0 .. workerCount) {
            workers ~= spawn(&workerFun, cast(shared)this);
        }
        workers ~= thisTid();
        syncTime = utime();
        tickWatch.start();
        workerFun(cast(shared)this);
    }

    void exit() {
        exiting = true;
    }
    
    bool running() {
        return workers.length != 0;
    }
    
    void registerModule(Module mod) {
        synchronized(this){
            modules ~= mod;
        }
    }
    void unregisterModule(Module mod) {
        synchronized(this){
            bool pred(Module m) {
                return m == mod;
            }
            modules = remove!(pred)(modules);
        }
    }


    void delegate() whenSerialized;
    void startSerialize(void delegate() whenDone) {
        whenSerialized = whenDone;
        shouldSerialize = true;
    }

    private void serialize() {
        world.serialize();
        foreach (task; chain(sync[], async[])) {
            //task.writeTo(output);
        }
        foreach (mod; modules) {
            mod.serializeModule();
        }
        if (whenSerialized !is null) {
            whenSerialized();
        }
        shouldSerialize = false;
    }
    
    void deserialize() {
        world.deserialize();
        foreach (mod; modules) {
            mod.deserializeModule();
        }
    }

    //If we synchronize threads, changelist is used and stuff. Otherwise it is ignored.
    bool getTask(ref Task task, ChangeList changeList) {
        synchronized(this) {
            //msg("scheduler state: ", to!string(state));
            switch (state) {
                default:
                case State.update:
                    if(exiting) {
                        if (workers.length > 1){
                            bool pred(Tid t){
                                return t == thisTid();
                            }
                            workers = remove!(pred)(workers);
                            return false;
                        }
                        //Close all but last thread here. Last threads exits a bit down, in update, after potential save.
                    }
                    if(workers.length > 1){
                        //TODO: Wait for all workers here. Synchronize. Etc. :)
                    }

                    //msg("updating!");
                    //TODO: Make threads wait and synchronize with each other before this phase!
                    //Important! :)

                    syncTime = utime();
                    changeList.apply(world);
                    world.update(this);
                    foreach (mod; modules) {
                        mod.update(world, this);
                    }
                    tickWatch.stop();
                    g_Statistics.addTPS(tickWatch.peek().usecs);
                    tickWatch.reset();
                    tickWatch.start();

                    if (shouldSerialize) {
                        serialize();
                    }
                    
                    if(exiting){
                        workers.length = 0;
                        return false;
                    }
                    
                    state = state.sync;
                    goto case;

                    // fallin through...~~~~
                case State.sync:
                    auto t = sync.removeAny();

                    if (!t.syncsScheduler) {
                        task = t;
                        return true;
                    }

                    state = State.forcedAsync;
                    asyncLeft = ASYNC_COUNT;
                    sync.insert(syncTask());
                    return getTask(task, changeList);
                    

                case State.forcedAsync:
                    asyncLeft -= 1;
                    if (asyncLeft == 0) {
                        state = State.async;
                    }
                    task = popAsync(changeList);
                    return true;

                case State.async:
                    if (utime() > nextSync) {
                        state = State.update;
                        return getTask(task, changeList);
                    }
                    task = popAsync(changeList);
                    return true;
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
}
