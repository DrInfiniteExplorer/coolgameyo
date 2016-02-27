module random.valuesource;

import cgy.util.util;

import cgy.math.vector : vec3d, vec2d;

class ValueSource {
    abstract double getValue3(vec3d);
    abstract double getValue2(vec2d);
    abstract double getValue(double);


    private double getVal3(double x, double y, double z) {
        return getValue3(vec3d(x, y, z));
    }
    private double getVal2(double x, double y) {
        return getValue2(vec2d(x, y));
    }


    vec3d centralGradient(double x, double y, double z, double h = 1.0) {
        return vec3d(
                     (getVal3(x+h, y, z) - getVal3(x-h, y, z)) / (2*h),
                     (getVal3(x, y+h, z) - getVal3(x, y-h, z)) / (2*h),
                     (getVal3(x, y, z+h) - getVal3(x, y, z-1)) / (2*h)
                     );
    }
    vec2d centralGradient(double x, double y, double h) {
        return vec2d(
                     (getVal2(x+h, y) - getVal2(x-h, y)) / (2*h),
                     (getVal2(x, y+h) - getVal2(x, y-h)) / (2*h)
                     );
    }
    double centralGradient(double x, double h) {
        return (getValue(x+h) - getValue(x-h)) / (2*h);
    }

    vec3d forwardGradient(double x, double y, double z, double h = 1.0) {
        auto here = getVal3(x, y, z);
        return vec3d(
                     (getVal3(x+h, y, z) - here) / h,
                     (getVal3(x, y+h, z) - here) / h,
                     (getVal3(x, y, z+h) - here) / h
                     );
    }
    vec2d forwardGradient(double x, double y, double h = 1.0) {
        auto here = getVal2(x, y);
        return vec2d(
                     (getVal2(x+h, y) - here) / h,
                     (getVal2(x, y+h) - here) / h
                     );
    }
    double forwardGradient(double x, double h = 1.0) {
        return (getValue(x+h) - getValue(x)) / h;
    }


    vec3d upwindGradient(double x, double y, double z, double dirX, double dirY, double dirZ, double h = 1.0) {
        auto here = getVal3(x, y, z);
        return vec3d(
                     dirX < 0 ? getVal3(x+h, y  , z  ) - here : here - getVal3(x-h, y  , z  ),
                     dirY < 0 ? getVal3(x  , y+h, z  ) - here : here - getVal3(x  , y-h, z  ),
                     dirZ < 0 ? getVal3(x  , y  , z+h) - here : here - getVal3(x  , y  , z-h)
                     ) / h;
    }

    vec2d upwindGradient(double x, double y, double dirX, double dirY, double h = 1.0) {
        auto here = getVal2(x, y);
        return vec2d(
                     dirX < 0 ? getVal2(x+h, y  ) - here : here - getVal2(x-h, y  ),
                     dirY < 0 ? getVal2(x  , y+h) - here : here - getVal2(x  , y-h)
                     ) / h;
    }
    double upwindGradient(double x, double dirX, double h = 1.0) {
        auto here = getValue(x);
        return (dirX < 0 ? getValue(x+h) - here : here - getValue(x-h)) / h;
    }

}


final class DelegateSource : ValueSource { //Like above, but also handles coordinates. And the derp herp merp lerpl.
    double delegate(vec3d) f;
    this(double delegate(vec3d) _f) {
        f = _f;
    }

    override double getValue3(vec3d pos) {
        return f(pos);
    }
    override double getValue2(vec2d pos) {
        return f(pos.v3(0));
    }
    override double getValue(double x) {
        return f(vec3d(x, 0, 0));
    }    
}


class ValueSource2D {
    abstract vec2d getValue3(vec3d);
    abstract vec2d getValue2(vec2d);
    abstract vec2d getValue(double x);
}

final class ValueSource2DProxy : ValueSource2D {
    ValueSource a, b;
    this(ValueSource _a, ValueSource _b) {
        a = _a;
        b = _b;
    }

    override vec2d getValue3(vec3d pos) {
        return vec2d(a.getValue3(pos), b.getValue3(pos));
    }
    override vec2d getValue2(vec2d pos) {
        return vec2d(a.getValue2(pos), b.getValue2(pos));
    }
    override vec2d getValue(double x) {
        return vec2d(a.getValue(x), b.getValue(x));
    }

}

final class DelegateSource2D : ValueSource2D { //Like above, but also handles coordinates. And the derp herp merp lerpl.
    vec2d delegate(vec3d) f;
    this(vec2d delegate(vec3d) _f) {
        f = _f;
    }

    override vec2d getValue3(vec3d pos) {
        return f(pos);
    }
    override vec2d getValue2(vec2d pos) {
        return f(pos.v3(0));
    }
    override vec2d getValue(double x) {
        return f(vec3d(x, 0, 0));
    }    
}

