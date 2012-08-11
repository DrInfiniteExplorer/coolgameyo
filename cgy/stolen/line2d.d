// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.line2d;

import stolen.vector2d;

//! 2D line between two points with intersection methods.
struct line2d(T)
{
public:
	//! Constructor for line between the two points.
	this(T xa, T ya, T xb, T yb) {start = vector2d!(T)(xa, ya); end = vector2d!(T)(xb, yb);}
	//! Constructor for line between the two points given as vectors.
	this(const vector2d!(T) vstart, const vector2d!(T) vend) { start = vstart; end = vend; }


	// operators

	line2d!(T) opAdd(const vector2d!(T) point) const { return line2d!(T)(start + point, end + point); }
	line2d!(T) opAddAssign(const vector2d!(T) point) { start += point; end += point; return this; }

	line2d!(T) opSub(const vector2d!(T) point) const { return line2d!(T)(start - point, end - point); }
	line2d!(T) opSubAssign(const vector2d!(T) point) { start -= point; end -= point; return this; }

	bool opEquals(const ref line2d!(T) other) const
	{ return (start==other.start && end==other.end) || (end==other.start && start==other.end);}

	// functions
	//! Set this line to new line going through the two points.
	void setLine(const T xa, const T ya, const T xb, const T yb) {start.set(xa, ya); end.set(xb, yb);}
	//! Set this line to new line going through the two points.
	void setLine(const vector2d!(T) nstart, const vector2d!(T) nend){start.set(nstart); end.set(nend);}
	//! Set this line to new line given as parameter.
	void setLine(const line2d!(T) line){start.set(line.start); end.set(line.end);}

	//! Get length of line
	/** \return Length of the line. */
	double getLength() const { return start.getDistanceFrom(end); }

	//! Get squared length of the line
	/** \return Squared length of line. */
	T getLengthSQ() const { return start.getDistanceFromSQ(end); }

	//! Get middle of the line
	/** \return center of the line. */
	vector2d!(T) getMiddle() const
	{
		return (start + end) * cast(T)0.5;
	}

	//! Get the vector of the line.
	/** \return The vector of the line. */
	vector2d!(T) getVector() const { return vector2d!(T)(end.X - start.X, end.Y - start.Y); }

