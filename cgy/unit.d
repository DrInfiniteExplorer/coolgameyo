
import util;
import pos;

struct Unit {
    vec3i pos;
    
    TilePos tilePosition() @property { return tilePos(pos); }
}

