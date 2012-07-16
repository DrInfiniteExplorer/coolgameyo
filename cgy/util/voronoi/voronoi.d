module util.voronoi.voronoi;

import std.algorithm;
import std.math;
import std.random;
import std.stdio;

alias std.math.abs abs;

import util.util;


import statistics;


final class HalfEdge {

    HalfEdge _reverse;
    HalfEdge next;

    Vertex vertex;
    Site left;

    double angle; //Angle of the half-edge. Ie. angle of line between sites.

    this(Site l, Site right) {
        left = l;
        l.halfEdges ~= this;

        if(right !is null) {
            angle = atan2(right.pos.Y - left.pos.Y, right.pos.X - left.pos.X);
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

    void nuke() {
        bool pred(HalfEdge e) {
            return e is this;
        }
        left.halfEdges = remove!pred(left.halfEdges);
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
            return (_reverse.vertex.pos - vertex.pos).normalize();
        }
        if(_reverse !is null) {
            auto tmp = _reverse.left.pos - left.pos;
            return vec2d(-tmp.Y, tmp.X).normalize();
        }
        BREAKPOINT;
        return vec2d.init;
    }

    override int opCmp(Object _o) {
        HalfEdge o = cast(HalfEdge) _o;
        if(angle == o.angle) return 0;
        if(angle > o.angle) return 1;
        return -1;
    }

}


final class Edge {

    HalfEdge halfLeft;
    HalfEdge halfRight;

    bool derp = false;

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

    vec2d dir() const @property {
        if(halfLeft.vertex !is null && halfRight.vertex !is null) {
            return halfRight.vertex.pos - halfLeft.vertex.pos;
        }

        auto ortho = vec2d(halfRight.left.pos - halfLeft.left.pos);
        ortho = vec2d(-ortho.Y, ortho.X);
        //if(derp) ortho = -ortho;
        return ortho.normalize();
    }

    vec2d center() @property {
        return (halfLeft.left.pos + halfRight.left.pos) * 0.5;
    }

}

final class Vertex {
    vec2d pos;

    this(vec2d pt) {
        pos = pt;
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
}


final class VoronoiPoly {
    Edge[] edges;
    Vertex[] vertices;
    Site[] sites;
    HalfEdge[] halfEdges;


    void scale(vec2d scale) {
        foreach(vert ; vertices) {
            vert.pos *= scale;
        }
        foreach(site ; sites) {
            site.pos *= scale;
        }

    }

    //This works fine now, i think, so long as the sites only share one edge. Otherwise, strange things happen :)
    Site mergeSites(Site a, Site b) {
        writeln("s e he ", sites.length, " ", edges.length, " ", halfEdges.length);
        scope(exit) writeln("s e he ", sites.length, " ", edges.length, " ", halfEdges.length);
        //Loop and find the connection using the shortest loop.
        if(a.halfEdges.length < b.halfEdges.length) {
            swap(a, b);
        }
        foreach(he ; b.halfEdges) {
            if(he.right is a) {

                //Find and eliminate as long a stretch as possible along this border.



                // Knit together the half-edge-struct
                auto he_r = he.reverse;
                auto he_prev = he.prev;
                auto he_next = he.next;
                auto he_r_prev = he_r.prev;
                auto he_r_next = he_r.next;
                he_prev.next = he_r_next;
                he_r_prev.next = he_next;

                //Now he and he_r are dangling pointers. No other half-edge points to them.
                // There is an edge, and there is a reference each in the site's lists of
                // half-edges referencing them.
                
                // Make the half-edges switch alegiance to b!
                auto iter = he_next;
                while(iter.next !is he_r_next) {
                    iter.left = b;
                    iter = iter.next;
                }
                //They are no longer sorted!
                //Add the half-edges from the small to the big
                b.halfEdges ~= a.halfEdges;
                a.halfEdges = null;

                //Remove the small site.
                sites = remove!(s => s is a)(sites);

                //Remove the two evil half-edges.
                bool heInB(HalfEdge h) {
                    return (h is he) || (h is he_r);
                }
                b.halfEdges = remove!heInB(b.halfEdges);
                halfEdges = remove!heInB(halfEdges);

                bool edgePred(Edge edge){
                    return (edge.halfLeft is he || edge.halfRight is he);
                }
                edges = remove!edgePred(edges);

                return b;
            }
        }
        msg("WARNING! Tried to merge two voronoi cells which where not neighbors");
        return null;
    }


