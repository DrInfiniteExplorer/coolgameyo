
module util.math;

import stolen.vector2d;
import stolen.vector3d;

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

vector3d!(A) negDivV(A)(const vector3d!(A) wap, const A b){
    //return vector3d!A(to!A(negDiv(wap.X, b)), to!A(negDiv(wap.Y,b)), to!A(negDiv(wap.Z, b)));
    return vector3d!A(negDiv(wap.X, b), negDiv(wap.Y,b), negDiv(wap.Z, b));
}
vector2d!(A) negDivV(A)(const vector2d!(A) wap, const A b){
    //return vector3d!A(to!A(negDiv(wap.X, b)), to!A(negDiv(wap.Y,b)), to!A(negDiv(wap.Z, b)));
    return vector2d!A(negDiv(wap.X, b), negDiv(wap.Y,b));
}
vector3d!(A) posModV(A)(const vector3d!(A) wap, const A b){
    return vector3d!A(posMod(wap.X, b), posMod(wap.Y,b), posMod(wap.Z, b));
}
vector2d!(A) posModV(A)(const vector2d!(A) wap, const A b){
    return vector2d!A(posMod(wap.X, b), posMod(wap.Y,b));
}

