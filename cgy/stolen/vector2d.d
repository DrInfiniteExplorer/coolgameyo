// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.vector2d;

import stolen.math;
import stolen.vector3d;



struct vector2d(T)
{
public:
	//! Constructor with two different values
	this(T nx, T ny) {X = nx; Y = ny;}
	//! Constructor with the same value for both members
	this(T n) {X = n; Y = n;}
	//! Copy constructor
	this(const vector2d!(T) other) {X = other.X; Y = other.Y;}

    vector3d!T vec3(T z = 0) const {
        return vector3d!T(X, Y, z);
    }

    vector2d!TTT convert(TTT)() const {
        return vector2d!TTT(cast(TTT)(X), cast(TTT)(Y));
    }

	// operators

	vector2d!(T) opNeg() const { return vector2d!(T)(-X, -Y); }

	vector2d!(T) opAssign(const vector2d!(T) other) { X = other.X; Y = other.Y; return this; }


	vector2d!(T) opAdd(const vector2d!(T) other) const { return vector2d!(T)(cast(T) (X + other.X) ,cast(T) (Y + other.Y)); }
	vector2d!(T) opAddAssign(const vector2d!(T) other) { X+=other.X; Y+=other.Y; return this; }
	vector2d!(T) opAdd(const T v) const { return vector2d!(T)(cast(T) (X + v), cast(T) (Y + v)); }
	vector2d!(T) opAddAssign(const T v) { X+=v; Y+=v; return this; }

	vector2d!(T) opSub(const vector2d!(T) other) const { return vector2d!(T)(cast(T) (X - other.X), cast(T) (Y - other.Y)); }
	vector2d!(T) opSubAssign(const vector2d!(T) other) { X-=other.X; Y-=other.Y; return this; }
	vector2d!(T) opSub(const T v) const { return vector2d!(T)(cast(T) (X - v), cast(T) (Y - v)); }
	vector2d!(T) opSubAssign(const T v) { X-=v; Y-=v; return this; }

	vector2d!(T) opMul(const vector2d!(T) other) const { return vector2d!(T)(cast(T) (X * other.X), cast(T) (Y * other.Y)); }
	vector2d!(T) opMulAssign(const vector2d!(T) other) { X*=other.X; Y*=other.Y; return this; }
	vector2d!(T) opMul(const T v) const { return vector2d!(T)(cast(T) (X * v), cast(T) (Y * v)); }
	vector2d!(T) opMulAssign(const T v) { X*=v; Y*=v; return this; }

	vector2d!(T) opDiv(const vector2d!(T) other) const { return vector2d!(T)(cast(T) (X / other.X), cast(T) (Y / other.Y)); }
	vector2d!(T) opDivAssign(const vector2d!(T) other) { X/=other.X; Y/=other.Y; return this; }
	vector2d!(T) opDiv(const T v) const { return vector2d!(T)(cast(T) (X / v), cast(T) (Y / v)); }
	vector2d!(T) opDivAssign(const T v) { X/=v; Y/=v; return this; }

    vector2d!T min(const vector2d!T other) const {
        T min(T a, T b) {
            return a < b ? a : b;
        }
        return vector2d!T(
                          min(X, other.X), 
                          min(Y, other.Y)
                          );
    }

    vector2d!T max(const vector2d!T other) const {
        T max(T a, T b) {
            return a > b ? a : b;
        }
        return vector2d!T(
                          max(X, other.X), 
                          max(Y, other.Y)
                          );
    }

	//! sort in order X, Y. Equality with rounding tolerance.
	T opCmp(const vector2d!(T)other) const
	{
        auto dX = X - other.X;
        auto dY = Y - other.Y;
        
        if(dX*dY == 0){
            return 0;
        }
        if(dX < 0){
            return 1;
        }
        if(dX == 0 && dY < 0){
            return 1;
        }
        
		return -1;
	}

	bool opEquals(const ref vector2d!(T) other) const { return equals(other); }

	// functions

	//! Checks if this vector equals the other one.
	/** Takes floating point rounding errors into account.
	\param other Vector to compare with.
	\return True if the two vector are (almost) equal, else false. */
	bool equals(const vector2d!(T) other) const
	{
		return stolen.math.equals(X, other.X) && stolen.math.equals(Y, other.Y);
	}

