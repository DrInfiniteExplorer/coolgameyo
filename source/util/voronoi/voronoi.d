module util.voronoi.voronoi;

import std.algorithm;
import std.array;
import std.math;
import std.random;
import std.stdio;

alias std.math.abs abs;

import util.util;
import util.filesystem;


import statistics;


final class HalfEdge {

    HalfEdge _reverse;
    HalfEdge next;

    Vertex _vertex;
    Site left;

    void serialize(BinaryWriter writer, int[HalfEdge] halfEdges, int[Vertex] vertices, int[Site] sites) {
        if(_reverse is null) {
            writer.write(-1);
        } else {
            writer.write(halfEdges[_reverse]);
        }
        if(next is null) {
            writer.write(-1);
        } else {
            writer.write(halfEdges[next]);
        }
        writer.write(vertices[_vertex]);
        writer.write(sites[left]);
    }
    void deserialize(BinaryReader reader, HalfEdge[] halfEdges, Vertex[] vertices, Site[] sites) {

        _reverse = null;
        next = null;

        int id;
        reader.read(id);
        if(id != -1) {
            _reverse = halfEdges[id];
        }
        reader.read(id);
        if(id != -1) {
            next = halfEdges[id];
        }
        reader.read(id);
        _vertex = vertices[id];
        reader.read(id);
        left = sites[id];
    }

    double angle; //Angle of the half-edge. Ie. angle of line between sites.

    void vertex(Vertex v) @property {
        if(_vertex !is null) {
            _vertex.edge = null;
        }
        _vertex = v;
        if(vertex !is null) {
            _vertex.edge = this;
        }
    }

    Vertex vertex() @property {
        return _vertex;
    }

    this(Site l, Site right) {
        left = l;
        l.halfEdges ~= this;

        if(right !is null) {
            angle = atan2(right.pos.y - left.pos.y, right.pos.x - left.pos.x);
        }
    }

    //Added for border half-edges
    this(HalfEdge prev, Vertex vert, Vertex endVert) {
        vert.Ref();
        endVert.Ref();
        prev.next = this;
        left = prev.left;
        vertex = vert;
        new HalfEdge(this, endVert);
    }
    //Helper for the one above
    private this(HalfEdge rev, Vertex endVert) {
        rev.reverse = this;
        vertex = endVert;
    }

    //Helper for creating an empty shite.
    this() {
    }

    void nuke() {
        left.halfEdges = left.halfEdges.remove(countUntil(left.halfEdges, this));
        if(vertex !is null) {
            vertex.unRef();
        }
        _reverse = null;
        next = null;
        vertex = null;
        left = null;
    }

    Site right() @property {

        if(_reverse !is null) return _reverse.left;
        return null;
    }

    void reverse(HalfEdge r) @property {
        _reverse = r;
        r._reverse = this;
    }
    HalfEdge reverse() @property {
        return _reverse;
    }

    HalfEdge prev() @property {
        HalfEdge he = this;
        while(he.next !is this) {
            he = he.next;
        }
        return he;
    }

    Vertex getStartPoint() {
        return vertex;
    }
    Vertex getEndPoint() {
        if(_reverse !is null) {
            return _reverse.vertex;
        } else if(next !is null) {
            return next.vertex;
        }
        return null;
    }

    vec2d dir() @property {
        if(vertex !is null && _reverse.vertex !is null) {
            return (_reverse.vertex.pos - vertex.pos).normalizeThis();
        }
        if(_reverse !is null) {
            auto tmp = _reverse.left.pos - left.pos;
            return vec2d(-tmp.y, tmp.x).normalizeThis();
        }
        BREAKPOINT;
        return vec2d.init;
    }

//    override int opCmp(Object _o) {
//        HalfEdge o = cast(HalfEdge) _o;
//        if(angle == o.angle) return 0;
//        if(angle > o.angle) return 1;
//        return -1;
//    }

//    override size_t toHash() { return vertex.toHash; }

//    override bool opEquals(Object _o)
//    {
//        HalfEdge o = cast(HalfEdge) _o;
//        return o && angle == o.angle;
//    }
}


