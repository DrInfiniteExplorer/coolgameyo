// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.vector3d;

import std.conv;
import std.exception;
import std.traits;

import stolen.math;

//! 3d vector template class with lots of operators and methods.
/** The vector3d class is used in Irrlicht for three main purposes:
  1) As a direction vector (most of the methods assume this).
  2) As a position in 3d space (which is synonymous with a direction vector from the origin to this position).
  3) To hold three Euler rotations, where X is pitch, Y is yaw and Z is roll.
*/

struct vector3d(T)
{
public:
  //! Constructor with three different values
  this(T nx, T ny, T nz) { X = nx; Y = ny; Z = nz;}

  //! Constructor with the same value for all elements
  this(T n) {X = n; Y = n; Z = n;}

  //! Copy constructor
  this(const vector3d!(T) other) {X = other.X; Y = other.Y; Z = other.Z;}

  // operators
  
  ref T opIndex(uint index)
  in{
      assert(0 <= index, "Bad index for indexing vectors! " ~ to!string(index));
      assert(index <= 2, "Bad index for indexing vectors! " ~ to!string(index));
  }
  body{
      switch(index) {
          case 0: return X;
          case 1: return Y;
          case 2: return Z;
          default: enforce(0, "Bad index"); assert(0);
      }
  }


  vector3d!(T) opNeg() const { return vector3d!(T)(-X, -Y, -Z); }

  vector3d!(T) opAssign(const vector3d!(T) other) { X = other.X; Y = other.Y; Z = other.Z; return this; }

  vector3d!(T) opAdd(const vector3d!(T) other) const { return vector3d!(T)(X + other.X, Y + other.Y, Z + other.Z); }
  vector3d!(T) opAddAssign(const vector3d!(T) other) { X+=other.X; Y+=other.Y; Z+=other.Z; return this; }
  vector3d!(T) opAdd(const T val) const { return vector3d!(T)(X + val, Y + val, Z + val); }
  vector3d!(T) opAddAssign(const T val) { X+=val; Y+=val; Z+=val; return this; }

  vector3d!(T) opSub(const vector3d!(T) other) const { return vector3d!(T)(X - other.X, Y - other.Y, Z - other.Z); }
  vector3d!(T) opSubAssign(const vector3d!(T) other) { X-=other.X; Y-=other.Y; Z-=other.Z; return this; }
  vector3d!(T) opSub(const T val) const { return vector3d!(T)(X - val, Y - val, Z - val); }
  vector3d!(T) opSubAssign(const T val) { X-=val; Y-=val; Z-=val; return this; }

  vector3d!(T) opMul(const vector3d!(T) other) const { return vector3d!(T)(X * other.X, Y * other.Y, Z * other.Z); }
  vector3d!(T) opMulAssign(const vector3d!(T) other) { X*=other.X; Y*=other.Y; Z*=other.Z; return this; }
  vector3d!(T) opMul(const T v) const { return vector3d!(T)(X * v, Y * v, Z * v); }
  vector3d!(T) opMulAssign(const T v) { X*=v; Y*=v; Z*=v; return this; }


    
  
  vector3d!(T) opDiv(const vector3d!(T) other) const { return vector3d!(T)(X / other.X, Y / other.Y, Z / other.Z); }
  vector3d!(T) opDivAssign(const vector3d!(T) other) { X/=other.X; Y/=other.Y; Z/=other.Z; return this; }

  vector3d!(T) opDiv(const T v) const {
      static if (isIntegral!T) {
        return vector3d!(T)(X / v, Y / v, Z / v);
      } else {
          T i=cast(T)1.0/v; return vector3d!(T)(X * i, Y * i, Z * i);
      }
  }

  vector3d!(T) opDivAssign(const T v) {
      static if (isIntegral!T) {
          X/=v; Y/=v; Z/=v; return this;
      } else {
          T i=cast(T)1.0/v; X*=i; Y*=i; Z*=i; return this;
      }
  }

  //! Function multiplying a scalar and a vector component-wise.
  //vector3d!(T) opMul(const S scalar, const vector3d!(T) vector) { return vector*scalar; }

  //vector3d!(int) opDiv(int val) const {return vector3d!(int)(cast(int) (X/val), cast(int) (Y/val), cast(int) (Z/val));}
  //vector3d!(int) opDivAssign(int val) {X/=val;Y/=val;Z/=val; return this;}

