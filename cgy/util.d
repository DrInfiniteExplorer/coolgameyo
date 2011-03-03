import irrlicht;

alias IntVector3D vec3i;

struct Neighbors
{
    vec3i pos;
    vec3i lol[6];
    size_t i;
	
    this(vec3i me)
    {
		pos = me;
        lol[0] = me + vec3i(0,0,1);
        lol[1] = me - vec3i(0,0,1);
        lol[2] = me + vec3i(0,1,0);
        lol[3] = me - vec3i(0,1,0);
        lol[4] = me + vec3i(1,0,0);
        lol[5] = me - vec3i(1,0,0);
    }
    this(vec3i __pos, vec3i* wap, size_t __i)
    {
		pos = __pos;
		i = __i;
        memcpy(lol, wap, lol.sizeof);
    }

    Neighbors begin() { return Neighbors(pos, &lol[0], 0); }
    Neighbors end()   { return Neighbors(pos, &lol[0], 6); }
    vec3i operator * () const { return lol[i]; }
    bool operator == (const Neighbors other) const
    {
        return pos == other.pos && i == other.i;
    }
    bool operator != (const Neighbors other) const
    {
        return !(*this == other);
    }
    Neighbors& operator ++ ()
    {
        i += 1;
        return *this;
    }
};

struct RangeFromTo
{
    int bx,ex,by,ey,bz,ez;
    int x,y,z;
    RangeFromTo(int beginX, int endX,
        int beginY, int endY,
        int beginZ, int endZ)
        : bx(beginX), ex(endX), 
        by(beginY), ey(endY), 
        bz(beginZ), ez(endZ), 
        x(beginX), y(beginY), z(beginZ)
    { }
    RangeFromTo(int beginX, int endX,
        int beginY, int endY,
        int beginZ, int endZ,
        int x, int y, int z)
        : bx(beginX), ex(endX),
        by(beginY), ey(endY),
        bz(beginZ), ez(endZ),
        x(x), y(y), z(z)
    { }

    RangeFromTo begin() const { return RangeFromTo(bx,ex,by,ey,bz,ez,bx,by,bz); }
    RangeFromTo end()   const { return RangeFromTo(bx,ex,by,ey,bz,ez,bx,by,ez); }       
    vec3i operator * () const { return vec3i(x,y,z); }
    bool operator != (const RangeFromTo other) const
    {
        return x != other.x || y != other.y || z != other.z;
    }
    RangeFromTo& operator ++ ()
    {
        x += 1;
        if (x < ex) return *this; 
        x = bx;
        y += 1;
        if (y < ey) return *this;
        y = by;
        z += 1;
        return *this;
    }
};
/* Returns a/b rounded towards -inf instead of rounded towards 0 */
s32 NegDiv(const s32 a, const s32 b){
    static assert(15/8 == 1);
    static assert(8/8 == 1);

    static assert(7/8 == 0);
    static assert(0/8 == 0);

    static assert((-1-7)/8 == -1);
    static assert((-8-7)/8 == -1);

    static assert((-9-7)/8 == -2);

    enforce(b >0);

    if (a < 0) {
        return (a-b+1)/b;
    }
    return a/b;
}

/* Snaps to multiples of b. See enforceions. */
s32 Snap(const s32 a, const s32 b){
    static assert( (-16-7)-(-16-7)  % 8 ==  -16);
    static assert( (-9-7)-(-9-7)  % 8 ==  -16);

    static assert( (-8-7)-(-8-7)  % 8 ==  -8);
    static assert( (-1-7)-(-1-7)  % 8 ==  -8);

    static assert(  0- 0  % 8 ==  0);
    static assert(  7- 7  % 8 ==  0);

    static assert(  8- 8  % 8 ==  8);
    static assert( 15- 15 % 8 ==  8);

    enforce (b > 0);

    //return NegDiv(a,b) * b;

    if(a<0){
        auto x = a-b+1;
        return x - (x % b);
    }
    return a - a % b;
}

s32 PosMod_IF(const s32 a, const s32 b){
    static assert( 15 % 8 == 7);
    static assert(  8 % 8 == 0);

    static assert( 7 % 8  == 7);
    static assert( 0 % 8  == 0);

    static assert(7 +((1-1)%8) == 7);
    static assert(7 +((1-8)%8) == 0);

    static assert(7 +((1-9)%8) == 7);
    static assert(7 +((1-16)%8) == 0);

    if (a<0) {
       return b-1  +(1+a)%b;
    }
    return a%b;
}

