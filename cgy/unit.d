
import util;
import pos;

final class UnitType {
    string name;
    int x;
}

struct Unit {
    UnitType type;

    UnitPos pos;

    TilePos tilePosition() @property { return pos.getTilePos(); }
}

