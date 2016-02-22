
module modules.module_;

public import scheduler;
public import worldstate.worldstate;

abstract class Module {
    void update(WorldState world);
    
    void serializeModule();
    void deserializeModule();
}



