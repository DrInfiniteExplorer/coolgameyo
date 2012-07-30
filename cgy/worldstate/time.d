
module worldstate.time;

import std.string;
import std.exception;

enum TICKS_PER_SECOND = 35; //Ticks per irl second

//enum TicksPerMinute = 24; //This is then number of ticks required to increase world/game time with 1 minute
//For debug and quick day :)
enum TicksPerMinute = 15;
enum TicksPerHour = TicksPerMinute * 60;
enum TicksPerDay = TicksPerMinute * 24;

mixin template WorldTimeClockCode() {

    ulong worldTime = 0;

    void updateTime() {
        worldTime += 1;
    }

    //Returns 
    double getDayTime() const {
        ulong localDayTime = worldTime % TicksPerDay;
        return (cast(double)localDayTime) / (cast(double)TicksPerDay);
    }

    string getDayTimeString() const {
        double dayTime = getDayTime();
        int hours = cast(int)floor(24*dayTime);
        int minutes = cast(int)floor(24*60*dayTime);
        minutes = minutes % 60;
        return std.string.format("%02d:%02d", hours, minutes);
    }


}

