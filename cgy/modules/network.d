
import modules.module_;











class NetworkModule : Module {
    ChangeList[] changes;
    void update(World world, Scheduler scheduler) {
        foreach (cl; changes) {
            cl.apply(world);
        }
        changes.length = 0;
    }
    
    void serializeModule() {
    }
    void deserializeModule() {
    }
}
