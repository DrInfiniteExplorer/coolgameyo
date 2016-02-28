
//TODO: Horrible horrible threading in D! typecasts required and all is mad-sad! :(

module graphics.debugging;

import std.array : array;

import cgy.math.vector;

import cgy.opengl.error : glError;
import graphics.ogl;
import cgy.math.aabb : aabb3d;
import cgy.util.util;

struct AABBData{
    vec3f color;
    float radius;
    aabb3d aabb;

    bool opEquals(const AABBData o) const {
        return color == o.color && radius == o.radius && aabb == o.aabb;
    }
    bool opEquals(shared const AABBData o) shared const {
        return cast(AABBData)this == cast(AABBData)o;
    }
}

shared AABBData[int] aabbList;
shared int aabbCount=1;

int addAABB(aabb3d aabb, vec3f color=vec3f(1, 0, 0), float radius=100) {

/*
    auto d = AABBData(color, radius, aabb);
    auto t = aabbCount;
    aabbList[t] = cast(shared(AABBData))d;
    aabbCount++;
    return t;
    */
    return 0;
}

void removeAABB(int id) {
    aabbList.remove(id);
}

void renderAABBList(vec3d camPos, void delegate (vec3f color, float radius) set){

    vec3d[8] corners;
    vec3f[8] fcorners;
    immutable ubyte[] indices = [0, 1, 0, 4, 0, 2, 2, 6, 2, 3, 5, 1, 5, 4, 6, 2, 6, 4, 6, 7, 7, 5, 7, 3];
    foreach(data ; aabbList) {

        //aabbd bb = cast(aabbd)data.aabb;
        aabb3d bb = (cast(aabb3d)data.aabb);
        bb.translate(-camPos);
        corners = bb.getCorners();
        foreach(idx, v ; corners) {
            fcorners[idx] = v.convert!float; //Lol! Men om som innan att vi skickar doubles så kraschar det på lubens dator här :P
        }
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vec3f.sizeof, fcorners.ptr);
        //glVertexAttribPointer(0, 3, GL_DOUBLE, GL_FALSE, vec3d.sizeof, edges.ptr);
        glError();
        set(cast(vec3f)data.color, data.radius);
        static assert(indices.length == 24, "Derp herp ,mnnbv");
        glDrawElements(GL_LINES, 24, GL_UNSIGNED_BYTE, indices.ptr);        
    }
}


struct LineData{
    vec3d[] points;
    vec3f color;
    float radius;

    bool opEquals(const LineData o) const {
        return color == o.color && radius == o.radius && points == o.points;
    }
    bool opEquals(shared const LineData o) shared const {
        return cast(LineData)this == cast(LineData)o;
    }
}

shared LineData[int] lineList;
shared int lineCount=1;

int addLine(vec3d[] points, vec3f color = vec3f(0, 0, 1), float radius = 50){
    auto d = LineData(points.array, color, radius);
    auto t = lineCount;
    lineList[t] = cast(shared)d;
    core.atomic.atomicOp!"+="(lineCount,1);
    return t;
}

void removeLine(int id){
    lineList.remove(id);
}

void renderLineList(vec3d camPos, void delegate (vec3f color, float radius) set){
    foreach(data ; lineList) {
        foreach(ref pt ; data.points) {
            auto a = (cast(vec3d)pt)-camPos;
            pt = a;
            //pt.x = a.x;
            //pt.y = a.y;
            //pt.z = a.z;
        }
        glVertexAttribPointer(0, 3, GL_DOUBLE, GL_FALSE, vec3d.sizeof, cast(const void*)data.points.ptr);
        glError();
        set(cast(vec3f)data.color, data.radius);
        glDrawArrays(GL_LINE_STRIP, 0, cast(int)data.points.length);
        foreach(ref pt ; data.points) {
            auto a = (cast(vec3d)pt)+camPos;
            //pt.x = a.x;
            //pt.y = a.y;
            //pt.z = a.z;
            pt = a;
        }
    }
}