	vector2d!(T) set(T nx, T ny) {X=nx; Y=ny; return this; }
	vector2d!(T) set(const vector2d!(T) p) { X=p.X; Y=p.Y; return this; }

	//! Gets the length of the vector.
	/** \return The length of the vector. */
	T getLength() const { return cast(T) sqrt(cast(real) X*X + Y*Y ); }

	//! Get the squared length of this vector
	/** This is useful because it is much faster than getLength().
	\return The squared length of the vector. */
	T getLengthSQ() const { return cast(T) (X*X + Y*Y); }

	//! Get the dot product of this vector with another.
	/** \param other Other vector to take dot product with.
	\return The dot product of the two vectors. */
	T dotProduct(const vector2d!(T) other) const
	{
		return cast(T) (X*other.X + Y*other.Y);
	}

	//! Gets distance from another point.
	/** Here, the vector is interpreted as a point in 2-dimensional space.
	\param other Other vector to measure from.
	\return Distance from other point. */
	T getDistanceFrom(const vector2d!(T) other) const
	{
		return (vector2d!(T)(cast(T) (X - other.X), cast(T) (Y - other.Y))).getLength();
	}

	//! Returns squared distance from another point.
	/** Here, the vector is interpreted as a point in 2-dimensional space.
	\param other Other vector to measure from.
	\return Squared distance from other point. */
	T getDistanceFromSQ(const vector2d!(T) other) const
	{
		return (vector2d!(T)(cast(T) (X - other.X), cast(T) (Y - other.Y))).getLengthSQ();
	}

	//! rotates the point anticlockwise around a center by an amount of degrees.
	/** \param degrees Amount of degrees to rotate by, anticlockwise.
	\param center Rotation center.
	\return This vector after transformation. */
	vector2d!(T) rotateBy(double degrees, vector2d!(T)* center=null)
	{
		if (center is null)
			center = &vector2d!(T)();
		
		degrees *= DEGTORAD64;
		const double cs = cos(degrees);
		const double sn = sin(degrees);

		X -= center.X;
		Y -= center.Y;

		set(cast(T)(X*cs - Y*sn), cast(T)(X*sn + Y*cs));

		X += center.X;
		Y += center.Y;
		return this;
	}

	//! Normalize the vector.
	/** The null vector is left untouched.
	\return Reference to this vector, after normalization. */
	vector2d!(T) normalize()
	{
		float length = cast(float)(X*X + Y*Y);
		if (stolen.math.equals(length, 0.f))
			return this;
		length = 1.0f / sqrt ( length );
		X = cast(T)(X * length);
		Y = cast(T)(Y * length);
		return this;
	}

	//! Calculates the angle of this vector in degrees in the trigonometric sense.
	/** 0 is to the right (3 o'clock), values increase counter-clockwise.
	This method has been suggested by Pr3t3nd3r.
	\return Returns a value between 0 and 360. */
	double getAngleTrig() const
	{
		if (Y == 0)
			return X < 0 ? 180 : 0;
		else
		if (X == 0)
			return Y < 0 ? 270 : 90;

		if ( Y > 0)
			if (X > 0)
				return atan(cast(double)Y/cast(double)X) * RADTODEG64;
			else
				return 180.0-atan(cast(double)Y/-cast(double)X) * RADTODEG64;
		else
			if (X > 0)
				return 360.0-atan(-cast(double)Y/cast(double)X) * RADTODEG64;
			else
				return 180.0+atan(-cast(double)Y/-cast(double)X) * RADTODEG64;
	}

	//! Calculates the angle of this vector in degrees in the counter trigonometric sense.
	/** 0 is to the right (3 o'clock), values increase clockwise.
	\return Returns a value between 0 and 360. */
	double getAngle() const
	{
		if (Y == 0) // corrected thanks to a suggestion by Jox
			return X < 0 ? 180 : 0;
		else if (X == 0)
			return Y < 0 ? 90 : 270;

		// don't use getLength here to avoid precision loss with s32 vectors
		double tmp = Y / sqrt(cast(double)(X*X + Y*Y));
		tmp = atan( sqrt(1 - tmp*tmp) / tmp) * RADTODEG64;

		if (X>0 && Y>0)
			return tmp + 270;
		else
		if (X>0 && Y<0)
			return tmp + 90;
		else
		if (X<0 && Y<0)
			return 90 - tmp;
		else
		if (X<0 && Y>0)
			return 270 - tmp;

		return tmp;
	}