final class Edge {

    HalfEdge halfLeft;
    HalfEdge halfRight;

    bool derp = false;

    void serialize(BinaryWriter writer, int[HalfEdge] halfEdges) {
        if(halfLeft is null) {
            writer.write(-1);
        } else {
            writer.write(halfEdges[halfLeft]);
        }
        if(halfRight is null) {
            writer.write(-1);
        } else {
            writer.write(halfEdges[halfRight]);
        }
        writer.write(derp);
    }
    void deserialize(BinaryReader reader, HalfEdge[] halfEdges) {
        int id;
        halfLeft = null;
        halfRight = null;
        reader.read(id);
        if(id != -1) {
            halfLeft = halfEdges[id];
        }
        reader.read(id);
        if(id != -1) {
            halfRight = halfEdges[id];
        }
        reader.read(derp);
    }

    this(Site left, Site right, Vertex vA = null, Vertex vB = null) {

        halfLeft = new HalfEdge(left, right);
        halfRight = new HalfEdge(right, left);
        halfLeft.reverse = halfRight;
        if(vA !is null) {
            setStartPoint(left, right, vA);
        }
        if(vB !is null) {
            setEndPoint(left, right, vB);
        }
    }

    this() {
        //Derp.
    }

    void nuke() {
        bool pred(Edge e) {
            return e is this;
        }
        halfLeft.nuke();
        halfRight.nuke();

    }

    Vertex getStartPoint() {
        if(halfLeft.vertex is null) {
            BREAK_IF(halfRight.vertex !is null);
            return null;
        }
        return halfLeft.vertex;
    }
    Vertex getEndPoint() {
        BREAK_IF(halfLeft.vertex is null);
        if(halfRight.vertex is null) return null;
        return halfRight.vertex;
    }

    void setStartPoint(Site left, Site right, Vertex vert) {
        //Define the direction of the edge to be the direction
        //which we don't add a vertex to first. :P
        if(halfLeft.vertex is null && halfRight.vertex is null) {
            if(left !is halfLeft.left) {
                swap(halfLeft, halfRight);
            }
            halfLeft.vertex = vert;
            vert.Ref();
        } else if(halfLeft.left is right) {
            BREAK_IF(halfRight.vertex !is null);
            halfRight.vertex = vert;
            vert.Ref();
        } else if(halfLeft.left is left) {
            BREAK_IF(halfLeft.vertex !is null);
            halfLeft.vertex = vert;
            vert.Ref();
        } else {
            BREAKPOINT;
            //How did we get here?
            // A bug!
        }
    }
    void setEndPoint(Site left, Site right, Vertex vert) {
        setStartPoint(right, left, vert);
    }

    void looseEnd() {
        BREAK_IF(halfLeft.vertex is null);
        halfRight.vertex.unRef();
        halfRight.vertex = null;
    }

    void looseStart() {
        if(halfLeft.vertex is null) {
            BREAK_IF(halfRight.vertex !is null);
            return;
        }
        if(halfRight.vertex is null) {
            halfLeft.vertex.unRef();
            halfLeft.vertex = null;
            return;
        }
        //has both. swap dir of edge.
        halfLeft.vertex.unRef();
        halfLeft.vertex = null;
        swap(halfLeft, halfRight);
    }

    vec2d dir() @property {
        if(halfLeft.vertex !is null && halfRight.vertex !is null) {
            return halfRight.vertex.pos - halfLeft.vertex.pos;
        }

        auto ortho = halfRight.left.pos - halfLeft.left.pos;
        ortho = vec2d(-ortho.y, ortho.x);
        //if(derp) ortho = -ortho;
        return ortho.normalizeThis();
    }

    vec2d center() @property {
        return (halfLeft.left.pos + halfRight.left.pos) * 0.5;
    }

}

