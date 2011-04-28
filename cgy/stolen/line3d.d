// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.line3d;

import stolen.vector3d;
import stolen.math;

//! 3D line between two points with intersection methods.

struct line3d(T)
{
public:

	//! Constructor with two points
	this(T xa, T ya, T za, T xb, T yb, T zb) {start = vector3d!(T)(xa, ya, za); end = vector3d!(T)(xb, yb, zb);}
	//! Constructor with two points as vectors
	this(const vector3d!(T) vstart, const vector3d!(T) vend) {start = vstart; end = vend;}

	this(ref const line3d!(T) other)
	{
		start = vector3d!(T)(other.start);
		end = vector3d!(T)(other.end);
	}
	
	// operators

	line3d!(T) opAdd(const vector3d!(T) point) const { return line3d!(T)(start + point, end + point); }
	line3d!(T) opAddAssign(const vector3d!(T) point) { start += point; end += point; return this; }

	line3d!(T) opSub(const vector3d!(T) point) const { return line3d!(T)(start - point, end - point); }
	line3d!(T) opSubAssign(const vector3d!(T) point) { start -= point; end -= point; return this; }

	bool opEquals(const ref line3d!(T) other) const
	{ return (start==other.start && end==other.end) || (end==other.start && start==other.end);}

	// functions
	//! Set this line to a new line going through the two points.
	void setLine(const T xa, const T ya, const T za, const T xb, const T yb, const T zb)
	{start.set(xa, ya, za); end.set(xb, yb, zb);}
	//! Set this line to a new line going through the two points.
	void setLine(const vector3d!(T) nstart, const vector3d!(T) nend)
	{start.set(nstart); end.set(nend);}
	//! Set this line to new line given as parameter.
	void setLine(const line3d!(T) line)
	{start.set(line.start); end.set(line.end);}

	//! Get length of line
	/** \return Length of line. */
	T getLength() const { return start.getDistanceFrom(end); }

	//! Get squared length of line
	/** \return Squared length of line. */
	T getLengthSQ() const { return start.getDistanceFromSQ(end); }

	//! Get middle of line
	/** \return Center of line. */
	vector3d!(T) getMiddle() const
	{
		return (start + end) * cast(T)0.5;
	}

	//! Get vector of line
	/** \return vector of line. */
	vector3d!(T) getVector() const
	{
		return end - start;
	}

	//! Check if the given point is between start and end of the line.
	/** Assumes that the point is already somewhere on the line.
	\param point The point to test.
	\return True if point is on the line between start and end, else false.
	*/
	bool isPointBetweenStartAndEnd(const vector3d!(T) point) const
	{
		return point.isBetweenPoints(start, end);
	}

	//! Get the closest point on this line to a point
	/** \param point The point to compare to.
	\return The nearest point which is part of the line. */
	vector3d!(T) getClosestPoint(const vector3d!(T) point)
	{
		vector3d!(T) c = point - start;
		vector3d!(T) v = end - start;
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

	//! Check if the line intersects with a shpere
	/** \param sorigin: Origin of the shpere.
	\param sradius: Radius of the sphere.
	\param outdistance: The distance to the first intersection point.
	\return True if there is an intersection.
	If there is one, the distance to the first intersection point
	is stored in outdistance. */
	bool getIntersectionWithSphere(vector3d!(T) sorigin, T sradius, ref double outdistance) const
	{
		const vector3d!(T) q = sorigin - start;
		T c = q.getLength();
		T v = q.dotProduct(getVector().normalize());
		T d = sradius * sradius - (c*c - v*v);

		if (d < 0.0)
			return false;

		outdistance = v - sqrt ( d );
		return true;
	}

	// member variables

	//! Start point of line
	vector3d!(T) start = vector3d!(T)(0,0,0);
	//! End point of line
	vector3d!(T) end = vector3d!(T)(1,1,1);
};

//! Typedef for an f32 line.
alias line3d!(float) line3df;
//! Typedef for an integer line.
alias line3d!(int) line3di;