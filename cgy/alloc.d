module alloc;

import std.stdio;
import core.atomic;
import std.c.stdlib;


void[] malloc2(size_t size) {
    auto a = malloc(size);
    if (a is null) assert (0, "no memmwry");
    return a[0 .. size];
}


__gshared void[] arena;
shared size_t current_offset;

void[] temp_alloc(size_t s) {
    auto wat = core.atomic.atomicOp!"+="(current_offset, s);

    if (wat > arena.length) {
        return new void[](s);
    }
    return arena[wat - s .. wat];
}


void init_temp_alloc(size_t initial_size) {
    arena = malloc2(initial_size);
}
void reset_temp_alloc() {
    if (current_offset > arena.length) {
        free(arena.ptr);
        auto x = arena.length;
        while(x <= current_offset) {
            x *= 2;
        }
        arena = malloc2(x);
    }

    atomicStore(current_offset, 0);
}






unittest {
    init_temp_alloc(256);
    auto ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    reset_temp_alloc();
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    reset_temp_alloc();
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
    ret = temp_alloc(100);
    writeln("ret = ", ret.ptr - arena.ptr);
}



