module util.array;

//An array class that wraps a dynamic array
// When grown (with insert only!) allocates more memory
// When shrunk (with length, reset, removeAny, removeFromEnd) doesn't 
//  deallocate memory, and no assumeSafeAppend is needed because
//  the actuall storage array never shrank.

import std.traits;

struct Array(T) {
    T[] storage;

    size_t virtualLength;

    size_t length() @property {
        return virtualLength;
    }
    void length(size_t newSize) @property {
        if(newSize > storage.length) {
            grow(findFittingSize(newSize));
        }
        virtualLength = newSize;
    }

    size_t findFittingSize(size_t atLeast) {
        size_t now = storage.length;
        while(now < atLeast) {
            now = (now + 1) * 2 - 1;
        }
        return now;
    }

    void grow(size_t newSize) {
        if(newSize <= storage.length) return;
        storage.length = newSize;
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

    void reset() { virtualLength = 0; }
    void nuke() { storage = null; virtualLength = 0; }


    T removeAny() {
        virtualLength -= 1;
        return storage[virtualLength];
    }

    void removeFromEnd(size_t howMany) {
        assert (virtualLength >= howMany);
        virtualLength -= howMany;
    }

    bool empty() @property const { return virtualLength==0; }

    T[] opSlice() {
        return storage[0 .. virtualLength];
    }

    ref T opIndex(size_t index) {
        assert (index < virtualLength);
        return storage[index];
    }

    void opOpAssign(string s, T)(T t) if (s == "~") {
        insert(t);
    }
}

