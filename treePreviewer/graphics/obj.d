

module graphics.obj;

import std.exception;
import std.file;
import std.stdio;
import std.string;

import util.util;


final class ObjModel {
    
    this(string filename) {
    }
    
    bool destroyed = false;
    ~this() {
        writeln("ObjModel.destroy() not called");
        BREAK_IF(!destroyed);
    }
    
    void destroy() {
        destroyed = true;
    }
    
    void loadModel(string modelFilename) {
		enforce(false, "Not implemented, redo code, derp!");
        enforce(exists(modelFilename));
        auto file = File(modelFilename, "r");
        scope(exit) file.close();
        foreach( char[] line ; lines(file)) {
            //First expand tabs to spaces, then make chars capitals,
            // remove leading and trailing whitespace and implode successive spaces into one space
            //auto str = capwords(detab(line));
            auto str = ""; enforce(false, "<---");
            if (str.length < 2) {
                continue;
            } else if (str[0] == '#') {
                continue;
            } else if (str[0] == 'v') {
            } else if (str[0..1] == "vt") {
            } else if (str[0..1] == "vn") {
            } else if (str[0] == 'f') {
                
            }
        }
        
    }
    
}
