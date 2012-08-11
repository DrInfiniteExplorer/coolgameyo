module scheduler;

import core.time;
import core.thread;


import core.sync.mutex;
import core.sync.condition;

import std.cpuid;

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

import worldstate.time;
import worldstate.worldstate;

import modules.module_;
import util.util;
import util.queue;

import worldstate.worldproxy;

import changes.worldproxy;

struct Task {
    bool sync;
    bool syncsScheduler;
    void delegate(WorldProxy) run;
}

Task asyncTask(void delegate (WorldProxy) run) {
    return Task(false, false, run);
}
Task asyncTask(void delegate () run) {
    return Task(false, false, w => run());
}
Task syncTask(void delegate (WorldProxy) run) {
    return Task(true, false, run);
}
Task syncTask(void delegate () run) {
    return Task(true, false, w => run());
}


private Task syncTask() {
    return Task(true, true, null);
}

private void workerFun(shared Scheduler ssched,
                       shared WorldChangeListProxy sproxy,
                       int id) {
    workerID = id;
    bool should_continue = true;
    thread_attachThis();
    auto sched = cast(Scheduler)ssched; // fuck the type system!
    setThreadName("Fun-worker thread");


    auto proxy = cast(WorldChangeListProxy)sproxy;
    Task task;

    try {
        while (should_continue) {
            should_continue = sched.getTask(task, proxy.changeList);
            if (should_continue) {
                // try to receive message?
                //If scheduler syncs, this list is applied to the world.
                task.run(proxy); //Fill changelist!!
            }
        }
    } catch (Throwable o) {
        msg("Thread exception!\n", o.toString());
        version(Windows) {
            MessageBoxA(null, cast(char *)toStringz(o.toString()),
                    "Error", MB_OK | MB_ICONEXCLAMATION);
        }
    }
    if (should_continue) {
        MessageBoxA(null, "A worker thread exited prematurely. Emergency application crash!", "And the world was on fire!", 0);
        std.c.stdlib.exit(1);
    }
}

final class Scheduler {
    enum State { update, sync, forcedAsync, async, wait, apply }
    immutable ASYNC_COUNT = 23;

    bool shouldSerialize;
    bool exiting;
    
    private StopWatch tickWatch;

    WorldState world;
    Module[] modules;
    ChangeList changeList;

    Queue!Task sync, async;

    State state;

    WorldChangeListProxy[] proxies;
    Tid[] workers;

    int activeWorkers;

    long asyncLeft;

    long syncTime;
    long nextSync() @property const {
        return syncTime + (dur!"seconds"(1) / TICKS_PER_SECOND).total!"usecs";
    }

    Condition cond;

    this(WorldState world_) {
        world = world_;
        sync = new Queue!Task;
        async = new Queue!Task;

        sync.insert(syncTask());

        state = State.wait;

        cond = new Condition(new Mutex(this));
    }

    void start(int workerCount=core.cpuid.threadsPerCPU) {
        msg("using ", workerCount, " workers");
        activeWorkers = workerCount;

        workers ~= thisTid();
        auto myProxy = new WorldChangeListProxy(world);
        proxies ~= myProxy;
        foreach (x; 1 .. workerCount) {
            auto p = new WorldChangeListProxy(world);
            workers ~= spawn(&workerFun, cast(shared)this, cast(shared)p, x);
            proxies ~= p;
        }

        syncTime = utime();
        tickWatch.start();
        workerFun(cast(shared)this, cast(shared)myProxy, 0);
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

    bool getTask(ref Task task, ChangeList changeList) {
        StopWatch sw;
        sw.start();

        scope (exit) {
            sw.stop();
            g_Statistics.addGetTask(sw.peek().usecs);
        }

        synchronized (this) {
            return getTask_impl(task, changeList, sw);
        }
    }

    private void suspendMe(ref StopWatch sw) {
        sw.stop();

        activeWorkers -= 1;
        if (activeWorkers > 0) {
            cond.wait();
        } else {
            auto timeLeft = nextSync - utime();
            if (timeLeft > 0) {
                Thread.sleep(dur!"usecs"(timeLeft));
            }
        }
        activeWorkers += 1;
        
        sw.start();
    }

    private bool alone() {
        return activeWorkers == 1;
    }

    void wakeWorkers() {
        cond.notifyAll();
    }

    void doUpdateShit() {
        foreach (proxy; proxies) {
            proxy.changeList.apply(world);
        }

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
    }


    // this is so messy :(
    private bool getTask_impl(ref Task task, ChangeList changeList,
            ref StopWatch sw) {

        switch (state) {
            default:
                assert (0);
            case State.wait:

                if (!alone()) {

                    suspendMe(sw);

                    if (exiting) {
                        bool pred(Tid t) {
                            return t == thisTid();
                        }
                        workers = remove!(pred)(workers);
                        return false;
                    }
                    return getTask_impl(task, changeList, sw);
                }
                assert (alone());

                suspendMe(sw);

                assert (alone());

                state = State.update;

                return getTask_impl(task, changeList, sw);

            case State.update:

                assert (alone());

                syncTime = utime();

                doUpdateShit();

                wakeWorkers();

                TICK_LOL += 1;

                if (exiting) {
                    workers.length = 0;
                    return false;
                }

                state = state.sync;
                return getTask_impl(task, changeList, sw);

            case State.sync:
                auto t = sync.removeAny();

                if (!t.syncsScheduler) {
                    task = t;
                    return true;
                }

                state = State.forcedAsync;
                asyncLeft = ASYNC_COUNT;
                sync.insert(syncTask());
                return getTask_impl(task, changeList, sw);

            case State.forcedAsync:
                asyncLeft -= 1;
                assert (asyncLeft >= 0);
                if (asyncLeft == 0 || async.empty) {
                    state = State.async;
                    return getTask_impl(task, changeList, sw);
                }
                task = async.removeAny();
                return true;

            case State.async:
                if (utime() > nextSync || async.empty) {
                    state = State.wait;
                    return getTask_impl(task, changeList, sw);
                }
                task = async.removeAny();
                return true;
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
