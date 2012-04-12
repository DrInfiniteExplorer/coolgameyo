module util.array;

//An array class that wraps a dynamic array
//When grown (with insert only!) allocates more memory
//When shrunk (with length, reset, removeAny, removeFromEnd) doesn't 
// deallocate memory, and no assumeSafeAppend is needed because
// the actuall storage array never shrank.

//BUG!
// If someone increases the length of an array with a.length = 9001,
//  and then does removeAny, opSlice or opIndex, then we will not
//  have any actual data allocated to accomodate the increase in length

final class Array(T) {
    T[] storage;

    size_t virtualLength;

    //BUG! see top of file!
    ref size_t length() @property { return virtualLength; }

    alias insert insertBack;
    size_t insert(T t) {
        if (virtualLength >= storage.length) {
            storage.length = (storage.length + 1) * 2 - 1; // 2^n-1 ---> 2^(n+1)-1
            //assert (storage.length == storage.capacity);
        }
        storage[virtualLength] = t;
        virtualLength += 1;
        return 1;
    }
    void reset() { virtualLength = 0; }
    void nuke() { storage = null; virtualLength = 0; }

    //BUG, see top of file!
    T removeAny() {
        virtualLength -= 1;
        return storage[virtualLength];
    }

    void removeFromEnd(size_t howMany) {
        assert (virtualLength >= howMany);
        virtualLength -= howMany;
    }

    bool empty() @property const { return virtualLength==0; }

    //BUG, see top of file!
    T[] opSlice() { return storage[0 .. virtualLength]; }

    //BUG, see top of file!
    ref T opIndex(size_t index) {
        assert (index < virtualLength);
        return storage[index];
    }

    void opOpAssign(string s)(T t) if (s == "~") {
        insert(t);
    }
}

