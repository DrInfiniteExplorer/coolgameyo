
module util.filesystem;

import std.algorithm;
import std.exception;
import std.file;
import std.string;
import std.stdio;
import std.traits;
import std.zlib : Compress, UnCompress;

import util.memory : BinaryWriter, BinaryReader;
import util.util;


bool exists(string path) {
    return std.file.exists(path);
}
bool existsDir(string path) {
    return exists(path) && isDir(path);
}

ulong fileSize(string path) {
//    import std.stdio : getSize;
    return getSize(path);
}

//Reads a whole file as text
string readText(string path) {
    return std.file.readText(path);
}

void writeText(string path, string content) {
    std.file.write(path, content);
}

//Reads a binary file
void readBin(T)(string path, ref T[] t) {
    //static assert (__traits(compiles, cast(T)std.file.read(path)));
    t = cast(T[])std.file.read(path);
}
//Writes to a file as binary data.
void writeBin(T)(string path, T t) {
    std.file.write(path, t);
}

void append(Us...)(string path, Us us) {
    BinaryFile file = BinaryFile(path, "a");
    foreach(item ; us) {
        file.write(item);
    }
    file.close();
}

// int[] t = [1, 3, 5]
// writeBin("asd", t); 
// readBin("asd", t);


//Makes dir, recursively
void mkdir(string path) {
    if (exists(path)) {
        enforce(isDir(path), "Non-folder with name exists:" ~path);
        return;
    }
    mkdirRecurse(path);
}

//Removes dir, recursively
void rmdir(string path) {
    if(existsDir(path)) {
        rmdirRecurse(path);
    }
}

//Copies, recursively
void copy(string from, string to)
in{
    BREAK_IF(!exists(from));
}
body{
    if (isDir(from)) {

        mkdir(to);
        dir(from, (string item){
            auto too = to ~ "/" ~ item;
            copy(from ~ "/" ~ item, too);
        });

    } else {
        std.file.copy(from, to);
    }
}

//moves, recursively
void move(string from, string to)
in{
    BREAK_IF(!exists(from));
}
body{
    if (isDir(from)) {

        mkdir(to);
        dir(from, (string item){
            auto too = to ~ "/" ~ item;
            move(from ~ "/" ~ item, too);
        });
        rmdir(from);

    } else {
        std.file.rename(from, to);
    }
}

void deleteFile(string path) {
    std.file.remove(path);
}

auto dir(string path) {
    return (int delegate(ref string path) Body) {
        foreach(string name ; dirEntries(path, SpanMode.shallow)) {
            name = name[max(lastIndexOf(name, "/")+1,
                            lastIndexOf(name, "\\")+1) .. $];
            int ret = Body(name);
            if(ret) return ret;
        }
        return 0;
    };
}

//Call cb with every item in the path
void dir(string path, void delegate(string name) cb) {
    return dir(path, (string name){cb(name); return false;});
}

// cb should return true to stop iteration.
void dir(string path, bool delegate(string name) cb)
in{
    BREAK_IF(cb is null);
    BREAK_IF(!exists(path) || !isDir(path));
}
body{
    foreach(string name ; dirEntries(path, SpanMode.shallow)) {
        name = name[max(lastIndexOf(name, "/")+1,
                        lastIndexOf(name, "\\")+1) .. $];
        if (cb(name)) {
            return;
        }
    }
}

unittest {
    import std.file : dirEntries, SpanMode, DirEntry, getcwd;
    auto startDir = "data//";
    msg(getcwd());
    foreach(DirEntry dirEntry ; dirEntries(startDir, SpanMode.breadth)) {
        BREAK_IF(dirEntry.name()[0 .. startDir.length] != startDir);
    }
}


struct BinaryFile {
    File file;
    this(string path, string mode) {
        if(countUntil(mode, "b") == -1) {
            mode = mode ~ "b";
        }
        file = std.stdio.File(path, mode);

        writer = BinaryWriter(&rawWrite);
        reader = BinaryReader(&rawRead);
    }
    BinaryWriter writer;
    BinaryReader reader;

    void rawWrite(ubyte[] data) {
        file.rawWrite(data);
    }
    void rawRead(ubyte[] data) {
        file.rawRead(data);
    }

    ulong size() @property {
        return file.size;
    }

    ulong tell() @property {
        return file.tell();
    }

    auto close() {
        return file.close();
    }
};

