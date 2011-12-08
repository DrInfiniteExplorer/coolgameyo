module graphics.renderconstants;

import util.util;

immutable vec3f NightBlue = vec3f(0.2, 0.2, 0.5);
immutable vec3f SunLighty = vec3f(1.0, 1.0, 1.0);
immutable vec3f SunSet    = vec3f(0.9, 0.9, 0.7);
immutable vec3f SunSetter = vec3f(0.4, 0.4, 0.5);
immutable vec3f[] SkyColors = [
    SunSet,
    SunSetter,
    NightBlue,
    NightBlue,
    SunSet,
    SunLighty,
    SunLighty,
    SunLighty,
    SunSet,
    SunSetter,
    NightBlue,
];

