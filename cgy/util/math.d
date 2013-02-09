
module util.math;

import stolen.vector2d;
import stolen.vector3d;

// Awesomely much faster than std.math.floor!
// Also seems to be correct!
auto fastFloor(T)(T val) {
    int ret = cast(int)val;
    return val < ret ? ret - 1 : ret;
}

unittest {
    import std.conv : to;
    import std.exception : enforce;
    import std.math : floor;
    foreach(i ; 0 .. 1000) {
        double d = (i-500) / 250.0;
        enforce(fastFloor(d) == floor(d), "error in fastFloor for " ~ to!string(d));
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

Type clamp(Type=double)(Type val, Type min, Type max)
in{
    assert(min <= max, "Min must be less than or equal to max!");
}
body {
    if(val < min) {
        return min;
    }
    if(val > max) {
        return max;
    }
    return val;
}

vector3d!(A) clampV(A)(const vector3d!(A) wap, const vector3d!(A) a, const vector3d!(A) b){
    return vector3d!A(clamp(wap.X, a.X, b.X), clamp(wap.Y,a.Y, b.Y), clamp(wap.Z, a.Z, b.Z));
}
vector2d!(A) clampV(A)(const vector2d!(A) wap, const vector2d!(A) a, const vector2d!(A) b){
    return vector2d!A(clamp(wap.X, a.X, b.X), clamp(wap.Y,a.Y, b.Y));
}

vector3d!(A) snapV(A)(const vector3d!(A) wap, const A b){
    return vector3d!A(snap(wap.X, b), snap(wap.Y,b), snap(wap.Z, b));
}

vector2d!(A) snapV(A)(const vector2d!(A) wap, const A b){
    return vector2d!A(snap(wap.X, b), snap(wap.Y,b));
}

vector3d!(A) negDivV(A)(const vector3d!(A) wap, const A b){
    return vector3d!A(negDiv(wap.X, b), negDiv(wap.Y,b), negDiv(wap.Z, b));
}
vector2d!(A) negDivV(A)(const vector2d!(A) wap, const A b){
    return vector2d!A(negDiv(wap.X, b), negDiv(wap.Y,b));
}
vector3d!(A) posModV(A)(const vector3d!(A) wap, const A b){
    return vector3d!A(posMod(wap.X, b), posMod(wap.Y,b), posMod(wap.Z, b));
}
vector2d!(A) posModV(A)(const vector2d!(A) wap, const A b){
    return vector2d!A(posMod(wap.X, b), posMod(wap.Y,b));
}

vector2d!T CircumCircle(T)(vector2d!T a, vector2d!T b, vector2d!T c) {
    T tx = (a.X + c.X)/2;
    T ty = (a.Y + c.Y)/2;

    T vx = (b.X + c.X)/2;
    T vy = (b.Y + c.Y)/2;

    T ux,uy,wx,wy;

    if(a.X == c.X)
    {
        ux = 1;
        uy = 0;
    }
    else
    {
        ux = (c.Y - a.Y)/(a.X - c.X);
        uy = 1;
    }

    if(b.X == c.X)
    {
        wx = -1;
        wy = 0;
    }
    else
    {
        wx = (b.Y - c.Y)/(b.X - c.X);
        wy = -1;
    }

    T alpha = (wy*(vx-tx)-wx*(vy - ty))/(ux*wy-wx*uy);

    return vector2d!T(tx+alpha*ux,ty+alpha*uy);
}
