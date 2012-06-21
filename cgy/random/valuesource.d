module random.valuesource;

import util.util;

class ValueSource {
    abstract double getValue(double x, double y, double z);
    abstract double getValue(double x, double y);
    abstract double getValue(double x);


    vec3d centralGradient(double x, double y, double z, double h = 0.1) {
        return vec3d(
                     (getValue(x+h, y, z) - getValue(x-h, y, z)) / (2*h),
                     (getValue(x, y+h, z) - getValue(x, y-h, z)) / (2*h),
                     (getValue(x, y, z+h) - getValue(x, y, z-1)) / (2*h)
                     );
    }
    vec2d centralGradient(double x, double y, double h) {
        return vec2d(
                     (getValue(x+h, y) - getValue(x-h, y)) / (2*h),
                     (getValue(x, y+h) - getValue(x, y-h)) / (2*h)
                     );
    }
    double centralGradient(double x, double h) {
        return (getValue(x+h) - getValue(x-h)) / (2*h);
    }

    vec3d forwardGradient(double x, double y, double z, double h = 0.1) {
        auto here = getValue(x, y, z);
        return vec3d(
                     (getValue(x+h, y, z) - here) / h,
                     (getValue(x, y+h, z) - here) / h,
                     (getValue(x, y, z+h) - here) / h
                     );
    }
    vec2d forwardGradient(double x, double y, double h = 0.1) {
        auto here = getValue(x, y);
        return vec2d(
                     (getValue(x+h, y) - here) / h,
                     (getValue(x, y+h) - here) / h
                     );
    }
    double forwardGradient(double x, double h = 0.1) {
        return (getValue(x+h) - getValue(x)) / h;
    }

}


final class DelegateSource : ValueSource { //Like above, but also handles coordinates. And the derp herp merp lerpl.
    double delegate(double, double, double) f;
    this(double delegate(double, double, double) _f) {
        f = _f;
    }

    override double getValue(double x, double y, double z) {
        return f(x, y, z);
    }
    override double getValue(double x, double y) {
        return f(x, y, 0);
    }
    override double getValue(double x) {
        return f(x, 0, 0);
    }    
}


class ValueSource2D {
    abstract vec2d getValue(double x, double y, double z);
    abstract vec2d getValue(double x, double y);
    abstract vec2d getValue(double x);
}

final class ValueSource2DProxy : ValueSource2D {
    ValueSource a, b;
    this(ValueSource _a, ValueSource _b) {
        a = _a;
        b = _b;
    }

    override vec2d getValue(double x, double y, double z) {
        return vec2d(a.getValue(x, y, z), b.getValue(x, y, z));
    }
    override vec2d getValue(double x, double y) {
        return vec2d(a.getValue(x, y), b.getValue(x, y));
    }
    override vec2d getValue(double x) {
        return vec2d(a.getValue(x), b.getValue(x));
    }

}

final class DelegateSource2D : ValueSource2D { //Like above, but also handles coordinates. And the derp herp merp lerpl.
    vec2d delegate(double, double, double) f;
    this(vec2d delegate(double, double, double) _f) {
        f = _f;
    }

    override vec2d getValue(double x, double y, double z) {
        return f(x, y, z);
    }
    override vec2d getValue(double x, double y) {
        return f(x, y, 0);
    }
    override vec2d getValue(double x) {
        return f(x, 0, 0);
    }    
}

