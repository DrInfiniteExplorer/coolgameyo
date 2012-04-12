module worldgen.voronoi;

import std.algorithm;
import std.array;
import std.math;
import std.random;
import std.stdio;

alias std.math.abs abs;

import util.util;
import util.math;


import statistics;


final class HalfEdge {

    HalfEdge _reverse;
    HalfEdge next;

    Vertex vertex;
    Site left;
    Edge edge;


    double angle; //Angle of the half-edge. Ie. angle of line between sites.

    this(Edge e, Site l, Site right) {
        edge = e;
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
        edge = null;
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


class Edge {

    //Site leftSite;
    //Site rightSite;

    //Vertex vertA;
    //Vertex vertB;

    HalfEdge halfLeft;
    HalfEdge halfRight;

    bool derp = false;

    this(Site left, Site right, Vertex vA = null, Vertex vB = null) {

        halfLeft = new HalfEdge(this, left, right);
        halfRight = new HalfEdge(this, right, left);
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

    /*
    void add(Vertex vert) {
        if(vertA is null) {
            vertA = vert;
        }else if(vertB is null) {
            vertB = vert;
        } else {
            BREAKPOINT;
        }
        vert.edges ~= this;
    }
    */

    vec2d dir() const @property {
        if(halfLeft.vertex !is null && halfRight.vertex !is null) return halfRight.vertex.pos - halfLeft.vertex.pos;


        auto ortho = vec2d(halfRight.left.pos - halfLeft.left.pos);
        ortho = vec2d(-ortho.Y, ortho.X);
        //if(derp) ortho = -ortho;
        return ortho.normalize();
    }

    vec2d center() @property {
        return (halfLeft.left.pos + halfRight.left.pos) * 0.5;
    }

    void setAngle(Site s) {
        /*
        vec2d pos;
        if(halfLeft.vertex !is null && halfRight.vertex !is null) {
            pos = (halfLeft.vertex.pos + halfRight.vertex.pos) * 0.5;
            auto toA = halfLeft.vertex.pos - s.pos;
            auto toB = halfRight.vertex.pos - s.pos;
            auto bInA = vec2d(toB.X * toA.X + toB.Y * toA.Y, toB.Y * toA.X - toB.X * toA.Y);
            if(atan2(bInA.Y, bInA.X) < 0) {
                swap(vertA, vertB);
            }

        } else {
            BREAK_IF(halfLeft.vertex is null);
            pos = halfLeft.vertex.pos;
        }
        auto toEdge = pos - s.pos;
        angle = atan2(toEdge.Y, toEdge.X);
        */
    }

}

class Vertex {
    vec2d pos;

    this(vec2d pt) {
        pos = pt;
    }

    int refCnt = 0;
    void Ref() { refCnt++; }
    void unRef() { refCnt--;};
    bool isAlive() { return refCnt > 0; }
}

class Site {

    this(vec2d pt, int id) {
        pos = pt;
        siteId = id;
    }
    int siteId;
    vec2d pos;
    HalfEdge[] halfEdges;
}


final class Voronoi {

    int width;
    int height;

    this(int numWidth, int numHeight) {
        width = numWidth;
        height = numHeight;
        queue = new PQ;

        Random gen;
        gen.seed(cast(uint)8801284210);
        vec2d[] points;
        foreach(y ; 0 .. numHeight) {
            foreach(x ; 0 .. numWidth) {
                auto dx = uniform(0.0, 1.0, gen);
                auto dy = uniform(0.0, 1.0, gen);
                points ~= vec2d(x + dx, y + dy);
            }
        }
        makeVoronoi(points);
    }

    TreePart tree;
    PQ queue;
    Edge[] edges;
    Vertex[] vertices;
    Site[] sites;
    CircleEvent[TreeLeaf] currentCircles;

    HalfEdge[] halfEdges;


    TreeLeaf[] handleSiteEvent(SiteEvent e) {
        //writeln("site event! ", e.pos);
        auto site = e.site;
        if(tree is null) {
            tree = new TreeLeaf(site);
            return [];
        } else {
            //Locate existing arc (if any) directly above new site
            //delete potential cirlce event
            TreeLeaf leaf;
            leaf = tree.getLeafNode(e.pos.X, e.pos.Y);
            if(leaf.event) {
                queue.remove(leaf.event);
                leaf.event = null;
            }

            //  Break the arc, replace leaf node with subtree representing new arc & breakpoints
            // add edge in graph
            auto edge = new Edge(leaf.site, site);
            //edge.left = leaf.pos;
            //edge.right = e.pos;
            edges ~= edge;

            TreeNode subNode, subSubNode;
            subNode = new TreeNode(leaf.site, site, edge, false);
            subNode.left = new TreeLeaf(leaf.site);
            subSubNode = new TreeNode(site, leaf.site, edge, true);
            subSubNode.left = new TreeLeaf(site);
            subSubNode.right = new TreeLeaf(leaf.site);
            subNode.right = subSubNode;

            if(leaf.parent is null) {
                tree = subNode;
            } else {
                leaf.parent.replace(leaf, subNode);
            }

            return [cast(TreeLeaf) subNode.left,
                    cast(TreeLeaf)subSubNode.left,
                    cast(TreeLeaf)subSubNode.right];
        }

        //Check for potential circle events, add to queueueue.

    }

    TreeLeaf[] handleCircleEvent(CircleEvent e) {
        //writeln("Circle event! ", e.pos);
        TreeLeaf leaf = e.leaf;
        TreeLeaf left = leaf.getLeftLeaf();
        TreeLeaf right = leaf.getRightLeaf();
        if(left is null || right is null || left.site !is e.left.site || right.site !is e.right.site) {
            //Grafen har ändrats? SHUT DOWN EVERYTHING
            return [];
        }
        //Add vertex to edge in voronoi graph

        auto parentNode = cast(TreeNode)leaf.parent;
        auto vertex = new Vertex(e.center);
        vertices ~= vertex;

        //writeln("New vertex at ", e.center, " from y: ", e.pos.Y);

        //Derp, find herp, and remove part of tree.
        TreeNode otherNode;
        TreeNode leftNode, rightNode;
        if(parentNode.left == leaf) {
            rightNode = parentNode;
            leftNode = otherNode = left.stepRightOnce(); //Goes up along right, then follows a left up once
            parentNode.parent.replace(parentNode, parentNode.right);
        } else {
            leftNode = parentNode;
            rightNode = otherNode = leaf.stepRightOnce();
            parentNode.parent.replace(parentNode, parentNode.left);
        }


//        leftNode.edge.setStartPoint(left.site, leaf.site, vertex);
//        rightNode.edge.setStartPoint(leaf.site, right.site, vertex);
//        auto edge = new Edge(left.site, right.site, null, vertex);
//        edges ~= edge;

        leftNode.edge.setEndPoint(left.site, leaf.site, vertex);
        rightNode.edge.setEndPoint(leaf.site, right.site, vertex);
        auto edge = new Edge(left.site, right.site, vertex);
        edges ~= edge;

        auto newNode = new TreeNode(left.site, right.site, edge, false);
        newNode.left = otherNode.left;
        newNode.right = otherNode.right;
        if(otherNode.parent is null) {
            tree = newNode;
        } else {
            otherNode.parent.replace(otherNode, newNode);
        }

        //Delete the leaf node of the dissapearing arc and its circle event
        //Create new edge in voronoi graph
        //check for new triplets formed by the former neighboring arcs for potential circle events

        return [left, right];
    }

    CircleEvent checkCircleEvent(TreeLeaf leaf, double y) {
        TreeLeaf left = leaf.getLeftLeaf();
        if(left is null) return null;
        TreeLeaf right = leaf.getRightLeaf();
        if(right is null) return null;
        if(leaf.site is right.site || right.site == left.site || left.site == leaf.site) return null;

        double dx1, dx2, dy1, dy2;
		dx1 = leaf.site.pos.X - left.site.pos.X;
        dy1 = leaf.site.pos.Y - left.site.pos.Y;
		dx2 = right.site.pos.X - left.site.pos.X;
        dy2 = right.site.pos.Y - left.site.pos.Y;
		if (dx1*dy2 <= dy1*dx2) {
		    return null;
        }
        auto event = new CircleEvent(left, leaf, right);
        if(event.pos.Y < y) return null;
        return event;
    }

    void handleEvent(Event e) {
        TreeLeaf[] checkCircle;
        if(cast(SiteEvent)e !is null) {
            checkCircle = handleSiteEvent(cast(SiteEvent)e);
        } else if(cast(CircleEvent)e !is null) {
            checkCircle = handleCircleEvent(cast(CircleEvent)e);
        }

        //Potentially destroyed some circles!!
        //and potentially haz new circles too.
        auto y = e.pos.Y; //duh!
        foreach(TreeLeaf leaf ; checkCircle) {
            if(leaf in currentCircles) {
                currentCircles[leaf].valid = false;
                currentCircles.remove(leaf);
                //writeln("FALSE CIRCLE FOUND or more like something?!");
            }
            auto newEvent = checkCircleEvent(leaf, y);
            if(newEvent !is null) {
                //writeln("potential circle found with eventpos ", newEvent.pos);
                currentCircles[leaf] = newEvent;
                queue.add(newEvent);
            }
        }
        //Did we just destroyed a circle?
        if(cast(SiteEvent)e !is null) {
            foreach(circle ; currentCircles) {
                if(circle.center.getDistanceFrom(e.pos) < circle.radius - 1E10) {
                    //writeln("FALSE CIRCLE FOUND with stuff in it!");
                    circle.valid = false;
                }
            }
        }
    }

    void makeVoronoi(vec2d[] points) {
        mixin(MeasureTime!"Time to make voronoi:");

        //points = [ vec2d(100, 100), vec2d(75, 150), vec2d(120, 155), vec2d(60, 160), vec2d(140, 190) ];
        //points = [ vec2d(100, 80), vec2d(230, 100), vec2d(100, 210)];

        CircleEvent[SiteEvent] currentCircles;

        //foreach(pt ; points) {
        //    queue.add(new SiteEvent(pt));
        //}
        queue.add(array(map!(
            (vec2d pt) {
                auto site = new Site(pt, sites.length);
                sites ~= site;
                return cast(Event)new SiteEvent(site);
            })(points)));

        //writeln("starting!");

        while(!queue.empty) {
            auto event = queue.get();
            handleEvent(event);
        }
        //Finish him!

        /*
        void fix(TreePart part) {
            auto node = cast(TreeNode) part;
            if(node is null) return;
            if(node.flipped) {
                auto a = node.edge.leftSite;
                node.edge.leftSite = node.edge.rightSite;
                node.edge.rightSite = a;
            }
            fix(node.left);
            fix(node.right);
        }
        fix(tree);
        */

        //buildHalfEdgeGraph();

    }

    //This code runs under the assumption that sites are never outside of the box.
    void cutDiagram(vec2d min, vec2d max) {


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
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(up && !left) {
                        if(aboutSame(nextStart.pos.Y, maxY)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(minX, maxY));
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(left && !down) {
                        if(aboutSame(nextStart.pos.X, minX)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(minX, minY));
                            newHalf = new HalfEdge(curr, currEnd, newVert);
                        }
                    }
                    else if(down && !right) {
                        if(aboutSame(nextStart.pos.Y, minY)) {
                            newHalf = new HalfEdge(curr, currEnd, nextStart);
                        } else {
                            auto newVert = new Vertex(vec2d(maxX, minY));
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

};


final class PQ {
    Event[] events;

    void add(Event e) {
        events ~= e;
        events.sort;
    }
    void add(Event[] e) {
        events ~= e;
        events.sort;
    }
    Event get() {
        Event ret = events[$-1];
        events.length -= 1;
        assumeSafeAppend(events);
        //events = events[0 .. $-1];
        return ret;
    }
    void remove(Event e) {
        bool pred(Event f) {
            return f == e;
        }
        events = std.algorithm.remove!pred(events);
        events.sort; //Dunno if nexxxecccarry but wutlol!
    }
    bool empty() @property const { return events.length == 0; }
}


class Event {
public:
    vec2d pos;
    override int opCmp(Object _o) {
        auto o = cast(Event)_o;
        if(pos.Y < o.pos.Y) return 1;
        if(pos.Y == o.pos.Y) {
            if(pos.X < o.pos.X) return 1;
            if(pos.X == o.pos.X) return 0;
        }
        return -1;
    }
}

final class SiteEvent : Event {
    Site site;
    this(Site _site) {
        site = _site;
        pos = site.pos;
    }
}
final class CircleEvent : Event {
    TreeLeaf left, leaf, right;
    bool valid;
    vec2d center;
    double radius;
    this(TreeLeaf _left, TreeLeaf _leaf, TreeLeaf _right) {
        left = _left;
        leaf = _leaf;
        right = _right;
        center = CircumCircle(left.site.pos, leaf.site.pos, right.site.pos);
        radius = center.getDistanceFrom(left.site.pos);
        valid = true;
        pos = center + vec2d(0.0, radius);
    }
}


//Represents break-point between arcs
class TreePart {
    TreePart _left;
    TreePart _right;
    TreePart parent;

    void left(TreePart l) @property {
        _left = l;
        l.parent = this;
    }
    TreePart left() @property { return _left; }

    void right(TreePart r) @property {
        _right = r;
        r.parent = this;
    }
    TreePart right() @property { return _right; }

    void replace(TreePart son, TreePart newSon) {
        if(left == son) {
            left = newSon;
        } else if(right == son) {
            right = newSon;
        } else {
            //Dont get here please.
            BREAKPOINT;
        }
    }

    TreeLeaf getLeftLeaf() {
        TreePart node = this;
        //Step up along left edges.
        while(true) {
            if(node.parent is null) {
                return null;
            }
            if(node.parent.left == node) {
                node = node.parent;
            } else {
                node = node.parent; //Step up-left once
                break;
            }
        }
        BREAK_IF(node is null);
        node = node.left;
        while(node.right !is null) {
            node = node.right;
        }
        return cast(TreeLeaf)node;
    }
    TreeLeaf getRightLeaf() {
        TreePart node = this;
        //Step up along left edges.
        while(true) {
            if(node.parent is null) {
                return null;
            }
            if(node.parent.right == node) {
                node = node.parent;
            } else {
                node = node.parent; //Step up-right once
                break;
            }
        }
        BREAK_IF(node is null);
        node = node.right;
        while(node.left !is null) {
            node = node.left;
        }
        return cast(TreeLeaf)node;
    }

    TreeNode stepRightOnce() {
        TreePart node = this;
        //Step up along left edges.
        while(true) {
            BREAK_IF(node is null);
            if(node.parent.right == node) {
                node = node.parent;
            } else {
                node = node.parent; //Step up-right once
                break;
            }
        }
        BREAK_IF(node is null);
        return cast(TreeNode)node;
    }
    TreeLeaf getLeafNode(double x, double y) {
        if(cast(TreeLeaf)this) return cast(TreeLeaf)this;

        TreeNode _this = cast(TreeNode)this;
        if(_this.cut(x, y) < 0) {
            return left.getLeafNode(x, y);
        } else {
            return right.getLeafNode(x, y);
        }
    }


}

final class TreeNode : TreePart {

    Site leftSite, rightSite;
    Edge edge;
    bool flipped;

    this(Site l, Site r, Edge e, bool f) {
        edge = e;
        flipped = f;
        leftSite = l;
        rightSite = r;
    }

    double cut(double x, double y) {
        double cut(vec2d left, vec2d right, double y)
        {
            BREAK_IF(left.getDistanceFrom(right) < 1E-10);
            auto x1 = left.X;
            auto x2 = right.X;
            auto y1 = left.Y;
            auto y2 = right.Y;

            auto toPoint1 = y1 - y;
            auto toPoint2 = y2 - y;

            //If like, very close to both, approximate the point to be in the middle.
			if(abs(toPoint1)<1E-10 && abs(toPoint2)<1E-10) {
				return (x1+x2)/2.0;
            }
            //If like, _very_ close to the left one, then we are like at that point
			if(abs(toPoint1)<1E-10) {
				return x1;
            }
            //If like, _very_ close to the right one, then we are like at that point
			if(abs(toPoint2)<1E-10) {
				return x2;
            }

			double a1 = 1.0/(2.0*toPoint1);
			double a2 = 1.0/(2.0*toPoint2);
			if(abs(a1-a2)<1E-10) { //If.. very far away, and from both, assume middle.
				return (x1+x2)/2.0;
            }

            double xs1 = 0.5/(2*a1 - 2*a2)*(4*a1*x1 - 4*a2*x2 + 2*sqrt(-8*a1*x1*a2*x2 - 2*a1*y1 + 2*a1*y2 + 4*a1*a2*x2*x2 + 2*a2*y1 + 4*a2*a1*x1*x1 - 2*a2*y2));
            double xs2 = 0.5/(2*a1 - 2*a2)*(4*a1*x1 - 4*a2*x2 - 2*sqrt(-8*a1*x1*a2*x2 - 2*a1*y1 + 2*a1*y2 + 4*a1*a2*x2*x2 + 2*a2*y1 + 4*a2*a1*x1*x1 - 2*a2*y2));
			//xs1=Math.Round(xs1,10);
			//xs2=Math.Round(xs2,10);
			if(xs1>xs2) {
                //swap
				double h = xs1;
				xs1=xs2;
				xs2=h;
			}
			if(y1>=y2) {
				return xs2;
            }
			return xs1;
        }


        /*
        if(flipped) {
            return x - cut(rightSite.pos, leftSite.pos, y);
        }
        */
        return x - cut(leftSite.pos, rightSite.pos, y);
        /*
        if(flipped) {
            return x - cut(edge.halfRight.left.pos, edge.halfLeft.left.pos, y);
        }
        return x - cut(edge.halfLeft.left.pos, edge.halfRight.left.pos, y);
        */
    }
}

//Represents an arch.
class TreeLeaf : TreePart {

    //vec2d pos; //Point that 'creates' the arc
    Site site;
    CircleEvent event; //Potential circle event.

    //    this(vec2d pt) {
    //        pos = pt;
    //    }
    this(Site s) {
        site = s;
    }

}

