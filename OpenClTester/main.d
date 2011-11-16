module main;

import std.algorithm;
import std.exception;
import std.file;
import std.stdio;
import std.string;

import opencl.all;
pragma(lib, "cl4d.lib");
pragma(lib, "opencl.lib");


CLContext       clContext;
CLCommandQueue clCommandQueue;

bool testCode(string filename) {
    if(filename.length < 4) return false;
    if(filename[filename.length-3 .. $] != ".cl") {
        writeln("REJECTED!");
        return false;
    }
    writeln("=== Filename: " ~filename~ " ===");

    string fileContent = readText(filename);

	auto platforms = CLHost.getPlatforms();
	auto platform = platforms[0];
	auto devices = platform.allDevices;
	clContext = CLContext(devices);
    clCommandQueue = CLCommandQueue(clContext, devices[0]);

    auto program = clContext.createProgram( mixin(CL_PROGRAM_STRING_DEBUG_INFO) ~ fileContent);

    bool erroar = false;
    try{
        program.build("-w -Werror");
    }catch(Throwable t){
        writeln("Derp error lol!\n");
        erroar = true;
    }
    writeln(program.buildLog(devices[0]));
    return erroar;
}

//SHAMELESSELY STOLEN FROM THE VIBRANT CREATEORS OF COOLGAMEYO!!!! >.<
// cb should return true to stop iteration.
string[] dir(string path) {
    string[] ret;
    foreach(string name ; dirEntries(path, SpanMode.shallow)) {
        name = name[max(lastIndexOf(name, "/")+1,
                        lastIndexOf(name, "\\")+1) .. $];
        ret ~= name;
    }
    return ret;
}


int main(string[] argv)
{
    auto filenames = dir("./");
    foreach(name ; filenames) {
        if(testCode(name)) {
            break;
        }
    }
    writeln("\n\n\nFIN");
    readln();
    return 0;
}
