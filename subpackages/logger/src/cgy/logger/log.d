module cgy.logger.log;

import std.stdio, std.conv;

private __gshared void delegate(string) logCallback;

shared static this() {
    logCallback = (string) {};
}

void setLogCallback(void delegate(string) callback) {
    logCallback = callback;
}

void Log(string file=__FILE__, int line=__LINE__, Us...)(Us us) {
    foreach(item ; us) {
        logCallback(to!string(item));
    }
    logCallback("\n");
//    msg!(file, line)(us);
//    stdout.flush();
}

void LogError(string file=__FILE__, int line=__LINE__, Us...)(Us us) {
    Log!(file, line)("ERROR: ",us);
}
void LogWarning(string file=__FILE__, int line=__LINE__, Us...)(Us us) {
    Log!(file, line)("WARNING: ",us);
}
void LogVerbose(string file=__FILE__, int line=__LINE__, Us...)(Us us) {
    Log!(file, line)("VERBOSE: ", us);
}
