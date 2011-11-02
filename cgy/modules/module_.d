
module modules.module_;

public import scheduler;
public import world.world;

abstract class Module {
    void update(World world, Scheduler scheduler);
    
    void serializeModule();
    void deserializeModule();
}



