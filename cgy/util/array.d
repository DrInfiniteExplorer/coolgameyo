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

    bool empty() @property const { return p==0; }

    T[] opSlice() @property { return ts[0 .. p]; }
}

