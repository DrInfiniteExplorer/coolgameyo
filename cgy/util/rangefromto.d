
module util.rangefromto;

import std.stdio;

import util.util;

struct Range2D {
    int bx,ex,by,ey;
    int x,y;
    this(vec2i min, vec2i max){
        this(min.X, max.X,
             min.Y, max.Y);
    }

    //TODO: Recode this and all that uses this, so that it follows the convention of the one above which is more sensemakeing
    // and more often used.
    this(int beginX, int endX,
         int beginY, int endY)
    in{
        assert(endX>=beginX);
        assert(endY>=beginY);
    }
    body{
        x = bx = beginX;
        ex = endX;
        y = by = beginY;
        ey = endY;
    }
    this(int beginX, int endX,
         int beginY, int endY,
         int _x, int _y) {
             x = _x;
             bx = beginX;
             ex = endX;
             y = _y;
             by = beginY;
             ey = endY;
         }

    int opApply(scope int delegate(int x, int y) Do) {
        int ret;
        while(y < ey) {
            ret = Do(x, y);
            if(ret) break;
            x++;
            if(x >= ex) {
                x = bx;
                y++;
            }
        }
        return ret;
    }

}

struct RangeFromTo {
    int bx,ex,by,ey,bz,ez;
    int x,y,z;
    this(vec3i min, vec3i max){
        this(min.X, max.X,
             min.Y, max.Y,
             min.Z, max.Z);
    }

    //TODO: Recode this and all that uses this, so that it follows the convention of the one above which is more sensemakeing
    // and more often used.
    this(int beginX, int endX,
            int beginY, int endY,
            int beginZ, int endZ)
    in{
        assert(endX>=beginX);
        assert(endY>=beginY);
        assert(endZ>=beginZ);
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
        if (x <= ex) return;
        x = bx;
        y += 1;
        if (y <= ey) return;
        y = by;
        z += 1;
    }
    bool empty() const {
        return z > ez;
    }
}
unittest {
    int[5][5][5] x;
    cast(int[])(x[0][0])[] = 0;
    foreach (p; RangeFromTo (0,4,0,4,0,4)) {
        x[p.Z][p.Y][p.X] = 1;
    }
    auto xx = &x[0][0][0];
    for (int i = 0; i < (x.sizeof / x[0].sizeof ); i += 1) {
        if (xx[i] != 1) {
            printf("Something terrible! %d\n", xx[i]);
            BREAKPOINT;
        }
    }
}