  //! sort in order X, Y, Z. Equality with rounding tolerance.
  T opCmp(const vector3d!(T) other) const
  {
        T x = X - other.X;
        T y = Y - other.Y;
        T z = Z - other.Z;
        if(!x && !y && !z){ return 0;}
        if(x>0)
        {
            return 1;
        }
        if(x==0){
            if(y>0){
                return 1;
            }
            if(y==0){
                if(z>0){
                    return 1;
                }
            }
        }
        return -1;
    }

  //! use weak float compare
  bool opEquals(ref const vector3d!(T) other) const
  {
    return this.equals(other);
  }

  // functions

  //! returns if this vector equals the other one, taking floating point rounding errors into account
  bool equals(const vector3d!(T) other, const T tolerance = cast(T)ROUNDING_ERROR_f32 ) const
  {
    return stolen.math.equals(X, other.X, tolerance) &&
      stolen.math.equals(Y, other.Y, tolerance) &&
      stolen.math.equals(Z, other.Z, tolerance);
  }

  vector3d!(T) set(const T nx, const T ny, const T nz) {X=nx; Y=ny; Z=nz; return this;}
  vector3d!(T) set(const vector3d!(T) p) {X=p.X; Y=p.Y; Z=p.Z;return this;}

  //! Get length of the vector.
  T getLength() const { return cast (T) (sqrt(cast(real)( X*X + Y*Y + Z*Z ))); }

  //! Get squared length of the vector.
  /** This is useful because it is much faster than getLength().
  \return Squared length of the vector. */
  T getLengthSQ() const { return X*X + Y*Y + Z*Z; }

  //! Get the dot product with another vector.
  T dotProduct(const vector3d!(T) other) const
  {
    return X*other.X + Y*other.Y + Z*other.Z;
  }

  //! Get distance from another point.
  /** Here, the vector is interpreted as point in 3 dimensional space. */
  T getDistanceFrom(const vector3d!(T) other) const
  {
    return (vector3d!(T)(X - other.X, Y - other.Y, Z - other.Z)).getLength();
  }

  //! Returns squared distance from another point.
  /** Here, the vector is interpreted as point in 3 dimensional space. */
  T getDistanceFromSQ(const vector3d!(T) other) const
  {
    return (vector3d!(T)(X - other.X, Y - other.Y, Z - other.Z)).getLengthSQ();
  }

  //! Calculates the cross product with another vector.
  /** \param p Vector to multiply with.
  \return Crossproduct of this vector with p. */
  vector3d!(T) crossProduct(const vector3d!(T) p) const
  {
    return vector3d!(T)(Y * p.Z - Z * p.Y, Z * p.X - X * p.Z, X * p.Y - Y * p.X);
  }

  //! Returns if this vector interpreted as a point is on a line between two other points.
  /** It is assumed that the point is on the line.
  \param begin Beginning vector to compare between.
  \param end Ending vector to compare between.
  \return True if this vector is between begin and end, false if not. */
  bool isBetweenPoints(const vector3d!(T) begin, const vector3d!(T) end) const
  {
    const T f = (end - begin).getLengthSQ();
    return getDistanceFromSQ(begin) <= f &&
      getDistanceFromSQ(end) <= f;
  }

  //! Normalizes the vector.
  /** In case of the 0 vector the result is still 0, otherwise
  the length of the vector will be 1.
  \return Reference to this vector after normalization. */
  vector3d!(T) normalize()
  {
    double length = X*X + Y*Y + Z*Z;
    if (stolen.math.equals(length, 0.0)) // this check isn't an optimization but prevents getting NAN in the sqrt.
      return this;
    length = 1.0 / sqrt(length);

    X = cast(T)(X * length);
    Y = cast(T)(Y * length);
    Z = cast(T)(Z * length);
    return this;
  }

  //! Sets the length of the vector to a new value
  vector3d!(T) setLength(T newlength)
  {
    normalize();
    return (this *= newlength);
  }

  //! Inverts the vector.
  vector3d!(T) invert()
  {
    X *= -1;
    Y *= -1;
    Z *= -1;
    return this;
  }

  //! Rotates the vector by a specified number of degrees around the Y axis and the specified center.
  /** \param degrees Number of degrees to rotate around the Y axis.
  \param center The center of the rotation. */
  void rotateXZBy(double degrees, vector3d!(T) center)
  {
      enforce(0, "Implement but with radians as makes sense");
    degrees *= DEGTORAD64;
    double cs = cos(degrees);
    double sn = sin(degrees);
    X -= center.X;
    Z -= center.Z;
    set(cast (T)(X*cs - Z*sn), Y, cast(T)(X*sn + Z*cs));
    X += center.X;
    Z += center.Z;
  }