struct CompressedBinaryFile {
    File file;
    bool read;
    Compress compress;
    UnCompress uncompress;
    ubyte[] buffer;
    ubyte[] uncompressed;
    int bufferFillLevel = 0;
    this(string path, string mode) {
        if(countUntil(mode, "b") == -1) {
            mode = mode ~ "b";
        }
        file = std.stdio.File(path, mode);
        read = mode.countUntil("r") != -1;


        reader = BinaryReader(&sorry);
        writer = BinaryWriter(&sorry);
        if(read) {
            uncompress = new UnCompress();
            reader = BinaryReader(&decompressIt);
        } else {
            compress = new Compress(1);
            writer = BinaryWriter(&compressIt);
        }
        buffer.length = 32*1024;

    }
    BinaryWriter writer;
    BinaryReader reader;

    void sorry(ubyte[] data) {
        LogError("Sorry, cannot do that operation, the file is opened for ", read ? "reading" : "writing", " only.");
        BREAKPOINT;
    }

    void compressIt(ubyte[] data) {
        while(true) {
            if(data.length == 0) break;
            if(data.length + bufferFillLevel < buffer.length) {
                buffer[bufferFillLevel .. bufferFillLevel + data.length] = data[];
                bufferFillLevel += data.length;
                break;
            } else {
                auto untilBufferFilled = buffer.length - bufferFillLevel;
                buffer[bufferFillLevel .. $] = data[0 .. untilBufferFilled];
                data = data[untilBufferFilled .. $];
                bufferFillLevel = 0;
                ubyte[] compressed = cast(ubyte[])compress.compress(buffer);
                file.rawWrite(compressed);
            }
        }
    }
    void decompressIt(ubyte[] data) {
        while(true) {
            if(uncompressed.length >= data.length) {
                data[] = uncompressed[0 .. data.length];
                uncompressed = uncompressed[data.length .. $];
                break;
            } else {
                if(uncompressed.length) {
                    data[0 .. uncompressed.length] = uncompressed[];
                    data = data[uncompressed.length .. $];
                    uncompressed = uncompressed[$..$]; // just setting length = 0 :P
                }
                auto leftOfFile = size - tell;
                if(leftOfFile < buffer.length) {
                    buffer.length = cast(size_t)leftOfFile;
                }
                if(leftOfFile > 0) {
                    file.rawRead(buffer);
                    uncompressed = cast(ubyte[])uncompress.uncompress(buffer);
                } else {
                    uncompressed = cast(ubyte[])uncompress.flush();
                }
            }
        }
    }

    ulong size() @property {
        return file.size;
    }

    ulong tell() @property {
        return file.tell();
    }

    auto close() {
        if(read) {
        } else {
            if(bufferFillLevel) {
                ubyte[] compressed = cast(ubyte[])compress.compress(buffer[0 .. bufferFillLevel]);
                file.rawWrite(compressed);
            }
            ubyte[] flushed = cast(ubyte[])compress.flush();
            file.rawWrite(flushed);
        }
        return file.close();
    }
};

unittest {
    auto orig = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789";

    ubyte[] buff = cast(ubyte[])orig;

    CompressedBinaryFile file = CompressedBinaryFile("compress.test", "wb");
    auto writer = file.writer;
    auto count = 1000;
    foreach(idx ; 0 .. count) {
        writer.write(buff);
    }
    file.close();


    /*
    auto f = BinaryFile("compress.test", "rb");
    buff.length = f.size;
    f.reader.read(buff);
    f.close();
    auto uncomp = new UnCompress();
    ubyte[] un = cast(ubyte[])uncomp.uncompress(buff);
    un ~= cast(ubyte[])uncomp.flush();
    */

    file = CompressedBinaryFile("compress.test", "rb");
    auto reader = file.reader;
    foreach(idx ; 0 .. count) {
        msg(" idx ", idx, " len ", buff.length);
        reader.read(buff);
        if(buff != orig) {
            msg("Error at idx ", idx);
            BREAKPOINT;
        }
    }
    file.close();


/*
    file = CompressedBinaryFile("compress.test", "rb");
    auto reader = file.reader;
    foreach(idx ; 0 .. count) {
        msg(" idx ", idx, " len ", buff.length);
        reader.read(buff);
        if(buff != orig) {
            msg("Error at idx ", idx);
            BREAKPOINT;
        }
    }
    file.close();
*/

}
