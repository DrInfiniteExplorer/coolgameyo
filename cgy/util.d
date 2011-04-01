import std.conv;
import std.exception;
import std.stdio;

import world : BlockSize, SectorSize , GraphRegionSize;
import pos;
import stolen.all;

version (Posix) {
    import core.sys.posix.stdlib: posix_memalign;
    import std.c.stdlib;
}


alias vector2d!(int)	vec2i;
alias vector2d!(float)	vec2f;

alias vector3d!(int)	vec3i;
alias vector3d!(float)	vec3f;
alias vector3d!(double) vec3d;

vector3d!(A) convert(A,B)(const vector3d!(B) wap){
    return vector3d!A(to!A(wap.X), to!A(wap.Y), to!A(wap.Z));
}

void setFlag(A,B)(ref A flags, B flag, bool value) {
    if (value) {
        flags |= flag;
    } else {
        flags &= ~flag;
    }
}

void BREAKPOINT() {
    asm { int 3; }
}

void[] allocateBlob(size_t size) {
    version (Windows) { //For win32 evaluatar inte sant pa win64
        auto ret = VirtualAlloc(null, 4096 * size, MEM_COMMIT, PAGE_READWRITE); 
        auto tmp = enforce(ret[0 .. 4096*size], "memory allocation fail :-)");
        return tmp;
    } else version (Posix) {
        void* ret;
        auto result = posix_memalign(&ret, 4096, 4096 * size);
        enforce (result == 0, "memory allocation fail :-)");
        return ret[0 .. size];
    } else {
        static assert (0, "version?");
    }
}
void freeBlob(void* blob) {
    version (Windows) {
        VirtualFree(blob, 0, MEM_RELEASE);
    } else version (Posix) {
        free(blob);
    } else {
        static assert (0);
    }
}

unittest{
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    assert(si.dwPageSize == 4096);
}

TilePos[6] neighbors(TilePos tilePos) {
    TilePos[6] ret;
    ret[] = tilePos;
    ret[0].value += vec3i(0,0,1);
    ret[1].value -= vec3i(0,0,1);
    ret[2].value += vec3i(0,1,0);
    ret[3].value -= vec3i(0,1,0);
    ret[4].value += vec3i(1,0,0);
    ret[5].value -= vec3i(1,0,0);
    return ret;
}


struct RangeFromTo
{
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

    vec3i front() {
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
    bool empty() {
        return z >= ez; //Popfront is called before empty() and this smaller criteria is more sufficient and such.
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

/* Returns a/b rounded towards -inf instead of rounded towards 0 */
int negDiv(const int a, const int b)
in{
    assert(b >0);
}
body{
    static assert(15/8 == 1);
    static assert(8/8 == 1);

    static assert(7/8 == 0);
    static assert(0/8 == 0);

    static assert((-1-7)/8 == -1);
    static assert((-8-7)/8 == -1);

    static assert((-9-7)/8 == -2);

    if (a < 0) {
        return (a-b+1)/b;
    }
    return a/b;
}

unittest {
    assert(negDiv(15, 8) == 1);
    assert(negDiv( 8, 8) == 1);
    assert(negDiv( 7, 8) == 0);
    assert(negDiv( 0, 8) == 0);
    assert(negDiv(-1, 8) == -1);
    assert(negDiv(-8, 8) == -1);
    assert(negDiv(-9, 8) == -2);
}

/* snaps to multiples of b. See enforceions. */
int snap(const int a, const int b)
in{
    assert(b > 0);
}
body{
    static assert( (-16-7)-(-16-7)  % 8 ==  -16);
    static assert( (-9-7)-(-9-7)  % 8 ==  -16);

    static assert( (-8-7)-(-8-7)  % 8 ==  -8);
    static assert( (-1-7)-(-1-7)  % 8 ==  -8);

    static assert(  0- 0  % 8 ==  0);
    static assert(  7- 7  % 8 ==  0);

    static assert(  8- 8  % 8 ==  8);
    static assert( 15- 15 % 8 ==  8);

    if(a<0){
        auto x = a-b+1;
        return x - (x % b);
    }
    return a - a % b;
}

unittest {
    assert(snap(-16,  8) == -16);
    assert(snap( -9,  8) == -16);
    assert(snap( -8,  8) == -8);
    assert(snap( -1,  8) == -8);
    assert(snap(  0,  8) == 0);
    assert(snap(  7,  8) == 0);
    assert(snap(  8,  8) == 8);
    assert(snap( 15,  8) == 8);
}

int posMod(const int a, const int b){
    static assert( ((15 % 8)+8)%8 == 7);
    static assert(  ((8 % 8)+8)%8 == 0);

    static assert( ((7 % 8)+8)%8  == 7);
    static assert( ((0 % 8)+8)%8  == 0);

    static assert( ((-1 % 8)+8)%8  == 7);
    static assert( ((-8 % 8)+8)%8  == 0);

    static assert( ((-9 % 8)+8)%8  == 7);
    static assert( ((-16% 8)+8)%8  == 0);

    return ((a % b) + b) % b;
}

unittest {
    assert(posMod(-9, 8) == 7);
    assert(posMod(-8, 8) == 0);
    assert(posMod(-1, 8) == 7);
    assert(posMod( 0, 8) == 0);
    assert(posMod( 7, 8) == 7);
    assert(posMod( 8, 8) == 0);
}

//Removed stuff. Now lies in pos.d

class Queue(T) {
    struct Node {
        Node* next;
        T value;
        this(Node* n, T t) { next = n; value = t; }
    }
    Node* first, last;

    void insert(T t) {
        if (last is null) {
            last = new Node(null, t);
            first = last;
        } else {
            last.next = new Node(null, t);
            last = last.next;
        }
    }
    T removeAny() {
        enforce(!empty);
        T ret = first.value;
        
        first = first.next;
        if (first is null) last = null;

        return ret;
    }
    bool empty() @property const {
        return first is null;
    }
}

enum Direction{
    north = 1<<0,
    south = 1<<1,
    west  = 1<<2,
    east  = 1<<3,
    up    = 1<<4,
    down  = 1<<5,
    all   = north | up | west | down | south | east,
}