  //! Rotates the vector by a specified number of radians around the Z axis and the specified center.
  /** \param degrees: Number of radians to rotate around the Z axis.
  \param center: The center of the rotation. */
  void rotateXYBy(double radians, vector3d!(T) center)
  {
    double cs = cos(radians);
    double sn = sin(radians);
    X -= center.X;
    Y -= center.Y;
    set(cast (T)(X*cs - Y*sn), cast (T)(X*sn + Y*cs), Z);
    X += center.X;
    Y += center.Y;
  }

  //! Rotates the vector by a specified number of degrees around the X axis and the specified center.
  /** \param degrees: Number of degrees to rotate around the X axis.
  \param center: The center of the rotation. */
  void rotateYZBy(double degrees, vector3d!(T) center)
  {
      enforce(0, "Implement but with radians as makes sense");
    degrees *= DEGTORAD64;
    double cs = cos(degrees);
    double sn = sin(degrees);
    Z -= center.Z;
    Y -= center.Y;
    set(X, cast (T)(Y*cs - Z*sn), cast (T)(Y*sn + Z*cs));
    Z += center.Z;
    Y += center.Y;
  }

  //! Creates an interpolated vector between this vector and another vector.
  /** \param other The other vector to interpolate with.
  \param d Interpolation value between 0.0f (all the other vector) and 1.0f (all this vector).
  Note that this is the opposite direction of interpolation to getInterpolated_quadratic()
  \return An interpolated vector.  This vector is not modified. */
  vector3d!(T) getInterpolated(const vector3d!(T) other, double d) const
  {
    const double inv = 1.0 - d;
    return vector3d!(T)(cast (T)(other.X*inv + X*d), cast (T)(other.Y*inv + Y*d), cast (T)(other.Z*inv + Z*d));
  }

  //! Creates a quadratically interpolated vector between this and two other vectors.
  /** \param v2 Second vector to interpolate with.
  \param v3 Third vector to interpolate with (maximum at 1.0f)
  \param d Interpolation value between 0.0f (all this vector) and 1.0f (all the 3rd vector).
  Note that this is the opposite direction of interpolation to getInterpolated() and interpolate()
  \return An interpolated vector. This vector is not modified. */
  vector3d!(T) getInterpolated_quadratic(const vector3d!(T) v2, const vector3d!(T) v3, double d) const
  {
    // this*(1-d)*(1-d) + 2 * v2 * (1-d) + v3 * d * d;
    const double inv = cast(T) 1.0 - d;
    const double mul0 = inv * inv;
    const double mul1 = cast(T) 2.0 * d * inv;
    const double mul2 = d * d;

    return vector3d!(T) (cast(T)(X * mul0 + v2.X * mul1 + v3.X * mul2),
        cast(T)(Y * mul0 + v2.Y * mul1 + v3.Y * mul2),
        cast(T)(Z * mul0 + v2.Z * mul1 + v3.Z * mul2));
  }

  //! Sets this vector to the linearly interpolated vector between a and b.
  /** \param a first vector to interpolate with, maximum at 1.0f
  \param b second vector to interpolate with, maximum at 0.0f
  \param d Interpolation value between 0.0f (all vector b) and 1.0f (all vector a)
  Note that this is the opposite direction of interpolation to getInterpolated_quadratic()
  */
  vector3d!(T) interpolate(const vector3d!(T) a, const vector3d!(T) b, double d)
  {
    X = cast(T)(cast(double)b.X + ( ( a.X - b.X ) * d ));
    Y = cast(T)(cast(double)b.Y + ( ( a.Y - b.Y ) * d ));
    Z = cast (T)(cast(double)b.Z + ( ( a.Z - b.Z ) * d ));
    return this;
  }


