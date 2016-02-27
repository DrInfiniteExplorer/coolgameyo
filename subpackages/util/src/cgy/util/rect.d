
module cgy.util.rect;

import std.conv;

import cgy.math.vector;

//import cgy.util.util;


struct Rect(T) {
    alias vector2!T vec;
    vec start;
    vec size;
    
    this(vec _start, vec _size){
        start = _start;
        size = _size;
    }
    
    this(T sx, T sy, T w, T h) {
        start.set(sx, sy);
        size.set(w,h);
    }

    Rect!To convert(To)() const @property {
        return Rect!To(
            start.convert!To,
            size.convert!To);
    }
        
    bool isInside(vector2!T pos) {
        return !(pos.x < start.x ||
            pos.x > start.x+size.x ||
            pos.y < start.y ||
            pos.y > start.y+size.y);
    }
    
    vec getRelative(vec pos){
        return vector2!T(
            (pos.x - start.x) / size.x,
            (pos.y - start.y) / size.y,
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
        auto tmp = vec( centerHorizontal ? newStart.x : toCenter.start.x,
                          centerVertical ? newStart.y : toCenter.start.y);
        return Rect!T(tmp, toCenter.size);
    }

/*
    Rect!T diff(int a, int b, int c, int d){
        return diff(vector2!T(a,b), vector2!T(c,d));
    }
*/
    Rect!T diff(vec dStart, vec dSize){
        return Rect!T(  start + dStart,
                      size - dStart + dSize);
    }
    Rect!T diff(T dStartX, T dStartY, T dSizeX, T dSizeY){
        
        return diff(vec(dStartX, dStartY), vec(dSizeX, dSizeY));
    }

    Rect!T pad(T width, T height) {
        return diff(-width / 2, -height / 2, width / 2, height / 2);
    }
    
    string toString() const {
        return text(typeof(this).stringof , "(" ,start.x ," ", start.y , ", ", size.x, " ", size.y, ")");
    }
    
    const bool opEquals(ref const(Rect!T) o) {
        return start == o.start && size == o.size;
    }
    
    T bottomOf() const {
        return start.y + size.y;
    }
    T topOf() const {
        return start.y;
    }
    T rightOf() const {
        return start.x + size.x;
    }
    T leftOf() const {
        return start.x;
    }
    T widthOf() const {
        return size.x;
    }
    T heightOf() const {
        return size.y;
    }
    vec topLeft() const {
        return start;
    }
    vec topRight() const {
        return start + vec(size.x, 0);
    }
    vec bottomRight() const {
        return start + size;
    }
    vec bottomLeft() const {
        return start + vec(0, size.y);
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

