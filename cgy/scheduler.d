module scheduler;

import core.time;
import core.thread;


import core.sync.mutex;
import core.sync.condition;

import core.cpuid;

import std.algorithm;
import std.exception;
import std.c.stdlib;
import std.conv;
import std.container;
import std.datetime;
import std.stdio;
import std.string;
import std.range;

version(Windows) import std.c.windows.windows;

public import changes.changelist;
import util.filesystem : copy;
import statistics;
import settings : g_maxThreadCount;

import worldstate.time;
import worldstate.worldstate;

import modules.module_;
import network.all;
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

private void workerFun(Scheduler sched,
                       WorldProxy proxy,
                       int id) {
    workerID = id;
    bool should_continue = true;
    thread_attachThis();
    //auto sched = cast(Scheduler)ssched; // fuck the type system!
    setThreadName("Fun-worker thread");


    //auto proxy = cast(WorldProxy)sproxy;
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
    } catch (Throwable t) {
        Log(t);
        Log(t.info);
        msg("Thread exception!\n", t);
        version(Windows) {
            MessageBoxA(null, cast(char *)toStringz(to!string(t)),
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
    Thread[] workers;

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

    void start(int workerCount=g_maxThreadCount) {
        msg("using ", workerCount, " workers");

        /*
        if(!g_isServer) {
            workerCount = 1;
        }
        */

        //workerCount = 1;

        activeWorkers = workerCount;


        syncTime = utime();
        //workers ~= thisTid();
        //auto myProxy = new WorldProxy(world);
        //proxies ~= myProxy;
        foreach (x; 0 .. workerCount) {
            auto p = new WorldProxy(world);
            struct ThreadContext {
                Scheduler scheduler;
                WorldProxy proxy;
                int threadId;
                this(Scheduler s, WorldProxy p, int t) { scheduler = s; proxy = p; threadId = t; }
                void run() {workerFun(scheduler, proxy, threadId);}
            }
            auto context = new ThreadContext(this, p, x);
            workers ~= spawnThread(&context.run);
            proxies ~= p;
        }

        tickWatch.start();
        //workerFun(cast(shared)this, cast(shared)myProxy, 0);
    }

    void exit() {
        exiting = true;
    }
    
    bool running() {
        bool alive = false;
        foreach(worker ; workers) {
            if(worker.isRunning()) {
                alive = true;
            }
        }
        BREAK_IF(alive != (workers.length != 0));
        return workers.length != 0;
    }
    
    void registerModule(Module mod) {
        synchronized(this){
            modules ~= mod;
        }
    }
    void unregisterModule(Module mod) {
        synchronized(this){
            modules = modules.remove(modules.countUntil(mod));
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
                game.server.pushNetworkChanges(proxy.changeList);
            }        
            game.server.doNetworkStuffUntil(nextSync);
        } else {
            if(game.doneLoading) {
                foreach (proxy; proxies) {
                    game.client.pushChanges(proxy.changeList);
                }
                game.client.pushChanges();
                game.client.doNetworkStuffUntil(nextSync);
                game.client.getNetworkChanges(proxies[0].changeList);
            } else {
                //If not done loading, but we get here, that means we have are actually done loading.
                game.doneLoading = true;
                auto err = game.dummyThread.join(false);
                if(err) {
                    Log("Caught error from client dummy thread: ", err.msg);
                }
                //Do one last dummy-read and then apply the stuff, and we will be in sync.
                game.client.getNetworkChanges(proxies[0].changeList);
                game.client.commSock.send("ProperlyConnected\n"); 
            }
        }
        //Apply the current changes.
        foreach (proxy; proxies) {
            proxy.changeList.apply(world);
        }

        reset_temp_alloc();

        //Clients apply whatever changes they get from the server immediately,
        // but the server applies the changes from the clients during the next tick.
        if(g_isServer) {
            game.server.getNetworkChanges(proxies[0].changeList);
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
        BREAK_IF(!g_isServer);
        auto gameName = game.worldMap.worldSeed.to!string();
        copy(g_worldPath, "saves/" ~ gameName); //Will keep old save until we exit deliberately or somehow else.


        shouldSerialize = false;
        while(game.sendingSaveGame){
            pragma(msg, "Fix proper thread communication for handling sending of games after sync.");
        }
    }

    void deserialize() {
        game.deserialize();
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
                        static void cleanUp(ref Thread[] workers) {
                            workers = workers.remove(workers.countUntil(Thread.getThis));
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


                g_gameTick += 1;

                if (exiting) {
                    workers.length = 0;
                    return false;
                }

                state = state.sync;
                wakeWorkers();
                return getTask_impl(task, changeList, sw);

            case State.sync:
                auto t = sync.removeAny();
                //msg(&t);

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