  //! Get the rotations that would make a (0,0,1) direction vector point in the same direction as this direction vector.
  /** Thanks to Arras on the Irrlicht forums for this method.  This utility method is very useful for
  orienting scene nodes towards specific targets.  For example, if this vector represents the difference
  between two scene nodes, then applying the result of getHorizontalAngle() to one scene node will point
  it at the other one.
  Example code:
  // Where target and seeker are of type ISceneNode*
  const vector3df toTarget(target->getAbsolutePosition() - seeker->getAbsolutePosition());
  const vector3df requiredRotation = toTarget.getHorizontalAngle();
  seeker->setRotation(requiredRotation);

  \return A rotation vector containing the X (pitch) and Y (raw) rotations (in degrees) that when applied to a
  +Z (e.g. 0, 0, 1) direction vector would make it point in the same direction as this vector. The Z (roll) rotation
  is always 0, since two Euler rotations are sufficient to point in any given direction. */
  vector3d!(T) getHorizontalAngle() const
  {
    vector3d!(T) angle;

    const double tmp = (atan2(cast(double)X, cast(double)Z) * RADTODEG64);
    angle.Y = cast(T)tmp;

    if (angle.Y < 0)
      angle.Y += 360;
    if (angle.Y >= 360)
      angle.Y -= 360;

    const double z1 = sqrt(cast(real)X*X + Z*Z);

    angle.X = cast(T)(atan2(cast(double)z1, cast(double)Y) * RADTODEG64 - 90.0);

    if (angle.X < 0)
      angle.X += 360;
    if (angle.X >= 360)
      angle.X -= 360;

    return angle;
  }

  //! Get the spherical coordinate angles
  /** This returns Euler degrees for the point represented by
  this vector.  The calculation assumes the pole at (0,1,0) and
  returns the angles in X and Y.
  */
  vector3d!(T) getSphericalCoordinateAngles()
  {
    vector3d!(T) angle;
    const double length = X*X + Y*Y + Z*Z;

    if (length)
    {
      if (X!=0)
      {
        angle.Y = cast(T)(atan2(cast(double)Z,cast(double)X) * RADTODEG64);
      }
      else if (Z<0)
        angle.Y=180;

      angle.X = cast(T)(acos(Y * (1.0/ sqrt(length))) * RADTODEG64);
    }
    return angle;
  }

  //! Builds a direction vector from (this) rotation vector.
  /** This vector is assumed to be a rotation vector composed of 3 Euler angle rotations, in degrees.
  The implementation performs the same calculations as using a matrix to do the rotation.

  \param[in] forwards  The direction representing "forwards" which will be rotated by this vector.
  If you do not provide a direction, then the +Z axis (0, 0, 1) will be assumed to be forwards.
  \return A direction vector calculated by rotating the forwards direction by the 3 Euler angles
  (in degrees) represented by this vector. */
  vector3d!(T) rotationToDirection(vector3d!(T)* forwards = null) const
  {
    if (forwards is null)
      forwards = &vector3d!(T)(cast(T) 0, cast(T) 0, cast(T) 1);

    const double cr = cos( DEGTORAD64 * X );
    const double sr = sin( DEGTORAD64 * X );
    const double cp = cos( DEGTORAD64 * Y );
    const double sp = sin( DEGTORAD64 * Y );
    const double cy = cos( DEGTORAD64 * Z );
    const double sy = sin( DEGTORAD64 * Z );

    const double srsp = sr*sp;
    const double crsp = cr*sp;

    const double pseudoMatrix[] = [
      ( cp*cy ), ( cp*sy ), ( -sp ),
      ( srsp*cy-cr*sy ), ( srsp*sy+cr*cy ), ( sr*cp ),
      ( crsp*cy+sr*sy ), ( crsp*sy-sr*cy ), ( cr*cp )];

    return vector3d!(T)(
      cast (T)(forwards.X * pseudoMatrix[0] +
        forwards.Y * pseudoMatrix[3] +
        forwards.Z * pseudoMatrix[6]),
      cast (T)(forwards.X * pseudoMatrix[1] +
        forwards.Y * pseudoMatrix[4] +
        forwards.Z * pseudoMatrix[7]),
      cast (T)(forwards.X * pseudoMatrix[2] +
        forwards.Y * pseudoMatrix[5] +
        forwards.Z * pseudoMatrix[8]));
  }

  //! Fills an array of 4 values with the vector data (usually floats).
  /** Useful for setting in shader constants for example. The fourth value
  will always be 0. */
  void getAs4Values(T* array) const
  {
    array[0] = X;
    array[1] = Y;
    array[2] = Z;
    array[3] = 0;
  }

  //! X coordinate of the vector
  T X = 0;

  //! Y coordinate of the vector
  T Y = 0;

  //! Z coordinate of the vector
  T Z = 0;
  

    string toString() {
        return typeof(this).stringof ~
            " (" ~ to!string(X)
            ~ ", " ~ to!string(Y)
            ~ ", " ~ to!string(Z) ~ ")";
    }  
};

//! partial specialization for integer vectors
// Implementor note: inline keyword needed due to template specialization for s32. Otherwise put specialization into a .cpp


//! Typedef for a f32 3d vector.
alias vector3d!(float) vector3df;

//! Typedef for an integer 3d vector.
//alias vector3d!(int) vector3di;

