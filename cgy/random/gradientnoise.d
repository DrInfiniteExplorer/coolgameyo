module random.gradientnoise;

import std.math;

import util.util;
import random.random;
import random.permutation;
import random.randsource;

class GradientNoise(string Step = "smoothStep", string Lerp = "lerp") : ValueSource {
    mixin("alias " ~ Step ~ " StepFunc;");
    mixin("alias " ~ Lerp ~ " Interpolate;");
    uint size;
    vec3d[] PRNs;
    mixin Permutation!size;
    this(uint Size, RandSourceUniform rsu) {
        size = Size;
        PRNs.length = size;
        initPermutations(rsu);
        foreach(ref p ; permutations) {
            p = rsu.get!uint(0, size);
        }

        foreach(ref p ; PRNs) {
            vec3d v;
            do {
                v = vec3d(rsu.getValue(0), rsu.getValue(0), rsu.getValue(0));
            }while(v.getLengthSQ() > 1.0);
            p = v.normalize();
            
        }
    }
    
    double getLattice(int i, int j, int k, double dx, double dy, double dz) {
        return PRNs[Index(i, j, k)].dotProduct(vec3d(dx, dy, dz));
    }

    double getLattice(int i, int j, double dx, double dy) {
        auto v = PRNs[Index(i, j)];
        return v.X * dx + v.Y * dy; // TODO: Make use of all values eventually, not only x,y but z as well. Same for 1D-version
    }

    double getLattice(int i, double dx) {
        auto v = PRNs[Index(i)];
        return v.X * dx;
    }
    
    double getValue(double x, double y, double z) {
        x += 0.012354378973;
        y += 0.834239853982;
        z += 0.359820984234;
        int i = to!int(floor(x));
        int j = to!int(floor(y));
        int k = to!int(floor(z));
        double dx = x - to!double(i);
        double dy = y - to!double(j);
        double dz = z - to!double(k);
        
        double v000 = getLattice(i  , j  , k  , dx  , dy  , dz  );
        double v100 = getLattice(i+1, j  , k  , dx-1, dy  , dz  );
        double v110 = getLattice(i+1, j+1, k  , dx-1, dy-1, dz  );
        double v010 = getLattice(i  , j+1, k  , dx  , dy-1, dz  );
        double v001 = getLattice(i  , j  , k+1, dx  , dy  , dz-1);
        double v101 = getLattice(i+1, j  , k+1, dx-1, dy  , dz-1);
        double v111 = getLattice(i+1, j+1, k+1, dx-1, dy-1, dz-1);
        double v011 = getLattice(i  , j+1, k+1, dx  , dy-1, dz-1);
        
        double wx = StepFunc(dx);
        double wy = StepFunc(dy);
        double wz = StepFunc(dz);
        
        double v00 = Interpolate(v000, v001, wz);
        double v01 = Interpolate(v010, v011, wz);
        double v11 = Interpolate(v110, v111, wz);
        double v10 = Interpolate(v100, v101, wz);
        
        double v0 = Interpolate(v00, v01, wy);
        double v1 = Interpolate(v10, v11, wy);
        
        return 2.0 * Interpolate(v0, v1, wx);
    }    
    double getValue(double x, double y) {
        x += 0.012354378973;
        y += 0.834239853982;

        int i = to!int(floor(x));
        int j = to!int(floor(y));
        double dx = x - to!double(i);
        double dy = y - to!double(j);
        
        double v00 = getLattice(i  , j  , dx  , dy  );
        double v10 = getLattice(i+1, j  , dx-1, dy  );
        double v11 = getLattice(i+1, j+1, dx-1, dy-1);
        double v01 = getLattice(i  , j+1, dx  , dy-1);
        
        double wx = StepFunc(dx);
        double wy = StepFunc(dy);
        
        double y0 = Interpolate(v00, v10, wx);
        double y1 = Interpolate(v01, v11, wx);
        return 2.0 * Interpolate(y0, y1, wy);
    }
    
    double getValue(double x) {
        x += 0.012354378973;

        int i = to!int(floor(x));
        double dx = x - to!double(i);
        
        double v00 = getLattice(i  , dx  );
        double v10 = getLattice(i+1, dx-1);
        
        double wx = StepFunc(dx);
        
        return 2.0 * Interpolate(v00, v10, wx);
    }
}

class GradientNoise01(string Step = "smoothStep", string Lerp = "lerp") : GradientNoise!(Step, Lerp) {
    this(uint Size, RandSourceUniform rsu) {
        super(Size, rsu);
    }

    override double getValue(double x, double y, double z) {
        return super.getValue(x,y,z) + 0.5;
    }    
    override double getValue(double x, double y) {
        return super.getValue(x,y) + 0.5;
    }

    override double getValue(double x) {
        return super.getValue(x) + 0.5;
    }
}

class OffsetGradientNoise(string Step = "smoothStep", string Lerp = "lerp") : GradientNoise!(Step, Lerp) {
    this(uint Size, RandSourceUniform rsu) {
        super(Size, rsu);
    }

    override double getValue(double x, double y, double z) {
        return super.getValue(x+0.51235456,y+0.554378989,z+0.545723);
    }    
    override double getValue(double x, double y) {
        return super.getValue(x+0.2512454,y+0.258673);
    }

    override double getValue(double x) {
        return super.getValue(x+0.57623493);
    }
}

import random.randsource;
import std.stdio;
import std.conv;
unittest {
    auto randSource = new RandSourceUniform(123453);
    auto worldHeightMap = new OffsetGradientNoise!()(123456, randSource);   // [-500, 1500]
    double min = double.max;
    double max = -double.max;
    for(double t = 0; t < 123456; t += 0.1) {
        double v = worldHeightMap.getValue(t);
        if (min > v) min = v;
        if (max < v) max = v;
    }
    writeln(text("min ", min, " max ", max));
    assert(max - min > 1.8, text("Derp derp lskjdflu blommorna brinner! ", max-min));
}
