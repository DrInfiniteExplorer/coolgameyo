module scheduler;

import core.time;
import core.thread;

import core.sync.mutex;

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

private Task syncTask() {
    return Task(true, true, null);
}

private void workerFun(shared Scheduler ssched, int id) {
    workerID = id;
    bool should_continue = true;
    thread_attachThis();
    auto sched = cast(Scheduler)ssched; // fuck the type system!
    setThreadName("Fun-worker thread");

    ChangeList changeList = new ChangeList;
    Task task;

    try {
        while (should_continue) {
            should_continue = sched.getTask(task, changeList);
            if (should_continue) {
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
    if (should_continue) {
        MessageBoxA(null, "A worker thread exited prematurely. Emergency application crash!", "And the world was on fire!", 0);
        std.c.stdlib.exit(1);
    }
}

class Scheduler {
    enum State { update, sync, forcedAsync, async, wait }
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

    int activeWorkers;

    long asyncLeft;

    long syncTime;
    long nextSync() @property const {
        return syncTime + (dur!"seconds"(1) / TICKS_PER_SECOND).total!"usecs";
    }

    Condition cond;

    this(World world_) {
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
        foreach (x; 1 .. workerCount) {
            workers ~= spawn(&workerFun, cast(shared)this, x);
        }

        syncTime = utime();
        tickWatch.start();
        workerFun(cast(shared)this, 0);
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
        synchronized (this) {
            return getTask_impl(task, changeList);
        }
    }

    private bool getTask_impl(ref Task task, ChangeList changeList) {
        switch (state) {
            default:
                assert (0);
            case State.wait:
                activeWorkers -= 1;

                if (activeWorkers > 0) {
                    if (exiting) {
                        bool pred(Tid t) {
                            return t == thisTid();
                        }
                        workers = remove!(pred)(workers);
                        return false;
                    } else {
                        cond.wait();
                        return getTask_impl(task, changeList);
                    }
                }
                auto timeLeft = nextSync - utime();
                if (timeLeft > 0) {
                    Thread.sleep(dur!"usecs"(timeLeft));
                }
                goto case; //Switch case falltrough, explicit.
            case State.update:
                assert (activeWorkers == 0);
                activeWorkers = workers.length;
                cond.notifyAll();

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
                return getTask_impl(task, changeList);

            case State.sync:
                auto t = sync.removeAny();

                if (!t.syncsScheduler) {
                    task = t;
                    return true;
                }

                state = State.forcedAsync;
                asyncLeft = ASYNC_COUNT;
                sync.insert(syncTask());
                return getTask_impl(task, changeList);

            case State.forcedAsync:
                asyncLeft -= 1;
                assert (asyncLeft >= 0);
                if (asyncLeft == 0 || async.empty) {
                    state = State.async;
                    return getTask_impl(task, changeList);
                }
                task = async.removeAny();
                return true;

            case State.async:
                if (utime() > nextSync || async.empty) {
                    state = State.wait;
                    return getTask_impl(task, changeList);
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
