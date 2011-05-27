// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.quaternion;

import stolen.vector3d;
import stolen.matrix4;
import stolen.math;

//! Quaternion class for representing rotations.
/** It provides cheap combinations and avoids gimbal locks.
Also useful for interpolations. */
struct quaternion
{
public:

	//! Constructor
	this(float x, float y, float z, float w) {  X = x; Y = y; Z = z; W = w; }

	//! Constructor which converts euler angles (radians) to a quaternion
	this(float x, float y, float z) { set(x,y,z); }

	//! Constructor which converts euler angles (radians) to a quaternion
	this(const vector3df vec) { set(vec.X,vec.Y,vec.Z); }

	//! Constructor which converts a matrix to a quaternion
	this(const matrix4 mat) { this = mat; }

	//! Equalilty operator
	bool opEquals(const ref quaternion other) const
	{
		return ((X == other.X) &&
			(Y == other.Y) &&
			(Z == other.Z) &&
			(W == other.W));	
	}

	//! Assignment operator
	quaternion opAssign(const quaternion other)
	{
		X = other.X;
		Y = other.Y;
		Z = other.Z;
		W = other.W;
		return this;	
	}

	//! Matrix assignment operator
	quaternion opAssign(const matrix4 m)
	{
		const float diag = m.at(0,0) + m.at(1,1) + m.at(2,2) + 1;

		if( diag > 0.0f )
		{
			const float scale = sqrt(diag) * 2.0f; // get scale from diagonal

			// TO_DO: speed this up
			X = ( m.at(2,1) - m.at(1,2)) / scale;
			Y = ( m.at(0,2) - m.at(2,0)) / scale;
			Z = ( m.at(1,0) - m.at(0,1)) / scale;
			W = 0.25f * scale;
		}
		else
		{
			if ( m.at(0,0) > m.at(1,1) && m.at(0,0) > m.at(2,2))
			{
				// 1st element of diag is greatest value
				// find scale according to 1st element, and double it
				const float scale = sqrt( 1.0f + m.at(0,0) - m.at(1,1) - m.at(2,2)) * 2.0f;

				// TO_DO: speed this up
				X = 0.25f * scale;
				Y = (m.at(0,1) + m.at(1,0)) / scale;
				Z = (m.at(2,0) + m.at(0,2)) / scale;
				W = (m.at(2,1) - m.at(1,2)) / scale;
			}
			else if ( m.at(1,1) > m.at(2,2))
			{
				// 2nd element of diag is greatest value
				// find scale according to 2nd element, and double it
				const float scale = sqrt( 1.0f + m.at(1,1) - m.at(0,0) - m.at(2,2)) * 2.0f;

				// TO_DO: speed this up
				X = (m.at(0,1) + m.at(1,0) ) / scale;
				Y = 0.25f * scale;
				Z = (m.at(1,2) + m.at(2,1) ) / scale;
				W = (m.at(0,2) - m.at(2,0) ) / scale;
			}
			else
			{
				// 3rd element of diag is greatest value
				// find scale according to 3rd element, and double it
				const float scale = sqrt( 1.0f + m.at(2,2) - m.at(0,0) - m.at(1,1)) * 2.0f;

				// TO_DO: speed this up
				X = (m.at(0,2) + m.at(2,0)) / scale;
				Y = (m.at(1,2) + m.at(2,1)) / scale;
				Z = 0.25f * scale;
				W = (m.at(1,0) - m.at(0,1)) / scale;
			}
		}

		return normalize();	
	}

	//! Add operator
	quaternion opAdd(const quaternion b) const
	{
		return quaternion(X+b.X, Y+b.Y, Z+b.Z, W+b.W);	
	}

	//! Multiplication operator
	quaternion opMul(const quaternion other) const
	{
		quaternion tmp;

		tmp.W = (other.W * W) - (other.X * X) - (other.Y * Y) - (other.Z * Z);
		tmp.X = (other.W * X) + (other.X * W) + (other.Y * Z) - (other.Z * Y);
		tmp.Y = (other.W * Y) + (other.Y * W) + (other.Z * X) - (other.X * Z);
		tmp.Z = (other.W * Z) + (other.Z * W) + (other.X * Y) - (other.Y * X);

		return tmp;	
	}

