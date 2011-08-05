module statistics;

import std.conv;
import std.exception;
import std.string;
import std.stdio;

__gshared Statistics g_Statistics;

static this() {
    g_Statistics = new Statistics;
}


enum MaxSamples = 100;

template DerpDerp(const char[] name) { //TODO: Think of better name than "DerpDerp"
    const char [] DerpDerp = text(
        "long[MaxSamples] time",name,";
        uint index",name,";
        void add",name,"(long usecs) {
            synchronized(this) {
                time",name,"[index",name,"] = usecs;
                index",name," = (index",name,"+1)%MaxSamples;
                writeln(\"", name, " \", index",name,", \" \", usecs);
            }
        }
        long average",name,"() const {
            synchronized(this) {
                uint sum = 0;
                foreach(v ; time",name,") {
                    sum += v;
                }
                return sum / MaxSamples;
            }
        }
        const(long)[] get",name,"() const{
            synchronized(this) {
                return time",name,";
            }
        }
    ");
}

class Statistics {

    this() {
    }    

/*
    Collects during full gc collect. Shouldnt? :S    
    ~this(){
        writeln("ASDASDASD");
        enforce(0, "Clean up statistics, write to file or something.");
    }        
*/  
    
    mixin(DerpDerp!("GRUploadTime"));
    mixin(DerpDerp!("BuildGeometry"));
    mixin(DerpDerp!("MakeGeometryTasks"));
    
}

template LogTime(const char[] What) {
    const char[] LogTime = 
    "StopWatch sw;    
    sw.start();
    scope(exit) {
        sw.stop();
        g_Statistics.add"~What~"(sw.peek().usecs);
    }";
    
}