	//! Calculates the angle between this vector and another one in degree.
	/** \param b Other vector to test with.
	\return Returns a value between 0 and 90. */
	double getAngleWith(const vector2d!(T) b) const
	{
		double tmp = X*b.X + Y*b.Y;

		if (tmp == 0.0)
			return 90.0;

		tmp = tmp / sqrt(cast(double)((X*X + Y*Y) * (b.X*b.X + b.Y*b.Y)));
		if (tmp < 0.0)
			tmp = -tmp;

		return atan(sqrt(1 - tmp*tmp) / tmp) * RADTODEG64;
	}

	//! Returns if this vector interpreted as a point is on a line between two other points.
	/** It is assumed that the point is on the line.
	\param begin Beginning vector to compare between.
	\param end Ending vector to compare between.
	\return True if this vector is between begin and end, false if not. */
	bool isBetweenPoints(const vector2d!(T) begin, const vector2d!(T) end) const
	{
		if (begin.X != end.X)
		{
			return ((begin.X <= X && X <= end.X) ||
				(begin.X >= X && X >= end.X));
		}
		else
		{
			return ((begin.Y <= Y && Y <= end.Y) ||
				(begin.Y >= Y && Y >= end.Y));
		}
	}

	//! Creates an interpolated vector between this vector and another vector.
	/** \param other The other vector to interpolate with.
	\param d Interpolation value between 0.0f (all the other vector) and 1.0f (all this vector).
	Note that this is the opposite direction of interpolation to getInterpolated_quadratic()
	\return An interpolated vector.  This vector is not modified. */
	vector2d!(T) getInterpolated(const vector2d!(T) other, double d) const
	{
		double inv = 1.0f - d;
		return vector2d!(T)(cast(T)(other.X*inv + X*d), cast(T)(other.Y*inv + Y*d));
	}

	//! Creates a quadratically interpolated vector between this and two other vectors.
	/** \param v2 Second vector to interpolate with.
	\param v3 Third vector to interpolate with (maximum at 1.0f)
	\param d Interpolation value between 0.0f (all this vector) and 1.0f (all the 3rd vector).
	Note that this is the opposite direction of interpolation to getInterpolated() and interpolate()
	\return An interpolated vector. This vector is not modified. */
	vector2d!(T) getInterpolated_quadratic(const vector2d!(T) v2, const vector2d!(T) v3, double d) const
	{
		// this*(1-d)*(1-d) + 2 * v2 * (1-d) + v3 * d * d;
		const double inv = 1.0f - d;
		const double mul0 = inv * inv;
		const double mul1 = 2.0f * d * inv;
		const double mul2 = d * d;

		return vector2d!(T) ( cast(T)(X * mul0 + v2.X * mul1 + v3.X * mul2),
					cast(T)(Y * mul0 + v2.Y * mul1 + v3.Y * mul2));
	}

	//! Sets this vector to the linearly interpolated vector between a and b.
	/** \param a first vector to interpolate with, maximum at 1.0f
	\param b second vector to interpolate with, maximum at 0.0f
	\param d Interpolation value between 0.0f (all vector b) and 1.0f (all vector a)
	Note that this is the opposite direction of interpolation to getInterpolated_quadratic()
	*/
	vector2d!(T) interpolate(const vector2d!(T) a, const vector2d!(T) b, double d)
	{
		X = cast(T)(cast(double)b.X + ( ( a.X - b.X ) * d ));
		Y = cast(T)(cast(double)b.Y + ( ( a.Y - b.Y ) * d ));
		return this;
	}

	//! X coordinate of vector.
	T X = 0;

	//! Y coordinate of vector.
	T Y = 0;
};

//! Typedef for float 2d vector.
alias vector2d!(float) vector2df;

//! Typedef for integer 2d vector.
alias vector2d!(int) vector2di;


//template<class S, class T>
//vector2d!(T) operator*(const S scalar, const vector2d!(T) vector) { return vector*scalar; }

