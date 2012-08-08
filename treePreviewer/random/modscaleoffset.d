module random.modscaleoffset;

import util.util;
import random.random;

//Scale and offset. For example, to use a valuemap(width, height) as source for world height,
// we want to scale with width/(worldSize*sectorsize.x) and offset with (width/2, height/2) to make sampling of
// 0, SectorSize.Y*worldSize/2 sample the value at width/2, height
class ModScaleOffset : ValueSource {
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
    
    double getValue(double x, double y, double z) {
        auto v = source.getValue(x*scale.X + offset.X, y*scale.Y + offset.Y, z*scale.Z + offset.Z);
        return v;
    }
    
    double getValue(double x, double y) {
        auto v = source.getValue(x*scale.X + offset.X, y*scale.Y + offset.Y);
        return v;
    }
    double getValue(double x) {
        auto v = source.getValue(x*scale.X + offset.X);
        return v;
    }
}


class AddSources : ValueSource {
    ValueSource source1;
    ValueSource source2;
    this(ValueSource s1, ValueSource s2) {
        source1 = s1;
        source2 = s2;
    }

    ~this(){
    }

    double getValue(double x, double y, double z) {
        auto v = source1.getValue(x, y, z) + source2.getValue(x, y, z);
        return v;
    }

    double getValue(double x, double y) {
        auto v = source1.getValue(x, y) + source2.getValue(x, y);
        return v;
    }
    double getValue(double x) {
        auto v = source1.getValue(x) + source2.getValue(x);
        return v;
    }
}