s32 PosMod(const s32 a, const s32 b){
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

/*  These functions are return a vector representing the  */
/*  index of the tile, relative to a <higher level> so that */
/*  the returned index can safely be used to find the <thing> */
/*  withing the <bigger thing>. Return values lie in the domain */
/*  [0, <bigger thing>_SIZE_?[  */
vec3i GetBlockRelativeTileIndex(const vec3i tilePosition){

    return vec3i(
        PosMod(tilePosition.X, BLOCK_SIZE_X),
        PosMod(tilePosition.Y, BLOCK_SIZE_Y),
        PosMod(tilePosition.Z, BLOCK_SIZE_Z)
        );
}
/*  See GetBlockRelativeTileIndex for description  */
vec3i GetSectorRelativeBlockIndex(const vec3i tilePosition){
    return vec3i(
        PosMod(NegDiv(tilePosition.X, TILES_PER_BLOCK_X), SECTOR_SIZE_X),
        PosMod(NegDiv(tilePosition.Y, TILES_PER_BLOCK_Y), SECTOR_SIZE_Y),
        PosMod(NegDiv(tilePosition.Z, TILES_PER_BLOCK_Z), SECTOR_SIZE_Z)
      );
}






/*  Returns the position of the first tile in this block as  */
/*  world tile coordinates. It is where the block starts.  */
vec3i GetBlockWorldPosition (const vec3i tilePosition){   
    return vec3i(
        Snap(tilePosition.X, TILES_PER_BLOCK_X),
        Snap(tilePosition.Y, TILES_PER_BLOCK_Y),
        Snap(tilePosition.Z, TILES_PER_BLOCK_Z)
        );
}

/*  Returns a vector which corresponds to the sector number in the  */
/*  world that the tile belongs to. Can be (0, 0, 0) or (1, 5, -7). */
/*  See Util::Test for usage and stuff  */
vec3i GetSectorNumber(const vec3i tilePosition){
    return vec3i(
        Snap(tilePosition.X, TILES_PER_SECTOR_X)/TILES_PER_SECTOR_X,
        Snap(tilePosition.Y, TILES_PER_SECTOR_Y)/TILES_PER_SECTOR_Y,
        Snap(tilePosition.Z, TILES_PER_SECTOR_Z)/TILES_PER_SECTOR_Z
        );
}



void Test() {

    enforce(NegDiv(15, 8) == 1);
    enforce(NegDiv( 8, 8) == 1);
    enforce(NegDiv( 7, 8) == 0);
    enforce(NegDiv( 0, 8) == 0);
    enforce(NegDiv(-1, 8) == -1);
    enforce(NegDiv(-8, 8) == -1);
    enforce(NegDiv(-9, 8) == -2);

    //printf("%d\n\n\n", Snap(-16,  8));
    enforce(Snap(-16,  8) == -16);
    enforce(Snap( -9,  8) == -16);
    enforce(Snap( -8,  8) == -8);
    enforce(Snap( -1,  8) == -8);
    enforce(Snap(  0,  8) == 0);
    enforce(Snap(  7,  8) == 0);
    enforce(Snap(  8,  8) == 8);
    enforce(Snap( 15,  8) == 8);

    enforce(PosMod(-9, 8) == 7);
    enforce(PosMod(-8, 8) == 0);
    enforce(PosMod(-1, 8) == 7);
    enforce(PosMod( 0, 8) == 0);
    enforce(PosMod( 7, 8) == 7);
    enforce(PosMod( 8, 8) == 0);

    /*  Sector number tests  */
    enforce(GetSectorNumber(vec3i(-TILES_PER_SECTOR_X,   -TILES_PER_SECTOR_Y , -TILES_PER_SECTOR_Z ))    == vec3i(-1, -1, -1));
    enforce(GetSectorNumber(vec3i(-1,                    -1,                 -1))                        == vec3i(-1, -1, -1));
    enforce(GetSectorNumber(vec3i(0,                     0,                  0))                         == vec3i( 0,  0,  0));
    enforce(GetSectorNumber(vec3i(TILES_PER_SECTOR_X-1,  TILES_PER_SECTOR_Y-1, TILES_PER_SECTOR_Z-1))    == vec3i( 0,  0,  0));
    enforce(GetSectorNumber(vec3i(TILES_PER_SECTOR_X  ,  TILES_PER_SECTOR_Y  , TILES_PER_SECTOR_Z  ))    == vec3i( 1,  1,  1));

    /*  tile index tests  */
    enforce(GetBlockRelativeTileIndex(vec3i(-1, -1, -1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
    enforce(GetBlockRelativeTileIndex(vec3i(TILES_PER_BLOCK_X-1,  TILES_PER_BLOCK_Y-1,  TILES_PER_BLOCK_Z-1)) == vec3i(BLOCK_SIZE_X-1, BLOCK_SIZE_Y-1, BLOCK_SIZE_Z-1));
    enforce(GetBlockRelativeTileIndex(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
    enforce(GetBlockRelativeTileIndex(vec3i( TILES_PER_BLOCK_X  ,  TILES_PER_BLOCK_Y  ,  TILES_PER_BLOCK_Z  )) == vec3i(0, 0, 0));


    /*  Block world position, where block start in world, tile-counted  */
    enforce(GetBlockWorldPosition(vec3i(-1, -1, -1)) == vec3i(-TILES_PER_BLOCK_X, -TILES_PER_BLOCK_Y, -TILES_PER_BLOCK_Z));
    enforce(GetBlockWorldPosition(vec3i( 0,  0,  0)) == vec3i(0, 0, 0));
    enforce(GetBlockWorldPosition(vec3i( TILES_PER_BLOCK_X,  TILES_PER_BLOCK_Y,  TILES_PER_BLOCK_Z)) == vec3i(TILES_PER_BLOCK_X, TILES_PER_BLOCK_Y, TILES_PER_BLOCK_Z));



    int[5][5][5] x;
    memset(x,0,x.sizeof);
    RangeFromTo range(0,5,0,5,0,5);
    foreach (it, range) {
        auto p = *it;
        x[p.X][p.Y][p.Z] = 1;
    }
    auto xx = &x[0][0][0];
    for (int i = 0; i < (sizeof x/sizeof x[0]); i += 1) {
        int j = sizeof x;
        if (xx[i] != 1) {
            printf("Something terrible! %d\n", xx[i]);
            BREAKPOINT;
        }
    }
}