	//! Multiplication operator with scalar
	quaternion opMul(float s) const
	{
		return quaternion(s*X, s*Y, s*Z, s*W);	
	}

	//! Multiplication operator with scalar
	quaternion opMulAssign(float s)
	{
		X*=s;
		Y*=s;
		Z*=s;
		W*=s;
		return this;	
	}

	//! Multiplication operator
	vector3df opMul(const vector3df v) const
	{
		// nVidia SDK implementation

		vector3df uv, uuv;
		vector3df qvec = vector3df(X, Y, Z);
		uv = qvec.crossProduct(v);
		uuv = qvec.crossProduct(uv);
		uv *= (2.0f * W);
		uuv *= 2.0f;

		return v + uv + uuv;	
	}

	//! Multiplication operator
	quaternion opMulAssign(const quaternion other)
	{
		return (this = other * this);	
	}

	//! Calculates the dot product
	float dotProduct(const quaternion q2) const
	{
		return (X * q2.X) + (Y * q2.Y) + (Z * q2.Z) + (W * q2.W);	
	}

	//! Sets quaternion
	quaternion set(float x, float y, float z, float w)
	{
		X = x;
		Y = y;
		Z = z;
		W = w;
		return this;	
	}

	//! Sets quaternion based on euler angles (radians)
	quaternion set(float x, float y, float z)
	{
		double angle;

		angle = x * 0.5;
		const double sr = sin(angle);
		const double cr = cos(angle);

		angle = y * 0.5;
		const double sp = sin(angle);
		const double cp = cos(angle);

		angle = z * 0.5;
		const double sy = sin(angle);
		const double cy = cos(angle);

		const double cpcy = cp * cy;
		const double spcy = sp * cy;
		const double cpsy = cp * sy;
		const double spsy = sp * sy;

		X = cast(float)(sr * cpcy - cr * spsy);
		Y = cast(float)(cr * spcy + sr * cpsy);
		Z = cast(float)(cr * cpsy - sr * spcy);
		W = cast(float)(cr * cpcy + sr * spsy);

		return normalize();	
	}

	//! Sets quaternion based on euler angles (radians)
	quaternion set(const vector3df vec)
	{
		return set(vec.X, vec.Y, vec.Z);	
	}

	//! Sets quaternion from other quaternion
	quaternion set(const quaternion quat)
	{
		return (this=quat);	
	}

	//! returns if this quaternion equals the other one, taking floating point rounding errors into account
	bool equals(const quaternion other,
			const float tolerance = ROUNDING_ERROR_f32 ) const
	{
		return stolen.math.equals(X, other.X, tolerance) &&
			stolen.math.equals(Y, other.Y, tolerance) &&
			stolen.math.equals(Z, other.Z, tolerance) &&
			stolen.math.equals(W, other.W, tolerance);			
	}

	//! Normalizes the quaternion
	quaternion normalize()
	{
		const float n = X*X + Y*Y + Z*Z + W*W;

		if (n == 1)
			return this;

		//n = 1.0f / sqrtf(n);
		return (this *= (1.0 / sqrt ( n )));	
	}

	//! Creates a matrix from this quaternion
	matrix4 getMatrix() const
	{
		matrix4 m;
		getMatrix_transposed(m);
		return m;	
	}

