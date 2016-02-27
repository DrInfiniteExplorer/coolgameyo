module cgy.util.array;

//An array class that wraps a dynamic array
// When grown (with insert only!) allocates more memory
// When shrunk (with length, reset, removeAny, removeFromEnd) doesn't 
//  deallocate memory, and no assumeSafeAppend is needed because
//  the actuall storage array never shrank.

import std.algorithm : countUntil;
import std.traits;

// Unsafe to initialize a binaryheap with an instance of this; does a bitblit, 
// so the storage is shared but the virtualLength is different, etc.

private mixin template ArrayFunctionality(T) {

    alias typeof(this) ThisType;
    T[] storage;

    private size_t virtualLength;

    private size_t findFittingSize(size_t atLeast) {
        size_t now = storage.length;
        while(now < atLeast) {
            now = (now + 1) * 2 - 1;
        }
        return now;
    }

    private void grow(size_t newSize) {
        if(newSize <= storage.length) return;
        storage.length = newSize;
    }

    ref T back() @property {
        return storage[virtualLength-1];
    }

    ThisType dup() @property {
        assert (0);
    }

    bool empty() @property const { return virtualLength==0; }

    ref T front() @property {
        return storage[0];
    }

    alias insert insertBack;
    size_t insert(T)(T t) {
        //pragma(msg, typeof(t));
        static if(isArray!T) {
            size_t total = virtualLength + t.length;

            grow(findFittingSize(total));
            storage[virtualLength .. virtualLength + t.length] = t[];
            virtualLength += t.length;
            return t.length;
        } else {
            if (virtualLength >= storage.length) {
                grow(findFittingSize(virtualLength+1));
            }
            storage[virtualLength] = t;
            virtualLength += 1;
            return 1;
        }
    }


    size_t length() const @property {
        return virtualLength;
    }
    alias length opDollar;
    void length(size_t newSize) @property {
        if(newSize > storage.length) {
            grow(findFittingSize(newSize));
        }
        virtualLength = newSize;
    }

    void nuke() { storage = null; virtualLength = 0; }


    void popBack() { removeFromEnd(1); }

    T removeAny() {
        virtualLength -= 1;
        return storage[virtualLength];
    }

    void removeFromEnd(size_t howMany) {
        assert (virtualLength >= howMany);
        virtualLength -= howMany;
    }


    size_t removeKey(T t) {
        auto idx = storage[0..virtualLength].countUntil(t);
        if(idx == -1) return 0;
        virtualLength -= 1;
        foreach(i ; idx .. virtualLength) {
            storage[i] = storage[i+1];
        }
        return 1 + removeKey(t);
    }

    void reset() { virtualLength = 0; }

    T[] opSlice() {
        return storage[0 .. virtualLength];
    }
    T[] opSlice(size_t lower, size_t upper) {
        return storage[lower .. upper];
    }

    ref T opIndex(size_t index) {
        assert (index < virtualLength);
        return storage[index];
    }

    void opOpAssign(string s, U)(U t) if (s == "~") {
        insert(t);
    }
}

struct Array(T) {
    mixin ArrayFunctionality!T;
}

class ArrayClass(T) {
    mixin ArrayFunctionality!T;
}
