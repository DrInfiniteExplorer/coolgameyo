module scheduler;

import core.time;
import core.thread;


import core.sync.mutex;
import core.sync.condition;

import core.cpuid;

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
import modules.network;
import util.util;
import util.queue;

import changes.worldproxy;
import game;

import alloc;

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
                       shared WorldProxy sproxy,
                       int id) {
    workerID = id;
    bool should_continue = true;
    thread_attachThis();
    auto sched = cast(Scheduler)ssched; // fuck the type system!
    setThreadName("Fun-worker thread");


    auto proxy = cast(WorldProxy)sproxy;
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
                    "Thread Error", MB_OK | MB_ICONEXCLAMATION);
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

    WorldProxy[] proxies;
    Tid[] workers;

    int activeWorkers;

    Game game;

    long asyncLeft;

    long syncTime;
    long nextSync() @property const {
        return syncTime + (dur!"seconds"(1) / TICKS_PER_SECOND).total!"usecs";
    }

    Condition cond;

    this(Game _game) {
        game = _game;
        world = game.getWorld();
        sync = new Queue!Task;
        async = new Queue!Task;

        sync.insert(syncTask());

        state = State.wait;

        cond = new Condition(new Mutex(this));

        proxies ~= enforce(cast(WorldProxy)world._worldProxy, "Uh nuh!");
    }

    void start(int workerCount=core.cpuid.threadsPerCPU) {
        msg("using ", workerCount, " workers");
        workerCount = 1;

        activeWorkers = workerCount;
        syncTime = utime();
        //workers ~= thisTid();
        //auto myProxy = new WorldProxy(world);
        //proxies ~= myProxy;
        foreach (x; 0 .. workerCount) {
            auto p = new WorldProxy(world);
            workers ~= spawn(&workerFun, cast(shared)this, cast(shared)p, x);
            proxies ~= p;
        }

        tickWatch.start();
        //workerFun(cast(shared)this, cast(shared)myProxy, 0);
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
            /*
            auto timeLeft = nextSync - utime();
            if (timeLeft > 0) {
                //Thread.sleep(dur!"usecs"(timeLeft));

            }*/
            //serverModule.doNetworkStuffUntil(nextSync);
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
        // this is the function that is the new tick in the world.

        if(g_isServer) {
            //Send the current changes.
            foreach (proxy; proxies) {
                game.pushNetworkChanges(proxy.changeList);
            }        
            game.doNetworkStuffUntil(nextSync);

            game.getNetworkChanges(proxies[0].changeList);
        } else {
            auto timeLeft = nextSync - utime();
            if (timeLeft > 0) {
                Thread.sleep(dur!"usecs"(timeLeft));
            }

        }
        //Apply the current changes.
        foreach (proxy; proxies) {
            proxy.changeList.apply(world);
        }

        reset_temp_alloc();

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

    //Starts a save of the game yeah~
    void saveGame() {
        shouldSerialize = true;
    }

    private void serialize() {
        game.serialize();
        foreach (task; chain(sync[], async[])) {
            //task.writeTo(output);
        }
        foreach (mod; modules) {
            mod.serializeModule();
        }
        shouldSerialize = false;
    }

    void deserialize() {
        world.deserialize();
        foreach (mod; modules) {
            mod.deserializeModule();
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
                        static void cleanUp(ref Tid[] workers) {
                            bool pred(Tid t) {
                                return t == thisTid();
                            }
                            workers = remove!(pred)(workers);
                        }
                        cleanUp(workers);
                        return false;
                    }
                    return getTask_impl(task, changeList, sw);
                }
                BREAK_IF(!alone());

                //Since was last alive, waited.
                //Now the waiting is happening in doUpdateShit -> network update shit. Yeah.
                //suspendMe(sw);

                BREAK_IF(!alone());

                state = State.update;

                return getTask_impl(task, changeList, sw);

            case State.update:

                BREAK_IF(!alone());

                syncTime = utime();

                doUpdateShit();

                /*
                if(TICK_LOL == 456) {
                    msg("Will now sleep forever");
                    activeWorkers++; //Enter the eternal slumber!
                    suspendMe(sw);
                }
                */


                TICK_LOL += 1;

                if (exiting) {
                    workers.length = 0;
                    return false;
                }

                state = state.sync;
                wakeWorkers();
                return getTask_impl(task, changeList, sw);

            case State.sync:
                auto t = sync.removeAny();
                msg(&t);

                //If synctask is only task, then will never return true.
                if (!t.syncsScheduler) {
                    task = t;
                    return true;
                }

                state = State.forcedAsync;
                asyncLeft = ASYNC_COUNT;
                push(syncTask({}));
                sync.insert(syncTask());
                return getTask_impl(task, changeList, sw);

            case State.forcedAsync:
                asyncLeft -= 1;
                BREAK_IF (asyncLeft < 0);
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
