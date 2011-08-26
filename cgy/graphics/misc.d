

module graphics.misc;

import util.util;


vec3f[] makeCube(vec3f size=vec3f(1, 1, 1), vec3f offset=vec3f(0, 0, 0)){
    alias vec3f v;
    enum a = 0.5f;
    vec3f ret[] = [
        v(-a, -a, -a), v(a, -a, -a), v(a, -a, a), v(-a, -a, a), //front face (y=-a)
        v(a, -a, -a), v(a, a, -a), v(a, a, a), v(a, -a, a), //right face (x=a)
        v(a, a, -a), v(-a, a, -a), v(-a, a, a), v(a, a, a), //back face(y=a)
        v(-a, a, -a), v(-a, -a, -a), v(-a, -a, a), v(-a, a, a), //left face(x=-a)
        v(-a, -a, a), v(a, -a, a), v(a, a, a), v(-a, a, a), //top face (z = a)
        v(-a, a, -a), v(a, a, -a), v(a, -a, -a), v(-a, -a, -a) //bottom face (z=-a)
    ];
    foreach(i; 0..ret.length){
        auto vert = ret[i];
        vert *= size;
        vert += offset;
        ret[i] = vert;
    }
    return ret;
}