	//! Creates a matrix from this quaternion
	void getMatrix(ref matrix4 dest, const vector3df center ) const
	{
		float * m = dest.pointer();

		m[0] = 1.0f - 2.0f*Y*Y - 2.0f*Z*Z;
		m[1] = 2.0f*X*Y + 2.0f*Z*W;
		m[2] = 2.0f*X*Z - 2.0f*Y*W;
		m[3] = 0.0f;

		m[4] = 2.0f*X*Y - 2.0f*Z*W;
		m[5] = 1.0f - 2.0f*X*X - 2.0f*Z*Z;
		m[6] = 2.0f*Z*Y + 2.0f*X*W;
		m[7] = 0.0f;

		m[8] = 2.0f*X*Z + 2.0f*Y*W;
		m[9] = 2.0f*Z*Y - 2.0f*X*W;
		m[10] = 1.0f - 2.0f*X*X - 2.0f*Y*Y;
		m[11] = 0.0f;

		m[12] = center.X;
		m[13] = center.Y;
		m[14] = center.Z;
		m[15] = 1.f;

		//dest.setDefinitelyIdentityMatrix ( matrix4::BIT_IS_NOT_IDENTITY );
		dest.setDefinitelyIdentityMatrix ( false );	
	}

	/*!
		Creates a matrix from this quaternion
		Rotate about a center point
		shortcut for
		core::quaternion q;
		q.rotationFromTo ( vin[i].Normal, forward );
		q.getMatrixCenter ( lookat, center, newPos );

		core::matrix4 m2;
		m2.setInverseTranslation ( center );
		lookat *= m2;

		core::matrix4 m3;
		m2.setTranslation ( newPos );
		lookat *= m3;

	*/
	void getMatrixCenter(ref matrix4 dest, const vector3df center, const vector3df translation ) const
	{
		float * m = dest.pointer();

		m[0] = 1.0f - 2.0f*Y*Y - 2.0f*Z*Z;
		m[1] = 2.0f*X*Y + 2.0f*Z*W;
		m[2] = 2.0f*X*Z - 2.0f*Y*W;
		m[3] = 0.0f;

		m[4] = 2.0f*X*Y - 2.0f*Z*W;
		m[5] = 1.0f - 2.0f*X*X - 2.0f*Z*Z;
		m[6] = 2.0f*Z*Y + 2.0f*X*W;
		m[7] = 0.0f;

		m[8] = 2.0f*X*Z + 2.0f*Y*W;
		m[9] = 2.0f*Z*Y - 2.0f*X*W;
		m[10] = 1.0f - 2.0f*X*X - 2.0f*Y*Y;
		m[11] = 0.0f;

		dest.setRotationCenter ( center, translation );	
	}

	//! Creates a matrix from this quaternion
	void getMatrix_transposed(ref matrix4 dest ) const
	{
		dest[0] = 1.0f - 2.0f*Y*Y - 2.0f*Z*Z;
		dest[4] = 2.0f*X*Y + 2.0f*Z*W;
		dest[8] = 2.0f*X*Z - 2.0f*Y*W;
		dest[12] = 0.0f;

		dest[1] = 2.0f*X*Y - 2.0f*Z*W;
		dest[5] = 1.0f - 2.0f*X*X - 2.0f*Z*Z;
		dest[9] = 2.0f*Z*Y + 2.0f*X*W;
		dest[13] = 0.0f;

		dest[2] = 2.0f*X*Z + 2.0f*Y*W;
		dest[6] = 2.0f*Z*Y - 2.0f*X*W;
		dest[10] = 1.0f - 2.0f*X*X - 2.0f*Y*Y;
		dest[14] = 0.0f;

		dest[3] = 0.f;
		dest[7] = 0.f;
		dest[11] = 0.f;
		dest[15] = 1.f;
		//dest.setDefinitelyIdentityMatrix ( matrix4::BIT_IS_NOT_IDENTITY );
		dest.setDefinitelyIdentityMatrix ( false );	
	}

	//! Inverts this quaternion
	quaternion makeInverse()
	{
		X = -X; Y = -Y; Z = -Z;
		return this;	
	}

	//! Set this quaternion to the result of the interpolation between two quaternions
	quaternion slerp( quaternion q1, quaternion q2, float time )
	{
		float angle = q1.dotProduct(q2);

		if (angle < 0.0f)
		{
			q1 *= -1.0f;
			angle *= -1.0f;
		}

		float scale;
		float invscale;

		if ((angle + 1.0f) > 0.05f)
		{
			if ((1.0f - angle) >= 0.05f) // spherical interpolation
			{
				const float theta = acos(angle);
				const float invsintheta = 1.0 / sin(theta);
				scale = sin(theta * (1.0f-time)) * invsintheta;
				invscale = sin(theta * time) * invsintheta;
			}
			else // linear interploation
			{
				scale = 1.0f - time;
				invscale = time;
			}
		}
		else
		{
			q2.set(-q1.Y, q1.X, -q1.W, q1.Z);
			scale = sin(PI * (0.5f - time));
			invscale = sin(PI * time);
		}

		return (this = (q1*scale) + (q2*invscale));	
	}

