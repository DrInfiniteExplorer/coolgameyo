import core.time;

import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.range;

public import std.datetime;

//TODO: Got order-dependant bugs here. If doing pos, stolen, worldparts, then we get bugs and bugs. sadface.
import worldparts.sector;
import worldparts.block;
import stolen.all;
import pos;

version (Posix) {
    import core.sys.posix.stdlib: posix_memalign;
    import std.c.stdlib;
}

void msg(string file=__FILE__, int line=__LINE__, T...)(T t) {
    writeln(file, "(", line, "): ", t);
}

long utime() {
    return TickDuration.currSystemTick().usecs;
}

alias vector2d!(int)  vec2i;
alias vector2d!(float)  vec2f;
alias vector2d!(double)  vec2d;

alias vector3d!(int)  vec3i;
alias vector3d!(float)  vec3f;
alias vector3d!(double) vec3d;

alias aabbox3d!double aabbd;

vector3d!(A) convert(A,B)(const vector3d!(B) wap){
    return vector3d!A(to!A(wap.X), to!A(wap.Y), to!A(wap.Z));
}
vector2d!(A) convert(A,B)(const vector2d!(B) wap){
    return vector2d!A(to!A(wap.X), to!A(wap.Y));
}

Rect!A convert(A,B)(const Rect!B r) {
    return Rect!A(
        convert!A(r.start),
        convert!A(r.size)
    );
}

vec3i getTilePos(T)(vector3d!T v){
    return vec3i(
        to!int(floor(v.X)),
        to!int(floor(v.Y)),
        to!int(floor(v.Z))
    );
}

struct Rect(T) {
    vector2d!T start;
    vector2d!T size;
    
    this(vector2d!T _start, vector2d!T _size){
        start = _start;
        size = _size;
    }
    
    this(T sx, T sy, T w, T h) {
        start.set(sx, sy);
        size.set(w,h);
    }
        
    bool isInside(vector2d!T pos) {
        return !(pos.X < start.X ||
            pos.X > start.X+size.X ||
            pos.Y < start.Y ||
            pos.Y > start.Y+size.Y);
    }
    
    vector2d!T getRelative(vector2d!T pos){
        return vector2d!T(
            (pos.X - start.X) / size.X,
            (pos.Y - start.Y) / size.Y,
        );
    }
    
    //TODO: better name required for this. See unittests below. Derp.
    Rect getSubRect(Rect subPart){
        auto subStart = subPart.start * size;
        auto subSize = subPart.size * size;
        return Rect(start+subStart, subSize);
    }
    
    //TODO: More fitting name required. What it does: Maps for example two absolute coords into the local coords
    // of 'this' rect. Ie. (0.5, 0.5, 0.5, 0.5).subInv(0.5, 0.5, 0.25, 0.25) -> (0, 0, 0.5, 0.5)
    Rect getSubRectInv(Rect part){
        auto newSize = part.size / size;
        auto newStart = (part.start - start) / size;
        return Rect(newStart, newSize);
    }
    
    Rect!T centerRect(Rect!T toCenter, bool centerHorizontal = true, bool centerVertical = true) {
        auto newStart = start + (size - toCenter.size) / 2;
        auto tmp = vector2d!T( centerHorizontal ? newStart.X : start.X,
                          centerVertical ? newStart.Y : start.Y);
        return Rect!T(tmp, toCenter.size);
    }
    
    Rect!T diff(vector2d!T dStart, vector2d!T dSize){
        return Rect!T(  start + dStart,
                        size - dStart + dSize);
    }
        
    invariant() {
//        enforce(size.X >= 0, "Width of rect negative!!");
//        enforce(size.Y >= 0, "Height of rect negative!!");
    }
    
    string toString() const {
        return text(typeof(this).stringof , "(" ,start.X ," ", start.Y , ", ", size.X, " ", size.Y, ")");
    }
    
    const bool opEquals(ref const(Rect!T) o) {
        return start == o.start && size == o.size;
    }
}

alias Rect!double Rectd;
alias Rect!int Recti;

unittest{
    auto a = Rectd(vec2d(0, 0), vec2d(1, 1));
    auto b = Rectd(vec2d(0.25, 0.25), vec2d(0.5, 0.5));
    auto c = a.getSubRect(b); 
    auto d = b.getSubRect(a);
    auto e = b.getSubRect(b);
    auto f = Rectd(vec2d(0.375, 0.375), vec2d(0.25, 0.25));
    assert(c == b, "a.sub(b) != b");
    assert(d == b, "b.sub(a) != b");
    assert(e == f, "b.sub(b) != <svar> " ~ to!string(e));
    
    auto g = b.getSubRectInv(e);
    assert(g == b, "b.subInv(b.sub(b)) != b");
}


void setFlag(A,B)(ref A flags, B flag, bool value) {
    if (value) {
        flags |= flag;
    } else {
        flags &= ~flag;
    }
}

void BREAKPOINT(uint doBreak=1) {
    if(doBreak) {
        asm { int 3; }
    }
}

void ASSERT(uint dontBreak){
    BREAKPOINT(!dontBreak);
}

version(Windows){
//    import std.c.windows.windows;
//    import win32.windows : SYSTEM_INFO, GetSystemInfo, RaiseException; //Not available in std.c.windows.windows
    import win32.windows;
}


