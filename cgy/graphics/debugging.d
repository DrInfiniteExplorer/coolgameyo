
module graphics.debugging;

import util;
import graphics.ogl;

struct AABBData{
    vec3f color;
    float radius;
    aabbd aabb;
}

AABBData[int] aabbList;
int aabbCount=0;


int addAABB(aabbd aabb, vec3f color=vec3f(1.f, 0.f, 0.f), float radius=100.f) {
    auto d = AABBData(color, radius, aabb);
    auto t = aabbCount;
    aabbList[t] = d;
    aabbCount++;
    return t;
}

void renderAABBList(void delegate (vec3f color, float radius) set){
    vec3d[8] edges;
    immutable ubyte[] indices = [0, 1, 0, 4, 0, 2, 2, 6, 2, 3, 5, 1, 5, 4, 6, 2, 6, 4, 6, 7, 7, 5, 7, 3];
    foreach(data ; aabbList) {
        auto bb = data.aabb;
        bb.getEdges(edges);
        glVertexAttribPointer(0, 3, GL_DOUBLE, GL_FALSE, vec3d.sizeof, edges.ptr);
        glError();
        set(data.color, data.radius);
        glDrawElements(GL_LINES, indices.length, GL_UNSIGNED_BYTE, indices.ptr);        
    }
}








