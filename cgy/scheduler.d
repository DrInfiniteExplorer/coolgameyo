import std.container;
interface Timer;


struct Task {
    bool async;
    bool syncsScheduler;
    void delegate() tick;
}

class Scheduler {
    enum State { sync, forcedAsync, async }
    enum ASYNC_COUNT = 23;

    State state;

    World world;
    Timer timer; //??

    int asyncLeft;

    uint syncTime;

    private Task popAsync() {
    }
    private Task popSync() {
    }

    uint timeToNextSync() const @property {
    }

    this(World world_, Timer timer_) {
        world = world_;
        timer = timer_;
    }

    Task getTask() {
    }

    void push(Task task) {
    }
}

