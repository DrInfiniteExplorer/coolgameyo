import modules;
import util;
import pos;

final class UnitType {
    string name;
    int x;
}

struct Unit {
    UnitType type;

    UnitPos pos;

    bool panics;

    void tick(int ticksLeft, PathModule blerp) {
        if (ticksLeft > 0) { // Was interrupted!!!!!!!
            assert (0);
        } else if (ticksLeft < 0) { // Back from some movement or shit
            assert (1 == 3);
        }
            

        assert (false);
    }
}

