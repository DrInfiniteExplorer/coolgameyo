module cgy.util.statistics;

import std.algorithm;
import std.conv;
import std.datetime;
import std.exception;
import std.file;
import std.string;
import std.stdio;

import cgy.util.util : msg;


__gshared Statistics g_Statistics;

__gshared int triCount = 0;

shared static this() {
    g_Statistics = new Statistics;
}

shared static ~this() {
    g_Statistics.save();
}


immutable MaxSamples = 100;

template SampleCircleBuffer(const char[] name, const int MaxSamples) {
    const char [] SampleCircleBuffer = text(
        "long[",MaxSamples,"] time",name,";
        long time",name,"Max=-long.max;
        long time",name,"Min= long.max;
        uint index",name,";
        void add",name,"(long usecs) {
            synchronized(this) {
                time",name,"Min = min(time",name,"Min, usecs);
                time",name,"Max = max(time",name,"Max, usecs);
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
        string saveData",name,"() {
            return text(
                \"",name," min:\", time",name,"Min, \"\\n\",
                \"",name," max:\", time",name,"Max, \"\\n\",
                \"",name," averate:\", average",name,"(), \"\\n\",
            );
        }
    ");
}

template SamplesPerSecond(const char[] name, const int samples) {
    const char[] SamplesPerSecond = text("mixin(SampleCircleBuffer!(\"",name,"\", ",samples,"));
        float get",name,"PS() const {
            auto val = getLatest",name,"();
            if (val == 0) {
                return float.infinity;
            }
            return 1_000_000.0f / to!float(val);
        }
        float get",name,"PSAverage() const {
            auto val = average",name,"();
            if (val == 0) {
                return float.infinity;
            }
            return 1_000_000.0f / to!float(val);
        }"
    );
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
        string saveData",name,"() {
            return text(\"",name,":\", time",name,",\"\\n\");
        }
    ");
}

template ProgressData(const char[] name) {
    const char [] ProgressData = text(
    "   int ",name,"ToDo;
        int ",name,"Done;
        void ",name,"New(int _new) {
            synchronized(this) {
                if (_new == 0) {
                    ",name,"ToDo = 0;
                    ",name,"Done = 0;
                } else {
                    ",name,"ToDo += _new;
                }
            }
        }
        void ",name,"Progress(int numDone) {
            synchronized(this) {
                ",name,"Done += numDone;
            }
        }
    "
    );
}

final class Statistics {

    this() {
    }    

    void save() {
        string str = 
            saveDataGRUploadTime() ~
            saveDataBuildGeometry() ~
            saveDataMakeGeometryTasks() ~
            saveDataGetTask() ~

            saveDataFPS() ~
            saveDataTPS() ~
            saveDataStartupTime() ~
            saveDataGameInit() ~
            saveDataTileTypeManagerCreation() ~
            saveDataRendererInit() ~
            saveDataAtlasUpload() ~
            saveDataInitialFloodFill() ~
            saveDataInitialHeightmaps() ~
            "";

        std.file.write("statistics.txt", str);
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

    mixin(SampleCircleBuffer!("GetTask", 200));

    mixin(SamplesPerSecond!("FPS", 50));
    mixin(SamplesPerSecond!("TPS", 50));

    mixin(SampleSingle!("StartupTime", true));
    mixin(SampleSingle!("GameInit", true));
    mixin(SampleSingle!("TileTypeManagerCreation", true));
    mixin(SampleSingle!("EntityTypeManagerCreation", true));
    mixin(SampleSingle!("UnitTypeManagerCreation", true));
    mixin(SampleSingle!("RendererInit", true));
    mixin(SampleSingle!("AtlasUpload", true));
    mixin(SampleSingle!("InitialFloodFill", true));
    mixin(SampleSingle!("InitialHeightmaps", true));

    mixin(ProgressData!("Heightmaps"));
    mixin(ProgressData!("GraphRegions"));
    mixin(ProgressData!("FloodFill"));
    mixin(ProgressData!("SaveGame"));
    mixin(ProgressData!("LoadGame"));
}

struct StupWatch {
    StopWatch sw;
    alias sw this;
}

template LogTime(const char[] What) {
    const char[] LogTime = 
    "StupWatch sw;    
    sw.start();
    scope(exit) {
        sw.stop();
        g_Statistics.add"~What~"(sw.peek().usecs);
    }";
    
}

template Time(const char[] WhenDone) {
    const char[] Time = 
    "StupWatch sw;    
    sw.start();
    scope(exit) {
        sw.stop();
        auto usecs = sw.peek().usecs;
        "~WhenDone~"
    }";
    
}

template MeasureTime(const char[] msg, const bool ms = true) {
    const char[] MeasureTime = 
        "StupWatch sw;    
        sw.start();
        scope(exit) {
            sw.stop();
            auto usecs = sw.peek().usecs;
            msg(\"" ~ msg ~ "\", "~ (ms?"usecs/1000":"usecs")~", " ~ (ms?"\" ms\"":"\" usecs\"")  ~ ");
        }";

}