    //This code runs under the assumption that sites are never outside of the box.
    void cutDiagram(vec2d min, vec2d max) {
        mixin(MeasureTime!"Time to cut diagram:");


        auto minX = min.X;
        auto minY = min.Y;
        auto maxX = max.X;
        auto maxY = max.Y;

        bool inside(vec2d pos) {
            enum epsilon = 1E-6;
            return (pos.X+epsilon >= minX && pos.X-epsilon <= maxX &&
                    pos.Y+epsilon >= minY && pos.Y-epsilon <= maxY);
        }

        vec2d intersect(vec2d start, vec2d dir) {
            BREAK_IF(!inside(start));
            double dx;
            double dy;
            dx = (dir.X > 0) ? maxX - start.X : start.X - minX;
            dy = (dir.Y > 0) ? maxY - start.Y : start.Y - minY;
            double tx = dx / abs(dir.X);
            double ty = dy / abs(dir.Y);
            double t = std.algorithm.min(tx, ty);
            BREAK_IF(t < 0);
            return start + dir * t;
        }

        bool hits(vec2d start, vec2d dir) {
            BREAK_IF(inside(start));
            double dx1, dy1;
            double dx2, dy2;
            dx1 = (start.X < minX) ? minX - start.X : maxX - start.X;
            dx2 = (start.X < minX) ? maxX - start.X : minX - start.X;
            dy1 = (start.Y < minY) ? minY - start.Y : maxY - start.Y;
            dy2 = (start.Y < minY) ? maxY - start.Y : minY - start.Y;

            double txMin = dx1 / dir.X;
            double txMax = dx2 / dir.X;
            double tyMin = dy1 / dir.Y;
            double tyMax = dy2 / dir.Y;
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

        HalfEdge[HalfEdge] toRemoveHalf;
        bool pred(Edge e) {
            if(e in toRemove) {
                toRemoveHalf[e.halfLeft] = e.halfLeft;
                toRemoveHalf[e.halfRight] = e.halfRight;
                e.nuke();
                //remove e
                return true;
            }
            return false;
        }

        edges = remove!pred(edges);

        bool pred2(HalfEdge e) {
            return (e in toRemoveHalf) !is null;
        }
        halfEdges = remove!pred2(halfEdges);
        vertices = remove!"!a.isAlive()"(vertices);

        bool aboutSameV(Vertex A, Vertex B) {
            auto a = A.pos;
            auto b = B.pos;
            enum epsilon = 1E-4;
            return (abs(a.X-b.X) < epsilon) && (abs(a.Y-b.Y) < epsilon);
        }
        bool aboutSame(double a, double b) {
            enum epsilon = 1E-4;
            return abs(a-b) < epsilon;
        }

        foreach(site ; sites) {
            site.halfEdges.sort;
            int edgeCount = site.halfEdges.length;
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

                    bool right = aboutSame(currEnd.pos.X, maxX);
                    bool up = aboutSame(currEnd.pos.Y, maxY);
                    bool left = aboutSame(currEnd.pos.X, minX);
                    bool down = aboutSame(currEnd.pos.Y, minY);

                    //Ensure is @ about edge of bb - otherwise error! :S
                    BREAK_IF(!right && !up && !left && !down);

                    HalfEdge newHalf;

                    if(right && !up) {
                        if(aboutSame(nextStart.pos.X, maxX)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(maxX, maxY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(up && !left) {
                        if(aboutSame(nextStart.pos.Y, maxY)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(minX, maxY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(left && !down) {
                        if(aboutSame(nextStart.pos.X, minX)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(minX, minY));
                            vertices ~= newVert;
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(down && !right) {
                        if(aboutSame(nextStart.pos.Y, minY)) {
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
                    edgeCount+=1;
                }
                if(curr._reverse.left is null) { //Delete temporary reverse-he used to span the edge.
                    curr._reverse = null;
                }
            }
        }

    }
}
