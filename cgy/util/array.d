module util.array;

final class Array(T) {
    T[] ts;

    size_t p;
    ref size_t length() @property { return p; }

    void insert(T t) {
        if (p >= ts.length) {
            ts.length = (ts.length + 1) * 2 - 1; // 2^n-1 ---> 2^(n+1)-1
            //assert (ts.length == ts.capacity);
        }
        ts[p] = t;
        p += 1;
    }
    void reset() { p = 0; }
    void nuke() { ts = null; p = 0; }

    T removeAny() {
        p -= 1;
        return ts[p];
    }

    void removeFromEnd(size_t howMany) {
        assert (p >= howMany);
        p -= howMany;
    }

    bool empty() @property const { return p==0; }

    T[] opSlice() { return ts[0 .. p]; }

    ref T opIndex(size_t index) {
        assert (index < p);
        return ts[index];
    }

    void opOpAssign(string s)(T t) if (s == "~") {
        insert(t);
    }
}

