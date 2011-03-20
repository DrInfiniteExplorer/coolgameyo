
struct vec3i {
    int X,Y,Z;
    vec3i opAdd(vec3i);
    vec3i opSub(vec3i);
    int opCmp(vec3i other);
}
struct vec2i {
    int X,Y;
}
vec3i toSectorPos(vec3i);
vec3i getSectorPos(vec3i);
vec3i getBlockWorldPosition(vec3i);
vec3i[6] neighbors(vec3i);
vec3i sectorPosToTilePos(vec3i);
vec3i getBlockPos(vec3i);

void setFlag(T)(T a, T b, bool b=true) {
    assert (0);
}


struct Range3D {
    int sx,ex,sy,ey,sz,ez;
    int x,y,z;
    this(int sx, int ex, int sy, int ey, int sz, int ez) {
        this.sx = sx;
        this.ex = ex;
        this.sy = sy;
        this.ey = ey;
        this.sz = sz;
        this.ez = ez;
        x = sx;
        y = sy;
        z = sz;
    }
    vec3i front() {
        return vec3i(x,y,z);
    }
    void popFront() {
        x += 1;
        if (x < ex) return;
        x = sx;
        y += 1;
        if (y < ey) return;
        y = sy;
        z += 1;
    }
    bool empty() {
        return z < ez;
    }
}

