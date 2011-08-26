
module util.rangefromto;

import std.stdio;

import util.util;



struct RangeFromTo {
    int bx,ex,by,ey,bz,ez;
    int x,y,z;
    this(vec3i min, vec3i max){
        this(min.X, max.X,
             min.Y, max.Y,
             min.Z, max.Z);
    }

    this(int beginX, int endX,
            int beginY, int endY,
            int beginZ, int endZ)
    in{
        assert(endX>beginX);
        assert(endY>beginY);
        assert(endZ>beginZ);
    }
    body{
        x = bx = beginX;
        ex = endX;
        y = by = beginY;
        ey = endY;
        z = bz = beginZ;
        ez = endZ;
    }
    this(int beginX, int endX,
            int beginY, int endY,
            int beginZ, int endZ,
            int _x, int _y, int _z) {
        x = _x;
        bx = beginX;
        ex = endX;
        y = _y;
        by = beginY;
        ey = endY;
        z = _z;
        bz = beginZ;
        ez = endZ;
    }

    vec3i front() const {
        return vec3i(x, y, z);
    }
    void popFront() {
        x += 1;
        if (x < ex) return;
        x = bx;
        y += 1;
        if (y < ey) return;
        y = by;
        z += 1;
    }
    bool empty() const {
        return z >= ez;
    }
}
unittest {
    int[5][5][5] x;
    cast(int[])(x[0][0])[] = 0;
    foreach (p; RangeFromTo(0,5,0,5,0,5)) {
        x[p.X][p.Y][p.Z] = 1;
    }
    auto xx = &x[0][0][0];
    for (int i = 0; i < (x.sizeof / x[0].sizeof ); i += 1) {
        if (xx[i] != 1) {
            printf("Something terrible! %d\n", xx[i]);
            BREAKPOINT;
        }
    }
}
