

import std.stdio;
import std.algorithm;
import std.array;

import etc.c.zlib;
import std.zlib;



//version = UnittestZStreamWrappers;


struct Deflate {

    z_stream stream;

    this(int level) {
        deflateInit(&stream, level);
    }
    ~this() {
        auto err = deflateEnd(&stream);
        if (err) {
            throw new ZlibException(err);
        }
    }

    private size_t deflate_impl(ubyte[]* next_in,
            ubyte[] next_out, bool flush) {

        stream.avail_in = cast(uint)next_in.length;
        stream.next_in = next_in.ptr;

        stream.avail_out = cast(uint)next_out.length;
        stream.next_out = next_out.ptr;

        auto err = etc.c.zlib.deflate(&stream,
                flush ? std.zlib.Z_FINISH : std.zlib.Z_NO_FLUSH);

        if (err == Z_STREAM_END) {
            // we're done, do not throw this :s
        } else if (err) {
            throw new ZlibException(err);
        }

        auto ret = next_out.length - stream.avail_out;
        *next_in = (*next_in)[$ - stream.avail_in .. $];
        return ret;
    }
    size_t deflate(ubyte[]* next_in, ubyte[] next_out) {
        return deflate_impl(next_in, next_out, false);
    }
    size_t flush(ubyte[] next_out) {
        ubyte[] dummy;
        return deflate_impl(&dummy, next_out, true);
    }
}

struct Inflate {

    z_stream stream;

    public this() @disable;
//    private this(int dummy_lol) {
//        inflateInit(&stream);
//    }
//    static Inflate opCall() {
//        return Inflate(0);
//    }
    ~this() {
        auto err = inflateEnd(&stream);
        if (err) {
            throw new ZlibException(err);
        }
    }

    private size_t inflate_impl(ubyte[]* next_in,
            ubyte[] next_out, bool flush) {

        stream.avail_in = cast(uint)next_in.length;
        stream.next_in = next_in.ptr;

        stream.avail_out = cast(uint)next_out.length;
        stream.next_out = next_out.ptr;

        auto err = etc.c.zlib.inflate(&stream,
                flush ? std.zlib.Z_FINISH : std.zlib.Z_NO_FLUSH);

        if (err == Z_STREAM_END) {
            // we're done, do not throw this :s
        } else if (err) {
            throw new ZlibException(err);
        }

        auto ret = next_out.length - stream.avail_out;
        *next_in = (*next_in)[$ - stream.avail_in .. $];
        return ret;
    }
    size_t inflate(ubyte[]* next_in, ubyte[] next_out) {
        return inflate_impl(next_in, next_out, false);
    }
    size_t flush(ubyte[] next_out) {
        ubyte[] dummy;
        return inflate_impl(&dummy, next_out, true);
    }
}

version (UnittestZStreamWrappers) unittest {
    ubyte[] buf = new ubyte[](2*1024);
    ubyte[] src;

    ubyte[] compressed;

    foreach (i; 0 .. 1024*1024) {
        src ~= (i) & 255;
        src[i] += i % 13;
        src[(i*i) % $] += 7;
    }
    auto src_original = src;

    auto z = Deflate(6);

    //writeln(src.length);

    size_t wrote;
    while (!src.empty) {
        wrote = z.deflate(&src, buf);
        compressed ~= buf[0 .. wrote];
    }

    while (true) {
        wrote = z.flush(buf);
        compressed ~= buf[0 .. wrote];
        if (wrote < buf.length) {
            break;
        }
    }

    //writeln(compressed.length);
    //writeln(1.0 - (0.0 + compressed.length) / src_original.length);

    assert (std.zlib.uncompress(compressed) == src_original);
}

version (UnittestZStreamWrappers) unittest {
    ubyte[] buf = new ubyte[](2*1024);
    ubyte[] complete_src;

    ubyte[] compressed;

    auto z = Deflate(9);

    size_t wrote;
    foreach (i; 0 .. 100) {
        ubyte[] src;

        src.length = std.random.uniform(10000, 20000);
        foreach (ref x; src) { x = 255&std.random.uniform(0, 256); }

        complete_src ~= src;

        while (!src.empty) {
            wrote = z.deflate(&src, buf);
            compressed ~= buf[0 .. wrote];
        }
    }

    while (true) {
        wrote = z.flush(buf);
        compressed ~= buf[0 .. wrote];
        if (wrote < buf.length) {
            break;
        }
    }

    //writeln(complete_src.length);
    //writeln(compressed.length);
    //writeln(1.0 - (0.0 + compressed.length) / complete_src.length);

    assert (std.zlib.uncompress(compressed) == complete_src);
}

version (UnittestZStreamWrappers) unittest {
    ubyte[] buf = new ubyte[](2*1024);
    ubyte[] complete_src;

    ubyte[] compressed;

    auto z = Deflate(9);

    size_t wrote;
    foreach (i; 0 .. 100) {
        ubyte[] src;

        src.length = std.random.uniform(10000, 20000);
        foreach (ref x; src) { x = 255&std.random.uniform(0, 256); }

        complete_src ~= src;

        while (!src.empty) {
            wrote = z.deflate(&src, buf);
            compressed ~= buf[0 .. wrote];
        }
    }

    while (true) {
        wrote = z.flush(buf);
        compressed ~= buf[0 .. wrote];
        if (wrote < buf.length) {
            break;
        }
    }

    //writeln(complete_src.length);
    //writeln(compressed.length);
    //writeln(1.0 - (0.0 + compressed.length) / complete_src.length);

    auto inflate = Inflate();
    ubyte[] inflated_src;

    while (!compressed.empty) {
        wrote = inflate.inflate(&compressed, buf);
        inflated_src ~= buf[0 .. wrote];
    }
    while (true) {
        wrote = inflate.flush(buf);
        inflated_src ~= buf[0 .. wrote];
        if (wrote < buf.length) {
            break;
        }
    }

    assert (inflated_src == complete_src);
}

version (UnittestZStreamWrappers) unittest {
    ubyte[] buf = new ubyte[](2*1024);
    ubyte[] src;

    foreach (i; 0 .. 1024*1024) {
        src ~= (i) & 255;
        src[i] += i % 13;
        src[(i*i) % $] += 7;
    }

    ubyte[] compressed = cast(ubyte[])std.zlib.compress(src);

    //writeln(compressed.length);
    //writeln(1.0 - (0.0 + compressed.length) / src_original.length);

    auto inflate = Inflate();
    ubyte[] inflated_src;

    while (!compressed.empty) {
        auto wrote = inflate.inflate(&compressed, buf);
        inflated_src ~= buf[0 .. wrote];
    }
    while (true) {
        auto wrote = inflate.flush(buf);
        inflated_src ~= buf[0 .. wrote];
        if (wrote < buf.length) {
            break;
        }
    }

    assert (inflated_src == src);
}


