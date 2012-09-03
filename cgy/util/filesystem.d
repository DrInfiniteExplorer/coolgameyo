
module util.filesystem;

import std.algorithm;
import std.exception;
import std.file;
import std.string;
import std.stdio;
import std.traits;

import util.util;

bool exists(string path) {
    return std.file.exists(path);
}
bool existsDir(string path) {
    return exists(path) && isDir(path);
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

// int[] t = [1, 3, 5]
// writeBin("asd", t); 
// readBin("asd", t);


//Makes dir, recursively
void mkdir(string path) {
    if (exists(path)) {
        enforce(isDir(path), "Non-filder with name exists:" ~path);
        return;
    }
    mkdirRecurse(path);
}

//Removes dir, recursively
void rmdir(string path) {
    rmdirRecurse(path);
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

struct BinaryFile {
    File file;
    this(string path, string mode) {
        if(std.algorithm.indexOf(mode, "w") == -1) {
            mode = "rb";
        } else {
            mode = "wb";
        }
        file = std.stdio.File(path, mode);
    }

    /*
    void writeRetard(T)(T t) { //Because asd.length -> retarded error.
        write(t);
    }
    solved with auto ref which takes ref if possible and not otherwise (according to plol)
    */
    void write(T)(auto ref T t) {

        static if(isArray!T) {
            file.rawWrite(t);
        } else static if(isAssociativeArray!T) {
            static assert(0, "Wut no we dont write associative arrays, duh!");
        } else {
            T[] arr = (&t)[0..1];
            file.rawWrite(arr);
        }
    }

    auto read(T)() {
        static if(isArray!T) {
            T tmp;
            file.rawRead(tmp);
            return tmp;
        } else {
            T tmp;
            T[] tmp2 = cast(T[])((&tmp)[0..1]);
            file.rawRead(tmp2);
            return tmp;
        }
    }
    void read(T)(ref T t) {
        static if(isArray!T) {
            file.rawRead(t);
        } else static if(isAssociativeArray!T) {
            static assert(0, "Wut no we dont read associative arrays, duh!");
        } else {
            T[] tmp2 = ((&t)[0..1]);
            file.rawRead(tmp2);
        }
    }

};