final class Vertex {
    vec2d pos;
    HalfEdge edge;

    this(vec2d pt) {
        pos = pt;
    }

    HalfEdge[] getEdges() {
        HalfEdge[] ret;
        auto edge = edge;
        auto startEdge = edge;
        do{
            ret ~= edge;
            edge = edge.next;
        }while(edge !is null && edge != startEdge);
        return ret;
    }


    void serialize(BinaryWriter writer, int[HalfEdge] halfEdges) {
        writer.write(pos);
        if(edge in halfEdges) {
            writer.write(halfEdges[edge]);
        } else {
            //msg("Wut? A loose vertex? Nevermind, ignore.");
            writer.write(-1);
        }
    }
    void deserialize(BinaryReader reader, HalfEdge[] halfEdges) {
        reader.read(pos);
        edge = null;
        int id;
        reader.read(id);
        if(id != -1) {
            edge = halfEdges[id];
        }
    }


    int refCnt = 0;
    void Ref() { refCnt++; }
    void unRef() { refCnt--;};
    bool isAlive() { return refCnt > 0; }
}

final class Site {

    this(vec2d pt, int id) {
        pos = pt;
        siteId = id;
    }

    int siteId;
    vec2d pos;
    HalfEdge[] halfEdges;

    void serialize(BinaryWriter writer, int[HalfEdge] halfEdgeMap) {
        writer.write(siteId);
        writer.write(pos);
        int len = cast(int)halfEdges.length;
        writer.write(len);
        foreach(idx, he ; halfEdges) {
            if(he in halfEdgeMap) {
                writer.write(halfEdgeMap[he]);
            } else {
                msg("Error at ", siteId, ":", idx, " of ", halfEdges.length, "/", halfEdgeMap.keys.length);
                BREAKPOINT;
            }
        }
    }

    void deserialize(BinaryReader reader, HalfEdge[] he) {
        reader.read(siteId);
        reader.read(pos);
        this.halfEdges.length = reader.read!int;
        int id;
        foreach(ref h ; this.halfEdges) {
            reader.read(id);
            h = he[id];
        }
    }

    //TODO: Turn into delegate?
    Site[] getNeighbors() {
        return array(map!"a.right"(halfEdges));
    }
}


final class VoronoiPoly {
    Edge[] edges;
    Vertex[] vertices;
    Site[] sites;
    HalfEdge[] halfEdges;

    void serialize(string path) {
        auto file = BinaryFile(path, "w");
        auto writer = file.writer;

        int[Edge] edgeMap;
        int[Vertex] vertexMap;
        int[Site] siteMap;
        int[HalfEdge] halfEdgeMap;

        foreach(idx, edge ; edges) {
            edgeMap[edge] = cast(int)idx;
        }
        foreach(idx, vertex; vertices) {
            vertexMap[vertex] = cast(int)idx;
        }
        foreach(idx, site ; sites) {
            siteMap[site] = cast(int)idx;
        }
        foreach(idx, he; halfEdges) {
            halfEdgeMap[he] = cast(int)idx;
        }

        writer.write!int(cast(int)sites.length);
        writer.write!int(cast(int)vertices.length);
        writer.write!int(cast(int)halfEdges.length);
        writer.write!int(cast(int)edges.length);

        foreach(site ; sites) {
            site.serialize(writer, halfEdgeMap);
        }
        foreach(vertex ; vertices) {
            vertex.serialize(writer, halfEdgeMap);
        }
        foreach(halfEdge ; halfEdges) {
            halfEdge.serialize(writer, halfEdgeMap, vertexMap, siteMap);
        }
        foreach(edge ; edges) {
            edge.serialize(writer, halfEdgeMap);
        }
    }

