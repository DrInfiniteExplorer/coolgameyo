module scheduler;

import core.time;
import core.thread;


import core.sync.mutex;
import core.sync.condition;
import core.stdc.stdlib;

import core.cpuid;

import std.algorithm;
import std.exception;
import std.conv;
import std.datetime;
import std.stdio;
import std.string;
import std.range;

//version(Windows) import std.c.windows.windows;

public import changes.changelist;
import cgy.util.filesystem : copy;
import cgy.util.statistics;
import settings : g_maxThreadCount;

import cgy.debug_.debug_ : setThreadName;


import worldstate.time;
import worldstate.worldstate;

import modules.module_;
import network.all;
import cgy.util.util;
import cgy.util.queue;

import cgy.util.socket : readString, sendString;

import changes.worldproxy;
import game : game;

import alloc;

alias cgy.util.array.Array Array;

struct Task {
    void delegate(WorldProxy) run;
}

Task task(void delegate (WorldProxy) run) {
    return Task(run);
}
Task task(void delegate () run) {
    return Task(w => run());
}

static class KillWorker : Exception
{
    this(string str) { super(str); }
}


struct WorkerThreadContext {
    WorldProxy proxy;
    int threadId;
    this(WorldProxy p, int t) { 
        proxy = p; 
        threadId = t;
    }

    void run() {
        workerID = threadId;
        thread_attachThis();
        setThreadName("Worker thread %s".format(threadId));

        Task task;

        try {
            while(true) {
                task = scheduler.getTask();
                task.run(proxy); //Fill changelist!!
            }
        } catch(KillWorker e) {
            Log("Scheduler exception", e);
        } catch (Throwable t) {
            msg(t);
            version (Windows) {
                version (AnnoyingMessageBoxes) {
                    MessageBoxA(null, cast(char *)toStringz(to!string(t)),
                            "Thread Error", MB_OK | MB_ICONEXCLAMATION);
                }
            }
            msg("A worker thread exited prematurely. Emergency crash!");
            exit(1);
        }
    }
}

struct Scheduler {
    enum State { update, running, wait, apply }

    bool shouldSerialize;
    bool exiting;

    private StopWatch tickWatch;

    WorldState world;
    Module[] modules;
    ChangeList changeList;

    Array!Task current, for_next;
    size_t task_index;

    State state;

    WorldProxy[] proxies;
    Thread[] workers;

    int activeWorkers;

    Mutex mutex;
    Condition cond;

    long syncTime;
    long nextSync() @property const {
        return syncTime + (dur!"seconds"(1) / TICKS_PER_SECOND).total!"usecs";
    }
    @disable this(this);

    void init() {
        world = game.getWorld();

        state = State.wait;


        mutex = new Mutex();
        cond = new Condition(mutex);

        proxies ~= enforce(world._worldProxy);
    }

    void start(int workerCount) {
        msg("using ", workerCount, " workers");

        activeWorkers = workerCount;

        syncTime = utime();

        foreach (x; 0 .. workerCount) {
            auto p = new WorldProxy(world);
            auto context = new WorkerThreadContext(p, x);
            workers ~= spawnThread(&context.run);
            proxies ~= p;
        }

        tickWatch.start();
    }

    void exit() {
        exiting = true;
    }

    bool running() {
        bool alive = false;
        foreach (worker; workers) {
            if (worker.isRunning()) {
                alive = true;
            }
        }
        BREAK_IF(alive != (workers.length != 0));
        return workers.length != 0;
    }

    void registerModule(Module mod) {
        synchronized(mutex){
            modules ~= mod;
        }
    }

    void doUpdateShit() {
        // this is the function that is the new tick in the world.

        if(g_isServer) {
            //Send the current changes.
            foreach (proxy; proxies) {
                game.server.pushNetworkChanges(proxy.changeList);
            }
            game.server.pushNetworkChanges(game.commands.commandProxy.changeList);
            game.commands.commandProxy.changeList.reset();
            game.server.doNetworkStuffUntil(nextSync);
        } else {
            foreach (proxy; proxies) {
                if(proxy.changeList.changeListData.length != 0) {
                    BREAKPOINT;
                }
            }
            if(game.doneLoading) {
                if(game.activeUnit) {
                    import settings;
                    game.client.sendCommand(text("PlayerMove ", g_playerName, " ", game.activeUnitPos.value.x, " ",game.activeUnitPos.value.y, " ", game.activeUnitPos.value.z));
                }


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
                game.client.commSock.sendString("ProperlyConnected"); 
            }
        }
        //Apply the current changes.
        foreach (proxy; proxies) {
            proxy.changeList.apply(world);
        }
        if(g_isServer) {
            game.commands.commandProxy.changeList.applyNoReset(world);
        }

        reset_temp_alloc();


        world.update();
        foreach (mod; modules) {
            mod.update(world);
        }

        tickWatch.stop();
        g_Statistics.addTPS(tickWatch.peek().usecs);
        tickWatch.reset();
        tickWatch.start();

        if (shouldSerialize) {
            serialize();
        }
    }

    void saveGame() {
        shouldSerialize = true;
    }

    private void serialize() {
        Log("Saving world...");
        auto now = mstime();
        game.serialize();
        foreach (mod; modules) {
            mod.serializeModule();
        }
        BREAK_IF(!g_isServer);
        auto gameName = game.worldMap.worldSeed.to!string();
        copy(g_worldPath, "saves/" ~ gameName);

        shouldSerialize = false;
        while (game.sendingSaveGame) {
            msg("Fix proper thread communication for handling sending of games after sync.");
            Thread.sleep(dur!"seconds"(1));
        }
        Log("Done saving world");
        Log("Took ", mstime() - now, " ms");
    }

    void deserialize() {
        game.deserialize();
        foreach (mod; modules) {
            mod.deserializeModule();
        }
    }

    void push(Task task) {
        synchronized(mutex) {
            for_next.insert(task);
        }
    }

    Task getTask() {
        Task task;
        synchronized (mutex) {
            while(!getTask_impl(task)){}
            return task;
        }
    }

    private {
        void suspendMe() {
            activeWorkers -= 1;
            if (activeWorkers > 0) {
                cond.wait();
            }
            activeWorkers += 1;
        }

        bool alone() {
            return activeWorkers == 1;
        }

        void wakeWorkers() {
            cond.notifyAll();
        }

        bool getTask_impl(ref Task task) {

            switch (state) {
                default:
                    BREAKPOINT;
                    assert (0);
                case State.wait:

                    if (!alone()) {

                        suspendMe();

                        if (exiting) {
                            workers = workers.remove(workers.countUntil(Thread.getThis));
                        }
                        return false;
                    }
                    BREAK_IF(!alone());

                    state = State.update;

                    return false;

                case State.update:

                    BREAK_IF(!alone());

                    syncTime = utime();

                    doUpdateShit();

                    g_gameTick += 1;

                    if (exiting) {
                        workers.length = 0;
                        throw new KillWorker("Exiting");
                    }

                    current.length = 0;
                    swap(current, for_next);
                    task_index = 0;
                    state = state.running;
                    wakeWorkers();
                    return false;

                case State.running:

                    if (task_index < current.length) {
                        task = current[task_index];
                        task_index += 1;
                        return true;
                    } else {
                        state = state.wait;
                        return false;
                    }
            }
        }
    }
}
__gshared Scheduler scheduler;












