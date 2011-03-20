import engine.irrlicht;
import std.stdio;

import world : BlockSize = BlockSize, SectorSize = SectorSize;

alias vector2d!(int)	vec2i;
alias vector3d!(int)	vec3i;
alias vector3d!(float)	vec3f;
alias vector3d!(double) vec3d;


vector3d!(A) convert(A,B)(const vector3d!(B) wap){
    return vector3d!(A)( to!(A)(wap.X), to!(A)(wap.Y), to!(A)(wap.Z));
}



void setFlag(A,B)(ref A flags, B flag, bool value) {
    if (value) {
        val |= flag;
    } else {
        val &= ~flag;
    }
}

void BREAKPOINT() {
    asm { int 3; }
}

void* AllocateBlob(size_t size) {
    version (windows) { //For win32 evaluatar inte sant pa win64
        auto ret = VirtualAlloc(NULL, 4096 * size, MEM_COMMIT, PAGE_READWRITE); 
        return enforce(ret, "memory allocation fail :-)");
    } else version (posix) {
        void* ret;
        auto result = posix_memalign(&ret, 4096, 4096 * size);
        enforce (result == 0, "memory allocation fail :-)");
        return ret;
    }
}
void FreeBlob(void* blob) {
    version (windows) {
        VirtualFree(blob, 0, MEM_RELEASE);
    } else version (posix) {
        free(blob);
    }
}

vec3i[6] neighbors(vec3i pos) {
    vec3i[6] ret;
    ret[0] = pos + vec3i(0,0,1);
    ret[1] = pos - vec3i(0,0,1);
    ret[2] = pos + vec3i(0,1,0);
    ret[3] = pos - vec3i(0,1,0);
    ret[4] = pos + vec3i(1,0,0);
    ret[5] = pos - vec3i(1,0,0);
    return ret;
}

struct RangeFromTo
{
    int bx,ex,by,ey,bz,ez;
    int x,y,z;
    this(int beginX, int endX,
            int beginY, int endY,
            int beginZ, int endZ) {
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
        return x == ex && y == ey && z == ez;
    }
}
unittest {
    int[5][5][5] x;
    x[] = 0;
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

/* Snaps to multiples of b. See enforceions. */
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
    assert(Snap(-16,  8) == -16);
    assert(Snap( -9,  8) == -16);
    assert(Snap( -8,  8) == -8);
    assert(Snap( -1,  8) == -8);
    assert(Snap(  0,  8) == 0);
    assert(Snap(  7,  8) == 0);
    assert(Snap(  8,  8) == 8);
    assert(Snap( 15,  8) == 8);
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

/*  These functions are return a vector representing the  */
/*  index of the tile, relative to a <higher level> so that */
/*  the returned index can safely be used to find the <thing> */
/*  withing the <bigger thing>. Return values lie in the domain */
/*  [0, <bigger thing>_SIZE_?[  */
vec3i getBlockRelativeTileIndex(const vec3i tilePosition){

    return vec3i(
        PosMod(tilePosition.X, BlockSize.x),
        PosMod(tilePosition.Y, BlockSize.y),
        PosMod(tilePosition.Z, BlockSize.z)
        );
}
/*  See GetBlockRelativeTileIndex for description  */
vec3i getSectorRelativeBlockIndex(const vec3i tilePosition){
    return vec3i(
        PosMod(NegDiv(tilePosition.X, BlockSize.x), SectorSize.x),
        PosMod(NegDiv(tilePosition.Y, BlockSize.y), SectorSize.y),
        PosMod(NegDiv(tilePosition.Z, BlockSize.z), SectorSize.z)
      );
}






/*  Returns the position of the first tile in this block as  */
/*  world tile coordinates. It is where the block starts.  */
vec3i getBlockWorldPosition (const vec3i tilePosition){   
    return vec3i(
        Snap(tilePosition.X, BlockSize.x),
        Snap(tilePosition.Y, BlockSize.y),
        Snap(tilePosition.Z, BlockSize.z)
        );
}

/*  Returns a vector which corresponds to the sector number in the  */
/*  world that the tile belongs to. Can be (0, 0, 0) or (1, 5, -7). */
/*  See Util::Test for usage and stuff  */
vec3i getSectorNumber(const vec3i tilePosition){
    return vec3i(
        Snap(tilePosition.X, SectorSize.x)/SectorSize.x,
        Snap(tilePosition.Y, SectorSize.y)/SectorSize.y,
        Snap(tilePosition.Z, SectorSize.z)/SectorSize.z
        );
}



unittest {

    /*  Sector number tests  */
    assert(GetSectorNumber(vec3i(-TILES_PER_SECTOR_X,   -TILES_PER_SECTOR_Y , -TILES_PER_SECTOR_Z ))    == vec3i(-1, -1, -1));
    assert(GetSectorNumber(vec3i(-1,                    -1,                 -1))                        == vec3i(-1, -1, -1));
    assert(GetSectorNumber(vec3i(0,                     0,                  0))                         == vec3i( 0,  0,  0));
    assert(GetSectorNumber(vec3i(TILES_PER_SECTOR_X-1,  TILES_PER_SECTOR_Y-1, TILES_PER_SECTOR_Z-1))    == vec3i( 0,  0,  0));
    assert(GetSectorNumber(vec3i(TILES_PER_SECTOR_X  ,  TILES_PER_SECTOR_Y  , TILES_PER_SECTOR_Z  ))    == vec3i( 1,  1,  1));

    /*  tile index tests  */
    assert(GetBlockRelativeTileIndex(vec3i(-1, -1, -1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
    assert(GetBlockRelativeTileIndex(vec3i(TILES_PER_BLOCK_X-1,  TILES_PER_BLOCK_Y-1,  TILES_PER_BLOCK_Z-1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
    assert(GetBlockRelativeTileIndex(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
    assert(GetBlockRelativeTileIndex(vec3i( TILES_PER_BLOCK_X  ,  TILES_PER_BLOCK_Y  ,  TILES_PER_BLOCK_Z  )) == vec3i(0, 0, 0));


    /*  Block world position, where block start in world, tile-counted  */
    assert(GetBlockWorldPosition(vec3i(-1, -1, -1)) == vec3i(-TILES_PER_BLOCK_X, -TILES_PER_BLOCK_Y, -TILES_PER_BLOCK_Z));
    assert(GetBlockWorldPosition(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
    assert(GetBlockWorldPosition(vec3i( TILES_PER_BLOCK_X,  TILES_PER_BLOCK_Y,  TILES_PER_BLOCK_Z)) == vec3i(TILES_PER_BLOCK_X, TILES_PER_BLOCK_Y, TILES_PER_BLOCK_Z));

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
}