void[] allocateBlob(size_t size) {
    version (Windows) {
        auto ret = VirtualAlloc(null, 4096 * size, MEM_COMMIT, PAGE_READWRITE);
        auto tmp = enforce(ret[0 .. 4096*size], "memory allocation fail :-)");
        return tmp;
    } else version (Posix) {
        void* ret;
        auto result = posix_memalign(&ret, 4096, 4096 * size);
        enforce (result == 0, "memory allocation fail :-)");
        return ret[0 .. 4096 * size];
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

unittest {
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    assert(si.dwPageSize == 4096);
}

T[6] neighbors(T)(T t) {
    T[6] ret;
    ret[] = t;
    ret[0].value += vec3i(0,0,1);
    ret[1].value -= vec3i(0,0,1);
    ret[2].value += vec3i(0,1,0);
    ret[3].value -= vec3i(0,1,0);
    ret[4].value += vec3i(1,0,0);
    ret[5].value -= vec3i(1,0,0);
    return ret;
}


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


    static struct Range {
        Node* node;

        T front() @property {
            return node.value;
        }
        void popFront() {
            node = node.next;
        }
        bool empty() @property {
            return node is null;
        }
    }

    Range opSlice() { return Range(first); }
}

struct TileIterator{

    TilePos tile;
    vec3i dir;
    vec3d tMax;
    vec3d tDelta;
    int cnt;
    int maxIter;
    this(vec3d start, vec3d _dir, int limit = 1000) {
        maxIter = limit;
        tile.value = getTilePos(start);
        dir.X = _dir.X >= 0 ? 1 : -1;
        dir.Y = _dir.Y >= 0 ? 1 : -1;
        dir.Z = _dir.Z >= 0 ? 1 : -1;
                
        tDelta.X = abs(1.f / _dir.X);
        tDelta.Y = abs(1.f / _dir.Y);
        tDelta.Z = abs(1.f / _dir.Z);
        
        double inter(double start, int dir, double vel){
            auto func = vel >= 0 ? &floor : &ceil;
            float stop = func(start+to!double(dir));
            float dist = stop-start;
            return dist/vel;
        }
        
        tMax.X = inter(start.X, dir.X, _dir.X);
        tMax.Y = inter(start.Y, dir.Y, _dir.Y);
        tMax.Z = inter(start.Z, dir.Z, _dir.Z);
    }
    TilePos front() @property {
        return tile;
    }
    void popFront() {
        if (tMax.X < tMax.Y) {
            if (tMax.X < tMax.Z) {
                //INCREMENT X WOOO
                tile.value.X += dir.X;
                tMax.X += tDelta.X;
            } else {
                //INCREMENT Z WOOO
                tile.value.Z += dir.Z;
                tMax.Z += tDelta.Z;                
            }
        } else {
            if (tMax.Y < tMax.Z) {
                //INCREMENT Y WOOO
                tile.value.Y += dir.Y;
                tMax.Y += tDelta.Y;
            } else {
                //Increment Z WOOO
                tile.value.Z += dir.Z;
                tMax.Z += tDelta.Z;                
            }
        }
        cnt++;
    }
    bool empty() @property {
        return cnt > maxIter;
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




void setThreadName(string threadName) {
    version(Windows){
        //
        // Usage: SetThreadName (-1, "MainThread");
        //
        //#include <windows.h>
        uint MS_VC_EXCEPTION=0x406D1388;

        struct THREADNAME_INFO{
            align(8):
           uint dwType; // Must be 0x1000.
           char* szName; // Pointer to name (in user addr space).
           uint dwThreadID; // Thread ID (-1=caller thread).
           uint dwFlags; // Reserved for future use, must be zero.
        };

        //const char* name = toStringz(threadName);
        char* name = cast(char*)(threadName ~ "\0").ptr;

        THREADNAME_INFO info;
        info.dwType = 0x1000;
        info.szName = to!(char*)(name);
        info.dwThreadID = GetCurrentThreadId();
        info.dwFlags = 0;

        uint* ptr = cast(uint*)&info;

        try//__try
        {
            RaiseException( MS_VC_EXCEPTION, 0u, info.sizeof/ptr.sizeof, ptr );
        }
        catch(Throwable o) //__except(EXCEPTION_EXECUTE_HANDLER)
        {
            msg("asdasdasd");
        }
    }
}

version(Windows){
    /*import win32.windows : GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE,
        OpenClipboard, EmptyClipboard, SetClipboardData, CF_TEXT, CloseClipboard, GetClipboardData;
    */
    import win32.windows;

    void setCopyString(string str) {
        auto strZ = str.toStringz();
        DWORD len = str.length+1;
        HANDLE hMem =  GlobalAlloc(GMEM_MOVEABLE, len);
        memcpy(GlobalLock(hMem), strZ, len);
        GlobalUnlock(hMem);
        OpenClipboard(null);
        EmptyClipboard();
        SetClipboardData(CF_TEXT, hMem);
        CloseClipboard();    
    }

    bool getCopyString(ref string output) {
        const(char*) clip;
        if (OpenClipboard(null)) {
            HANDLE hData = GetClipboardData( CF_TEXT );
            char * buffer = cast(char*)GlobalLock( hData );
            output = to!string(buffer);
            GlobalUnlock( hData );
            CloseClipboard();
            return true;
        }
        return false;
    }

}

unittest{
    setCopyString("dix");
    string s;
    assert(getCopyString(s), "Could not get string from clipboard");
    assert(s == "dix", "Didn't get correct string from clipboard");
}
