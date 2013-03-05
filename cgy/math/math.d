module math.math;

import std.math;

immutable RadToDeg = 180.0 / std.math.PI;
immutable DegToRad = std.math.PI / 180.0;


bool equals(T, Y)(T a, Y b, T tolerance = 0.000001) {
    return abs(a-b) < tolerance;
}




