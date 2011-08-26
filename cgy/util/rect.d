
module util.rect;

import std.conv;

import stolen.vector2d;

import util.util;

Rect!A convert(A,B)(const Rect!B r) {
    return Rect!A(
        util.util.convert!A(r.start),
        util.util.convert!A(r.size)
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
    
    Rect!T diff(int a, int b, int c, int d){
        return diff(vector2d!T(a,b), vector2d!T(c,d));
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
    
    T getBottom() const {
        return start.Y + size.Y;
    }
    T getTop() const {
        return start.Y;
    }
    T getRight() const {
        return start.X + size.X;
    }
    T getLeft() const {
        return start.X;
    }
    T getWidth() const {
        return size.X;
    }
    T getHeight() const {
        return size.Y;
    }
}

alias Rect!double Rectd;
alias Rect!float Rectf;
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

