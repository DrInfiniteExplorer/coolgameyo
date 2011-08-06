module statistics;

import std.algorithm;
import std.conv;
import std.exception;
import std.string;
import std.stdio;

import util;

__gshared Statistics g_Statistics;

shared static this() {
    g_Statistics = new Statistics;
}


enum MaxSamples = 100;

template SampleCircleBuffer(const char[] name, const int MaxSamples) {
    const char [] SampleCircleBuffer = text(
        "long[",MaxSamples,"] time",name,";
        long time",name,"Max=-long.max;
        long time",name,"Min= long.max;
        uint index",name,";
        void add",name,"(long usecs) {
            synchronized(this) {
                time",name,"Min = min(time",name,"Min, usecs);
                time",name,"Max = max(time",name,"Min, usecs);
                time",name,"[index",name,"] = usecs;
                index",name," = (index",name,"+1)%",MaxSamples,";
            }
        }
        long average",name,"() const {
            synchronized(this) {
                uint sum = 0;
                foreach(v ; time",name,") {
                    sum += v;
                }
                return sum / ",MaxSamples,";
            }
        }
        long get",name,"Min() const {
            return time",name,"Min;
        }
        long get",name,"Max() const {
            return time",name,"Max;
        }
        long getLatest",name,"() const{
                return time",name,"[(index",name,"+",MaxSamples,"-1)%",MaxSamples,"];
        }
        const(long)[] get",name,"() const{
            synchronized(this) {
                return time",name,";
            }
        }
    ");
}

template SampleSingle(const char[] name, const bool Write=false) {
    const char [] SampleSingle = text(
        "long time",name,";
        void add",name,"(long usecs) {
            synchronized(this) {
                time",name," = usecs;
                static if(",Write,") {
                    msg(\"",name,":\", usecs/1000, \" ms\");
                }
            }
        }
        long get",name,"() const{
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
    
    mixin(SampleCircleBuffer!("GRUploadTime", 50));
    mixin(SampleCircleBuffer!("BuildGeometry", 50));
    mixin(SampleCircleBuffer!("MakeGeometryTasks", 50));
    mixin(SampleCircleBuffer!("FPS", 50));
    mixin(SampleCircleBuffer!("TPS", 50));
    mixin(SampleSingle!("StartupTime", true));
    mixin(SampleSingle!("GameInit", true));
    mixin(SampleSingle!("TileTypeManagerCreation", true));    
    mixin(SampleSingle!("RendererInit", true));
    mixin(SampleSingle!("AtlasUpload", true));    

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
