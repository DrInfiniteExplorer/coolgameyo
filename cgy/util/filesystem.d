
module util.filesystem;

import std.algorithm;
import std.exception;
import std.file;
import std.string;

import util.util;

bool exists(string path) {
    return std.file.exists(path);
}

//Reads a whole file as text
string readText(string path) {
    return std.file.readText(path);
}

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
