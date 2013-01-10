module util.strings;

import std.format;
import std.array;

import util.array;
struct StringBuilder {

    void reserve(int startBuffer = 16) {
        _str.length = startBuffer;
    }

    Array!char _str;

    void put(E)(E e) {
        import util.util : BREAKPOINT;
        static if(is(E == dchar)) {
            BREAKPOINT;
        } else static if(is(E == dchar[])) {
            BREAKPOINT;
        } else static if(is(E == const(dchar))) {
            BREAKPOINT;
        } else static if(is(E == const(dchar)[])) {
            BREAKPOINT;
        } else {
            _str ~= e;
        }
    }


    void set(E)(E e) {
        clear();
        _str ~= cast(char[])e;
    }

    void clear() {
        _str.length = 0;
    }

    void write(T...)(T t) {
        _str.length = 0;
        //pragma(msg, "!" ~ typeof(t[0]).stringof);
        //pragma(msg, "!" ~ typeof(t[1]).stringof);
        formattedWrite!(typeof(&this), char)(&this, t);
    }

    immutable(string) str() @property {

        return cast(immutable)_str[];
    }

    auto opCall(T...)(T t) {
        write(t);
        return str;
    }

}
