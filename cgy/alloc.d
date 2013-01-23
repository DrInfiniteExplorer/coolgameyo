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


void* temp_alloc_malloc(size_t s) {
    return temp_alloc(s).ptr;
}
void temp_alloc_free(void*) {} // nothing:D


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





// DO NOT PUT THINGS WHICH POINT TO GC HEAP HERE ^_^
struct AA(K,V, 
        alias malloc=std.c.stdlib.malloc, 
        alias free=std.c.stdlib.free) {
    static struct Node {
        Node* next;
        hash_t hash;
        K key;
        V val;
    }

    static Node* make_new_node(hash_t hash, K k, V v) {
        auto a = cast(Node*)malloc(Node.sizeof);
        a.next = null;
        a.hash = hash;
        a.key = k;
        a.val = v;
        return a;
    }



    static hash_t delegate(const void*) nothrow @trusted hash_func;
    
    Node*[] table;

    size_t size;

    void init(size_t estimatedSize) {
        if (hash_func is null) {
            hash_func = &typeid(K).getHash;
        }
        auto a = cast(Node**)malloc((Node*).sizeof * estimatedSize);
        assert (a !is null);
        table = a[0 .. estimatedSize];
        table[] = null;
    }

    void destroy() {
        foreach (node; table) {
            while (node) {
                auto node2 = node.next;
                free(node);
                node = node2;
            }
        }
        free(table.ptr);
        table = [];
    }

    void opIndexAssign(V v, K k) {
        auto hash = hash_func(&k);
        auto index = hash % table.length;
        if (table[index] is null) {
            table[index] = make_new_node(hash, k, v);
            size += 1;
        } else {
            auto node = table[index];
            while (true) {
                if (node.hash == hash && node.key == k) {
                    node.val = v;
                    break;
                }
                if (node.next is null) {
                    node.next = make_new_node(hash, k, v);
                    size += 1;
                    break;
                }
                node = node.next;
            }
        }
    }

    V opIndex(K k) {
        auto hash = hash_func(&k);
        auto index = hash % table.length;
        auto node = table[index];
        while (true) {
            assert (node !is null);
            if (node.hash == hash && node.key == k) {
                return node.val;
            }
            node = node.next;
        }
    }

    void remove(K k) {
        auto hash = hash_func(&k);
        auto index = hash % table.length;
        auto node = table[index];
        if (node.hash == hash && node.key == k) {
            table[index] = node.next;
        }
        while (node.next !is null) {
            if (node.next.hash == hash && node.next.key == k) {
                node.next = node.next.next;
            }
            node = node.next;
        }
    }
}


unittest {

    struct Foo {
        int x;
        int y;
    }

    while (true) {
        AA!(Foo, int, temp_alloc_malloc, temp_alloc_free) aa;

        aa.init(1024*1024);

        foreach (x; 0 .. 1024*4) {
            aa[Foo(2,x)] = x;
        }

        aa.destroy();
        reset_temp_alloc();
    }
}









