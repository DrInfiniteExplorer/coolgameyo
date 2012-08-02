module random.modscaleoffset;

import util.util;
import util.rect;
import random.valuesource;

//Scale and offset. For example, to use a valuemap(width, height) as source for world height,
// we want to scale with width/(worldSize*sectorsize.x) and offset with (width/2, height/2) to make sampling of
// 0, SectorSize.Y*worldSize/2 sample the value at width/2, height
final class ModScaleOffset : ValueSource {
    ValueSource source;
    vec3d scale;
    vec3d offset;
    this(ValueSource s, vec3d _scale, vec3d _offset) {
        source = s;
        scale = _scale;
        offset = _offset;
    }

    ~this(){
    }

    override double getValue(double x, double y, double z) {
        auto v = source.getValue(x*scale.X + offset.X, y*scale.Y + offset.Y, z*scale.Z + offset.Z);
        return v;
    }

    override double getValue(double x, double y) {
        auto v = source.getValue(x*scale.X + offset.X, y*scale.Y + offset.Y);
        return v;
    }
    override double getValue(double x) {
        auto v = source.getValue(x*scale.X + offset.X);
        return v;
    }
}

//A more sane version of the cryptic stuff above.
// Maps for example (100, 100, 200, 200) to (10, 10). Derp.
auto MapRectToSize(ValueSource s, Rectd sourceRect, vec2d targetSize) {
    return new ModScaleOffset(s, (sourceRect.size / targetSize).vec3, sourceRect.start.vec3);
}

/*
// A more sane version of the cryptic one above.
final class MapRectToSize : ValueSource {
    ValueSource source;
    Rectd sourceRect;
    vec2d targetRange;
    this(ValueSource s, Rectd _sourceRect, vec2d _targetRange) {
        source = s;
        sourceRect = _sourceRect;
        targetRange = _targetRange;
    }

    ~this(){
    }

    override double getValue(double x, double y, double z) {
        enforce(0, "MapRectToSize is not implemented for 3-D querying.");
        return double.init;
    }

    override double getValue(double x, double y) {
        //X, Y in range 0->1
        auto X = x / scale.X;
        auto Y = y / scale.Y;
        //X, Y -> range 0->sourceSize
        X *= sourceRect.size.X;
        Y *= sourceRect.size.Y;
        //X, Y -> range start->end
        X += sourceRect.start.X;
        Y += sourceRect.start.Y;
        auto v = source.getValue(X, Y);

        return v;
    }
    override double getValue(double x) {
        enforce(0, "MapRectToSize is not implemented for 1-D querying.");
    }
}
*/
