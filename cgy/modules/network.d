
import modules.module_;



class NetworkModule : Module {
    ChangeList[] changes;
    override void update(WorldState world, Scheduler scheduler) {
        foreach (cl; changes) {
            cl.apply(world);
        }
        changes.length = 0;
    }
    
    override void serializeModule() {
    }
    override void deserializeModule() {
    }
}