	//! Create quaternion from rotation angle and rotation axis.
	/** Axis must be unit length.
	The quaternion representing the rotation is
	q = cos(A/2)+sin(A/2)*(x*i+y*j+z*k).
	\param angle Rotation Angle in radians.
	\param axis Rotation axis. */
	quaternion fromAngleAxis (float angle, const vector3df axis)
	{
		const float fHalfAngle = 0.5f*angle;
		const float fSin = sin(fHalfAngle);
		W = cos(fHalfAngle);
		X = fSin*axis.X;
		Y = fSin*axis.Y;
		Z = fSin*axis.Z;
		return this;	
	}

	//! Fills an angle (radians) around an axis (unit vector)
	void toAngleAxis (ref float angle, ref vector3df axis) const
	{
		const float scale = sqrt(X*X + Y*Y + Z*Z);

		if (iszero(scale) || W > 1.0f || W < -1.0f)
		{
			angle = 0.0f;
			axis.X = 0.0f;
			axis.Y = 1.0f;
			axis.Z = 0.0f;
		}
		else
		{
			const float invscale = reciprocal(scale);
			angle = 2.0f * acos(W);
			axis.X = X * invscale;
			axis.Y = Y * invscale;
			axis.Z = Z * invscale;
		}	
	}

	//! Output this quaternion to an euler angle (radians)
	void toEuler(ref vector3df euler) const
	{
		const double sqw = W*W;
		const double sqx = X*X;
		const double sqy = Y*Y;
		const double sqz = Z*Z;

		// heading = rotation about z-axis
		euler.Z = cast (float) (atan2(2.0 * (X*Y +Z*W),(sqx - sqy - sqz + sqw)));

		// bank = rotation about x-axis
		euler.X = cast (float) (atan2(2.0 * (Y*Z +X*W),(-sqx - sqy + sqz + sqw)));

		// attitude = rotation about y-axis
		euler.Y = asin( clamp(-2.0f * (X*Z - Y*W), -1.0f, 1.0f) );	
	}

	//! Set quaternion to identity
	quaternion makeIdentity()
	{
		W = 1.f;
		X = 0.f;
		Y = 0.f;
		Z = 0.f;
		return this;	
	}

	//! Set quaternion to represent a rotation from one vector to another.
	quaternion rotationFromTo(const vector3df from, const vector3df to)
	{
		// Based on Stan Melax's article in Game Programming Gems
		// Copy, since cannot modify local
		vector3df v0 = vector3df(from);
		vector3df v1 = vector3df(to);
		v0.normalize();
		v1.normalize();

		const float d = v0.dotProduct(v1);
		if (d >= 1.0f) // If dot == 1, vectors are the same
		{
			return makeIdentity();
		}
		else if (d <= -1.0f) // exactly opposite
		{
			vector3df axis = vector3df(1.0f, 0.f, 0.f);
			axis = axis.crossProduct(vector3df(X,Y,Z));
			if (axis.getLength()==0)
			{
				axis.set(0.f,1.f,0.f);
				axis.crossProduct(vector3df(X,Y,Z));
			}
			return this.fromAngleAxis(PI, axis);
		}

		const float s = sqrt( (1+d)*2 ); // optimize inv_sqrt
		const float invs = 1.f / s;
		const vector3df c = v0.crossProduct(v1)*invs;
		X = c.X;
		Y = c.Y;
		Z = c.Z;
		W = s * 0.5f;

		return this;	
	}

	//! Quaternion elements.
	float X = 0; // vectorial (imaginary) part
	float Y = 0;
	float Z = 0;
	float W = 0; // real part
};
