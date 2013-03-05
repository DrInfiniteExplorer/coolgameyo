module random.gradient;

import util.util;
import random.valuesource;

final class GradientField : ValueSource {
    vec3d normal;
    double d;

    this(vec3d zero, vec3d one) {
        normal = one - zero;
        d = normal.dotProduct(zero);
    }

    override double getValue3(vec3d pos) {
        return normal.dotProduct(pos) - d;
    }
    override double getValue2(vec2d pos) {
        return getValue3(pos.v3(0));
    }
    override double getValue(double x) {
        return getValue3(vec3d(x, 0, 0));
    }    
}

final class PlanarDistanceField : ValueSource {
    vec3d normal;
    double d;

    this(vec3d zero, vec3d _normal) {
        normal = _normal;
        d = normal.dotProduct(zero);
    }

    override double getValue3(vec3d pos) {
        return normal.dotProduct(pos) - d;
    }
    override double getValue2(vec2d pos) {
        return getValue3(pos.v3(0));
    }
    override double getValue(double x) {
        return getValue3(vec3d(x, 0, 0));
    }    
}



/*
      | 
      |
     /|\
    / | \
   /  |  \
  /   |   \
 /    |    \
/     |     \

Axis = centre axis
Zero = what point along the axis where the density of the field is 0
Falloff = 'The angle' of the cone, as illustrated above.
*/

final class ConicalGradientField : ValueSource {
    vec3d axis;
    vec3d zero;
    double d;
    double falloff;

    this(vec3d _axis, vec3d _zero, double _falloff) {
        axis = _axis;
        axis.normalize;
        zero = _zero;
        d = axis.dotProduct(zero);
        falloff = _falloff;
    }

    override double getValue3(vec3d pos) {

        auto pt = pos;
        auto projected = axis.dotProduct(pt);
        auto distanceOnAxis = projected - d;
        auto projectedPt = zero + distanceOnAxis * axis;
        auto distanceFromAxis = (pt - projectedPt).getLength;

        auto density = distanceOnAxis - distanceFromAxis * falloff;
        return density;
    }
    override double getValue2(vec2d pos) {
        return getValue3(pos.v3(0));
    }
    override double getValue(double x) {
        return getValue3(vec3d(x, 0, 0));
    }    
}
