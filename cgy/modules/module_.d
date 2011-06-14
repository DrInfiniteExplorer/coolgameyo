
module modules.module_;

public import scheduler;
public import world;

abstract class Module {
    void update(World world, Scheduler scheduler);
}