	//! Tests if this line intersects with another line.
	/** \param l: Other line to test intersection with.
	\param out: If there is an intersection, the location of the
	intersection will be stored in this vector.
	\return True if there is an intersection, false if not. */
	bool intersectWith(const line2d!(T) l, ref vector2d!(T) vout) const
	{
		// Uses the method given at:
		// http://local.wasp.uwa.edu.au/~pbourke/geometry/lineline2d/ 
		const float commonDenominator = (l.end.Y - l.start.Y)*(end.X - start.X) -
										(l.end.X - l.start.X)*(end.Y - start.Y);

		const float numeratorA = (l.end.X - l.start.X)*(start.Y - l.start.Y) -
										(l.end.Y - l.start.Y)*(start.X -l.start.X);

		const float numeratorB = (end.X - start.X)*(start.Y - l.start.Y) -
										(end.Y - start.Y)*(start.X -l.start.X); 

		if(stolen.math.equals(commonDenominator, 0.0f))
		{ 
			// The lines are either coincident or parallel
			// if both numerators are 0, the lines are coincident
			if(stolen.math.equals(numeratorA, 0.0f) && stolen.math.equals(numeratorB, 0.0f))
			{
				// Try and find a common endpoint
				if(l.start == start || l.end == start)
					vout = start;
				else if(l.end == end || l.start == end)
					vout = end;
				// now check if the two segments are disjunct
				else if (l.start.X>start.X && l.end.X>start.X && l.start.X>end.X && l.end.X>end.X)
					return false;
				else if (l.start.Y>start.Y && l.end.Y>start.Y && l.start.Y>end.Y && l.end.Y>end.Y)
					return false;
				else if (l.start.X<start.X && l.end.X<start.X && l.start.X<end.X && l.end.X<end.X)
					return false;
				else if (l.start.Y<start.Y && l.end.Y<start.Y && l.start.Y<end.Y && l.end.Y<end.Y)
					return false;
				// else the lines are overlapping to some extent
				else
				{
					// find the points which are not contributing to the
					// common part
					vector2d!(T) maxp;
					vector2d!(T) minp;
					if ((start.X>l.start.X && start.X>l.end.X && start.X>end.X) || (start.Y>l.start.Y && start.Y>l.end.Y && start.Y>end.Y))
						maxp=start;
					else if ((end.X>l.start.X && end.X>l.end.X && end.X>start.X) || (end.Y>l.start.Y && end.Y>l.end.Y && end.Y>start.Y))
						maxp=end;
					else if ((l.start.X>start.X && l.start.X>l.end.X && l.start.X>end.X) || (l.start.Y>start.Y && l.start.Y>l.end.Y && l.start.Y>end.Y))
						maxp=l.start;
					else
						maxp=l.end;
					if (maxp != start && ((start.X<l.start.X && start.X<l.end.X && start.X<end.X) || (start.Y<l.start.Y && start.Y<l.end.Y && start.Y<end.Y)))
						minp=start;
					else if (maxp != end && ((end.X<l.start.X && end.X<l.end.X && end.X<start.X) || (end.Y<l.start.Y && end.Y<l.end.Y && end.Y<start.Y)))
						minp=end;
					else if (maxp != l.start && ((l.start.X<start.X && l.start.X<l.end.X && l.start.X<end.X) || (l.start.Y<start.Y && l.start.Y<l.end.Y && l.start.Y<end.Y)))
						minp=l.start;
					else
						minp=l.end;

					// one line is contained in the other. Pick the center
					// of the remaining points, which overlap for sure
					vout = vector2d!(T)(0,0);
					if (start != maxp && start != minp)
						vout += start;
					if (end != maxp && end != minp)
						vout += end;
					if (l.start != maxp && l.start != minp)
						vout += l.start;
					if (l.end != maxp && l.end != minp)
						vout += l.end;
					vout *= cast(T) 0.5f;
				}

				return true; // coincident
			}

			return false; // parallel
		}

		// Get the point of intersection on this line, checking that
		// it is within the line segment.
		const float uA = numeratorA / commonDenominator;
		if(uA < 0.0f || uA > 1.0f)
			return false; // Outside the line segment

		const float uB = numeratorB / commonDenominator;
		if(uB < 0.0f || uB > 1.0f)
			return false; // Outside the line segment

		// Calculate the intersection point.
		vout.X = cast(T) (start.X + uA * (end.X - start.X));
		vout.Y = cast(T) (start.Y + uA * (end.Y - start.Y));
		return true; 
	}

	//! Get unit vector of the line.
	/** \return Unit vector of this line. */
	vector2d!(T) getUnitVector() const
	{
		T len = cast(T)(1.0 / getLength());
		return vector2d!(T)((end.X - start.X) * len, (end.Y - start.Y) * len);
	}

	//! Get angle between this line and given line.
	/** \param l Other line for test.
	\return Angle in degrees. */
	double getAngleWith(const line2d!(T) l) const
	{
		vector2d!(T) vect = getVector();
		vector2d!(T) vect2 = l.getVector();
		return vect.getAngleWith(vect2);
	}

	//! Tells us if the given point lies to the left, right, or on the line.
	/** \return 0 if the point is on the line
	<0 if to the left, or >0 if to the right. */
	T getPointOrientation(const vector2d!(T) point) const
	{
		return ( (end.X - start.X) * (point.Y - start.Y) -
				(point.X - start.X) * (end.Y - start.Y) );
	}

	//! Check if the given point is a member of the line
	/** \return True if point is between start and end, else false. */
	bool isPointOnLine(const vector2d!(T) point) const
	{
		T d = getPointOrientation(point);
		return (d == 0 && point.isBetweenPoints(start, end));
	}

	//! Check if the given point is between start and end of the line.
	/** Assumes that the point is already somewhere on the line. */
	bool isPointBetweenStartAndEnd(const vector2d!(T) point) const
	{
		return point.isBetweenPoints(start, end);
	}

	//! Get the closest point on this line to a point
	vector2d!(T) getClosestPoint(const vector2d!(T) point)
	{
		vector2d!(T) c = point - start;
		vector2d!(T) v = end - start;
		T d = cast(T)v.getLength();
		v /= d;
		T t = v.dotProduct(c);

		if (t < cast(T)0.0) return start;
		if (t > d) return end;

		v *= t;
		return start + v;
	}

	//! Start point of the line.
	vector2d!(T) start = vector2d!(T)(0,0);
	//! End point of the line.
	vector2d!(T) end = vector2d!(T)(1,1);
};

//! Typedef for an float line.
alias line2d!(float) line2df;
//! Typedef for an integer line.
alias line2d!(int) line2di;
