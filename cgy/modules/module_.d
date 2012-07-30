
module modules.module_;

public import scheduler;
public import worldstate.worldstate;

abstract class Module {
    void update(WorldState world, Scheduler scheduler);
    
    void serializeModule();
    void deserializeModule();
}



