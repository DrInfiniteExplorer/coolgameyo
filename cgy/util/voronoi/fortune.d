module util.voronoi.fortune;

import std.algorithm;
import std.array;
import std.math;
import std.range;
import std.stdio;

import statistics;
import util.math;
import util.util;
import util.voronoi.voronoi;

alias std.math.abs abs;

//Substantial speedup when true; goes from 120 seconds to around 90 seconds.
immutable ReuseEvents = true;

final class FortuneVoronoi {

    this() {
        queue = new PQ;
    }

    TreePart tree;
    PQ queue;
    CircleEvent[TreeLeaf] currentCircles;

    Edge[] edges;
    Vertex[] vertices;
    Site[] sites;

    static if(ReuseEvents) {
        CircleEvent[] circleReuse;
        SiteEvent[] siteReuse;

        CircleEvent newCircle(TreeLeaf _left, TreeLeaf _leaf, TreeLeaf _right) {
            if(circleReuse.length == 0) {
                return new CircleEvent(_left, _leaf, _right);
            }
            auto ret = circleReuse[$-1];
            circleReuse.length = circleReuse.length - 1;
            assumeSafeAppend(circleReuse);
            ret.init(_left, _leaf, _right);
            return ret;
        }
        void releaseCircleEvent(CircleEvent e) {
            circleReuse ~= e;
        }

        SiteEvent newSite(Site site) {
            if(siteReuse.length == 0) {
                return new SiteEvent(site);
            }
            auto ret = siteReuse[$-1];
            siteReuse.length = siteReuse.length - 1;
            assumeSafeAppend(siteReuse);
            ret.init(site);
            return ret;
        }
        void releaseSiteEvent(SiteEvent e) {
            siteReuse ~= e;
        }

        void releaseEvent(Event e) {
            if(cast(CircleEvent)e !is null) {
                releaseCircleEvent(cast(CircleEvent)e);
            } else {
                releaseSiteEvent(cast(SiteEvent)e);
            }
        }
    } else {
        auto newCircle(T...)(T t){ return new CircleEvent(t); }
        auto newSite(T...)(T t){ return new SiteEvent(t); }
        void releaseEvent(Event e) const {}
    }

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
        auto event = newCircle(left, leaf, right);
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
                currentCircles[leaf]._valid = false;
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
        
        /*
        //Did we just destroyed a circle?
        if(cast(SiteEvent)e !is null) {
            foreach(circle ; currentCircles) {
                if(circle.center.getDistanceFromSQ(e.pos) < (circle.radius*circle.radius) - 1E10) {
                    //writeln("FALSE CIRCLE FOUND with stuff in it!");
                    circle._valid = false;
                }
            }
        }
        */
    }

    VoronoiPoly makeVoronoi(vec2d[] points) {
        mixin(MeasureTime!"Time to make voronoi:");
        scope(exit) writeln("cnt ", cnt);

        //points = [ vec2d(100, 100), vec2d(75, 150), vec2d(120, 155), vec2d(60, 160), vec2d(140, 190) ];
        //points = [ vec2d(100, 80), vec2d(230, 100), vec2d(100, 210)];

        CircleEvent[SiteEvent] currentCircles;

        //Turn points into sites and add to queueueue.
        sites.length = points.length;
        Event[] startEvents;
        startEvents.length = sites.length;
        foreach(idx, pt ; points) {
            auto site = new Site(pt, idx);
            sites[idx] = site;
            startEvents[idx] = cast(Event)newSite(site);
        }

        queue.add(startEvents);

        while(!queue.empty) {
            auto event = queue.get();
            handleEvent(event);
            releaseEvent(event);
        }

        auto poly = new VoronoiPoly;
        poly.edges = edges; edges = null;
        poly.vertices = vertices; vertices = null;
        poly.sites = sites; sites = null;


        int[HalfEdge] heMap;
        foreach(site ; poly.sites) {
            foreach(he ; site.halfEdges) {
                heMap[he] = 0;
            }
        }
        poly.halfEdges.length = heMap.length;
        int c = 0;
        foreach(he, zero ; heMap) {
            poly.halfEdges[c] = he;
            c++;
        }

        return poly;
    }

};

int cnt = -1;

final class PQ {
    Event[] events;

    void add(Event e) {
        events ~= e;
        //events.sort;
        completeSort!("a < b", SwapStrategy.unstable, Event[], Event[])(assumeSorted(events[0 .. $-1]), events[$-1 .. $]);
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
        cnt++;
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
        init(_site);
    }
    void init(Site _site) {
        site = _site;
        pos = site.pos;
    }
}
final class CircleEvent : Event {
    TreeLeaf left, leaf, right;
    bool _valid;
    vec2d center;
    double radius;
    this(TreeLeaf _left, TreeLeaf _leaf, TreeLeaf _right) {
        init(_left, _leaf, _right);
    }

    void init(TreeLeaf _left, TreeLeaf _leaf, TreeLeaf _right) {
        left = _left;
        leaf = _leaf;
        right = _right;
        center = CircumCircle(left.site.pos, leaf.site.pos, right.site.pos);
        radius = center.getDistanceFrom(left.site.pos);
        _valid = true;
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
final class TreeLeaf : TreePart {

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