    void deserialize(string path) {
        auto file = BinaryFile(path, "r");
        auto reader = file.reader;

        sites.length = reader.read!int();
        vertices.length = reader.read!int();
        halfEdges.length = reader.read!int();
        edges.length = reader.read!int();

        auto nan2 = vec2d(double.nan);

        
        foreach(ref site ; sites) {
            site = new Site(nan2, -1);
        }
        foreach(ref vertex ; vertices) {
            vertex = new Vertex(nan2);
        }
        foreach(ref halfEdge ; halfEdges) {
            halfEdge = new HalfEdge;
        }
        foreach(ref edge ; edges) {
            edge = new Edge;
        }

        foreach(ref site ; sites) {
            site.deserialize(reader, halfEdges);
        }
        foreach(ref vertex ; vertices) {
            vertex.deserialize(reader, halfEdges);
        }
        foreach(ref halfEdge ; halfEdges) {
            halfEdge.deserialize(reader, halfEdges, vertices, sites);
        }
        foreach(ref edge ; edges) {
            edge.deserialize(reader, halfEdges);
        }
    }

    void scale(vec2d scale) {
        foreach(vert ; vertices) {
            vert.pos *= scale;
        }
        foreach(site ; sites) {
            site.pos *= scale;
        }

    }

    //This code runs under the assumption that sites are never outside of the box.
    void cutDiagram(vec2d min, vec2d max) {
        mixin(MeasureTime!"Time to cut diagram:");

        auto minX = min.x;
        auto minY = min.y;
        auto maxX = max.x;
        auto maxY = max.y;

        bool inside(vec2d pos) {
            immutable epsilon = 1E-6;
            return (pos.x+epsilon >= minX && pos.x-epsilon <= maxX &&
                    pos.y+epsilon >= minY && pos.y-epsilon <= maxY);
        }

        vec2d intersect(vec2d start, vec2d dir) {
            BREAK_IF(!inside(start));
            double dx;
            double dy;
            dx = (dir.x > 0) ? maxX - start.x : start.x - minX;
            dy = (dir.y > 0) ? maxY - start.y : start.y - minY;
            double tx = dx / abs(dir.x);
            double ty = dy / abs(dir.y);
            double t = std.algorithm.min(tx, ty);
            BREAK_IF(t < 0);
            return start + dir * t;
        }

        bool hits(vec2d start, vec2d dir) {
            BREAK_IF(inside(start));
            double dx1, dy1;
            double dx2, dy2;
            dx1 = (start.x < minX) ? minX - start.x : maxX - start.x;
            dx2 = (start.x < minX) ? maxX - start.x : minX - start.x;
            dy1 = (start.y < minY) ? minY - start.y : maxY - start.y;
            dy2 = (start.y < minY) ? maxY - start.y : minY - start.y;

            double txMin = dx1 / dir.x;
            double txMax = dx2 / dir.x;
            double tyMin = dy1 / dir.y;
            double tyMax = dy2 / dir.y;
            if(txMin < 0 || txMax < 0 || tyMin < 0 || tyMax < 0) return false;
            return (tyMax > txMin) || (txMax > tyMin);
        }

        Edge[Edge] toRemove;
        foreach(edge ; edges) {
            auto start = edge.getStartPoint();
            auto end = edge.getEndPoint();

            if(start !is null && end !is null && !inside(start.pos) && !inside(end.pos)) {

                toRemove[edge] = edge;

                edge.looseEnd();
                edge.looseStart();
                continue;
            }

            if(end && !inside(end.pos)) {
                edge.looseEnd();
                end = null;
            }
            if(start && !inside(start.pos)) {
                edge.looseStart(); //Will still retain info about direction.
                if(end is null) {
                    if(!hits(start.pos, edge.dir)) {
                        toRemove[edge] = edge;
                        continue;
                    }
                }
                start = end;
                end = null;
            }
            if(start is null) {
                //Place vertex at start
                auto pos = edge.center;
                auto dir = edge.dir;
                auto endPos = intersect(pos, dir);
                BREAK_IF(!inside(endPos));
                auto newVert = new Vertex(endPos);
                vertices ~= newVert;
                edge.setStartPoint(edge.halfRight.left, edge.halfLeft.left, newVert);
            }
            if(end is null) {
                auto pos = edge.getStartPoint().pos;
                auto dir = edge.dir;
                auto endPos = intersect(pos, dir);
                auto newVert = new Vertex(endPos);
                vertices ~= newVert;
                edge.setEndPoint(edge.halfLeft.left, edge.halfRight.left, newVert);
            }
        }

        Site[HalfEdge] toRemoveHalf;
        int[] edgesToRemove;
        foreach(idx, e ; edges) {
            if(e in toRemove) {
                toRemoveHalf[e.halfLeft] = e.halfLeft.left;
                toRemoveHalf[e.halfRight] = e.halfRight.left;
                e.nuke();
                edgesToRemove ~= cast(int)idx;
            }
        }
        edges = edges.remove(edgesToRemove);

        edgesToRemove.length = 0;
        foreach(idx, e ; halfEdges) {
            if(e in toRemoveHalf) {
                edgesToRemove ~= cast(int)idx;
            }
        }
        halfEdges = halfEdges.remove(edgesToRemove);

        foreach(site ; toRemoveHalf) {
            edgesToRemove.length = 0;
            foreach(idx, e ; site.halfEdges) {
                if(e in toRemoveHalf) {
                    edgesToRemove ~= cast(int)idx;
                }
            }
            site.halfEdges = site.halfEdges.remove(edgesToRemove);
        }
        vertices = remove!"!a.isAlive()"(vertices);

        bool aboutSameV(Vertex A, Vertex B) {
            auto a = A.pos;
            auto b = B.pos;
            immutable epsilon = 1E-4;
            return (abs(a.x-b.x) < epsilon) && (abs(a.y-b.y) < epsilon);
        }
        bool aboutSame(double a, double b) {
            immutable epsilon = 1E-4;
            return abs(a-b) < epsilon;
        }

        foreach(site ; sites) {
            std.algorithm.sort(site.halfEdges);
            int edgeCount = cast(int)site.halfEdges.length;
            int c = 0;
            for(int i = 0 ; i < edgeCount; i++) {
                auto curr = site.halfEdges[i];
                auto next = site.halfEdges[ (i+1) % edgeCount];
                auto currEnd = curr.getEndPoint();
                auto nextStart = next.getStartPoint();
                if(aboutSameV(currEnd, nextStart)) {
                    curr.next = next;
                } else {
                    c++; //If we've gone a lap around the box, something is wrong.
                    BREAK_IF(c > 4);

                    bool right = aboutSame(currEnd.pos.x, maxX);
                    bool up = aboutSame(currEnd.pos.y, maxY);
                    bool left = aboutSame(currEnd.pos.x, minX);
                    bool down = aboutSame(currEnd.pos.y, minY);

                    //Ensure is @ about edge of bb - otherwise error! :S
                    BREAK_IF(!right && !up && !left && !down);

                    HalfEdge newHalf;

                    if(right && !up) {
                        if(aboutSame(nextStart.pos.x, maxX)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(maxX, maxY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(up && !left) {
                        if(aboutSame(nextStart.pos.y, maxY)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(minX, maxY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(left && !down) {
                        if(aboutSame(nextStart.pos.x, minX)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(minX, minY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(down && !right) {
                        if(aboutSame(nextStart.pos.y, minY)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(maxX, minY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    if(i == edgeCount-1) {
                        site.halfEdges = site.halfEdges ~ newHalf;
                    } else {
                        site.halfEdges = site.halfEdges[0 .. i+1] ~ newHalf ~ site.halfEdges[i+1 .. $];
                    }
                    halfEdges ~= newHalf;
                    edgeCount+=1;
                }
                if(curr._reverse.left is null) { //Delete temporary reverse-he used to span the edge.
                    curr._reverse = null;
                }
            }
        }

    }
}
