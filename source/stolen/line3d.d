// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.line3d;

import stolen.math;
import math.vector;

//! 3D line between two points with intersection methods.

struct line3d(T)
{
public:

	//! Constructor with two points
	this(T xa, T ya, T za, T xb, T yb, T zb) {start = vector3!T(xa, ya, za); end = vector3!T(xb, yb, zb);}
	//! Constructor with two points as vectors
	this(const vector3!T vstart, const vector3!T vend) {start = vstart; end = vend;}

	this(ref const line3d!(T) other)
	{
		start = other.start;
		end = other.end;
	}
	
	// operators

	line3d!(T) opAdd(const vector3!T point) const { return line3d!(T)(start + point, end + point); }
	line3d!(T) opAddAssign(const vector3!T point) { start += point; end += point; return this; }

	line3d!(T) opSub(const vector3!T point) const { return line3d!(T)(start - point, end - point); }
	line3d!(T) opSubAssign(const vector3!T point) { start -= point; end -= point; return this; }

	bool opEquals(const ref line3d!(T) other) const
	{ return (start==other.start && end==other.end) || (end==other.start && start==other.end);}

	// functions
	//! Set this line to a new line going through the two points.
	void setLine(const T xa, const T ya, const T za, const T xb, const T yb, const T zb)
	{start.set(xa, ya, za); end.set(xb, yb, zb);}
	//! Set this line to a new line going through the two points.
	void setLine(const vector3!T nstart, const vector3!T nend)
	{start = nstart; end = nend;}
	//! Set this line to new line given as parameter.
	void setLine(const line3d!(T) line)
	{start = line.start; end = line.end;}

	//! Get length of line
	/** \return Length of line. */
	T getLength() const { return start.getDistance(end); }

	//! Get squared length of line
	/** \return Squared length of line. */
	T getLengthSQ() const { return start.getDistanceSQ(end); }

	//! Get middle of line
	/** \return Center of line. */
	vector3!T getMiddle() const
	{
		return (start + end) * cast(T)0.5;
	}

	//! Get vector of line
	/** \return vector of line. */
	vector3!T getVector() const
	{
		return end - start;
	}

	//! Check if the given point is between start and end of the line.
	/** Assumes that the point is already somewhere on the line.
	\param point The point to test.
	\return True if point is on the line between start and end, else false.
	*/
	bool isPointBetweenStartAndEnd(const vector3!T point) const
	{
		return point.isBetweenPoints(start, end);
	}

	//! Get the closest point on this line to a point
	/** \param point The point to compare to.
	\return The nearest point which is part of the line. */
	vector3!T getClosestPoint(const vector3!T point)
	{
		vector3!T c = point - start;
		vector3!T v = end - start;
		T d = cast(T)v.getLength();
		v /= d;
		T t = v.dotProduct(c);

		if (t < cast(T)0.0)
			return start;
		if (t > d)
			return end;

		v *= t;
		return start + v;
	}

    static if(isFloatingPoint!T) {

	    //! Check if the line intersects with a shpere
	    /** \param sorigin: Origin of the shpere.
	    \param sradius: Radius of the sphere.
	    \param outdistance: The distance to the first intersection point.
	    \return True if there is an intersection.
	    If there is one, the distance to the first intersection point
	    is stored in outdistance. */
	    bool getIntersectionWithSphere(vector3!T sorigin, T sradius, ref double outdistance) const
	    {
		    const vector3!T q = sorigin - start;
		    T c = q.getLength();
		    T v = q.dotProduct(getVector().normalizeThis());
		    T d = sradius * sradius - (c*c - v*v);

		    if (d < 0.0)
			    return false;

		    outdistance = v - sqrt (cast(real) d );
		    return true;
	    }
    }

	// member variables

	//! Start point of line
	vector3!T start = vector3!T(0,0,0);
	//! End point of line
	vector3!T end = vector3!T(1,1,1);
};

//! Typedef for an f32 line.
alias line3d!(float) line3df;
//! Typedef for an integer line.
alias line3d!(int) line3di;
