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

    void tick(bool interrupted, PathModule blerp) {
        assert (false);
    }
}

