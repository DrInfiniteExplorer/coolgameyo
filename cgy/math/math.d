module math.math;

import std.math;
import std.traits : isFloatingPoint, isIntegral;

immutable RadToDeg = 180.0 / std.math.PI;
immutable DegToRad = std.math.PI / 180.0;


bool equals(T, Y)(T a, Y b, T tolerance = cast(T)0.000001) {
    return abs(a-b) <= tolerance;
}


import math.vector;
import util.rangefromto : Range2D;

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

/*
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
*/

T clamp(T, Y, U)(T value, Y low, U high) {
    import std.algorithm : max, min;
	return min(max(value,cast(T)low), cast(T)high);
}


auto clampV(A)(const vector3!A wap, const vector3!(A) a, const vector3!(A) b){
    return vector3!A(clamp(wap.x, a.x, b.x), clamp(wap.y,a.y, b.y), clamp(wap.z, a.z, b.z));
}
auto clampV(A)(const vector2!A wap, const vector2!(A) a, const vector2!(A) b){
    return vector2!A(clamp(wap.x, a.x, b.x), clamp(wap.y,a.y, b.y));
}

auto snapV(A)(const vector3!A wap, const A b){
    return vector3!A(snap(wap.x, b), snap(wap.y,b), snap(wap.z, b));
}

auto snapV(A)(const vector2!A wap, const A b){
    return vector2!A(snap(wap.x, b), snap(wap.y,b));
}

auto negDivV(A)(const vector3!A wap, const A b){
    return vector3!A(negDiv(wap.x, b), negDiv(wap.y,b), negDiv(wap.z, b));
}
auto negDivV(A)(const vector2!A wap, const A b){
    return vector2!A(negDiv(wap.x, b), negDiv(wap.y,b));
}
auto posModV(A)(const vector3!A wap, const A b){
    return vector3!A(posMod(wap.x, b), posMod(wap.y,b), posMod(wap.z, b));
}
auto posModV(A)(const vec2!A wap, const vec2i b){
    return vector2!A(posMod( cast(int)wap.x, b.x), posMod(cast(int)wap.y,b.y));
}
auto posModV(A)(const vec2!A wap, const A b){
    return vector2!A(posMod(wap.x, b), posMod(wap.y,b));
}

vector2!T CircumCircle(T)(vector2!T a, vector2!T b, vector2!T c) {
    T tx = (a.x + c.x)/2;
    T ty = (a.y + c.y)/2;

    T vx = (b.x + c.x)/2;
    T vy = (b.y + c.y)/2;

    T ux,uy,wx,wy;

    if(a.x == c.x)
    {
        ux = 1;
        uy = 0;
    }
    else
    {
        ux = (c.y - a.y)/(a.x - c.x);
        uy = 1;
    }

    if(b.x == c.x)
    {
        wx = -1;
        wy = 0;
    }
    else
    {
        wx = (b.y - c.y)/(b.x - c.x);
        wy = -1;
    }

    T alpha = (wy*(vx-tx)-wx*(vy - ty))/(ux*wy-wx*uy);

    return vector2!T(tx+alpha*ux,ty+alpha*uy);
}

auto RungeKutta2(alias Func, T, D)(T value, D h) {
    auto k1 = Func(value) * h;
    auto k2 = Func(value + k1) * h;
    return value + 0.5 * (k1 + k2);
}
auto RungeKutta4(alias Func, T, D, int order = 4)(T value, D h) {
    auto k1 = Func(value) * h;
    auto k2 = Func(value + 0.5 * k1) * h;
    auto k3 = Func(value + 0.5 * k2) * h;
    auto k4 = Func(value + k3) * h;
    return value + 1.0/6.0 * (k1 + 2*k2 + 2*k3 + k4);
}

T trace(alias vectorField, T)(T pos, float time) {
    // Make more elaborate at a later time.
    //Like, detect if extreme velocities etc.
    pos = RungeKutta2!vectorField(pos, time);
    return pos;
}

void advect(Q, W, E)(Q vectorField, W get, E set, int sizeX, int sizeY, float time) {
    foreach(x, y ; Range2D(0, sizeX, 0, sizeY)) {
        auto startPos = vec2f(x, y) + vec2f(0.5);
        auto prevPos = trace!(vectorField, typeof(startPos))(startPos, -time);
        set(x, y, get(prevPos));
    }
}


