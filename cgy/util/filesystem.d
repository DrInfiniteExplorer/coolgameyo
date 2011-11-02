
module util.filesystem;

import std.algorithm;
import std.exception;
import std.file;
import std.string;

import util.util;

void mkdir(string path) {
    if (exists(path)) {
        enforce(isDir(path), "Non-filder with name exists:" ~path);
        return;
    }
    mkdirRecurse(path);
}

void rmdir(string path) {
    rmdirRecurse(path);
}


void copy(string from, string to)
in{
    BREAK_IF(!exists(from));
}
body{
    if (isDir(from)) {
        mkdir(to);
/*        
        foreach(string item ; dirEntries(from, SpanMode.shallow)) {
            item = item[max(lastIndexOf(item, "/")+1,
                            lastIndexOf(item, "\\")+1) .. $];
            auto too = to ~ "/" ~ item;
            util.copy(from ~ "/" ~ item, too);
        }
*/
        dir(from, (string item){
            auto too = to ~ "/" ~ item;
            copy(from ~ "/" ~ item, too);
        });
    } else {
        std.file.copy(from, to);
    }
}

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
