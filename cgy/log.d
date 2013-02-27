module log;

import std.stdio;

__gshared void delegate(string) logCallback;

enum LogLevel {
    Undefined = 0,
    Critical,
    Error,
    Warning,
    Information,
    Verbose,    
}

void LogBase(LogLevel level = LogLevel.Information, Us...)(Us us) {
    import std.conv : to;
    foreach(item ; us) {
        write(item);
        if(logCallback) {
            static if(is(item : string)) {
                logCallback(item);
            } else {
                logCallback(to!string(item));
            }
        }
    }
    write("\n");
    stdout.flush();
    if(logCallback) {
        logCallback("\n");
    }
}
/*
void Log(Us...)(Us us) {
    LogBase!(LogLevel.Information, Us)(us);
}
*/
alias LogBase Log;
void LogVerbose(Us...)(Us us) {
    LogBase!(LogLevel.Verbose, Us)(us);
}
