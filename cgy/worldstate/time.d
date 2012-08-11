
module worldstate.time;

import std.string;
import std.exception;

immutable TICKS_PER_SECOND = 35; //Ticks per irl second

//immutable TicksPerMinute = 24; //This is then number of ticks required to increase world/game time with 1 minute
//For debug and quick day :)
immutable TicksPerMinute = 15;
immutable TicksPerHour = TicksPerMinute * 60;
immutable TicksPerDay = TicksPerMinute * 24;

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

    vec3d getSunPosition() {

        auto sincos = expi(2*PI*getDayTime());
        immutable double worldSize = mapScale[5];
        immutable worldSize2 = 2 * worldSize;
        return vec3d(worldSize2*sincos.im, 0, abs(worldSize2*sincos.re));
    }


}

