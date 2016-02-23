// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module stolen.matrix4;

import math.vector;

import stolen.plane3d;
import stolen.aabbox3d;
import stolen.math;

import std.c.string;

//! 4x4 matrix. Mostly used as transformation matrix for 3d calculations.
/** The matrix is a D3D style matrix, row major with translations in the 4th row. */
struct CMatrix4(T)
{
  public:

    //! Constructor Flags
    enum eConstructor
    {
      EM4CONST_NOTHING,
      EM4CONST_COPY,
      EM4CONST_IDENTITY,
      EM4CONST_TRANSPOSED,
      EM4CONST_INVERSE,
      EM4CONST_INVERSE_TRANSPOSED
    };

    //! Default constructor
    /** \param constructor Choose the initialization style */
    this( eConstructor constructor = eConstructor.EM4CONST_IDENTITY )
    {
      switch ( constructor )
      {
        case eConstructor.EM4CONST_NOTHING:
        case eConstructor.EM4CONST_COPY:
          break;
        case eConstructor.EM4CONST_IDENTITY:
        case eConstructor.EM4CONST_INVERSE:
        default:
          makeIdentity();
          break;
      }
    }

    //! Copy constructor
    /** \param other Other matrix to copy from
    \param constructor Choose the initialization style */
    this(const CMatrix4!(T) other, eConstructor constructor = eConstructor.EM4CONST_COPY)
    {
      switch ( constructor )
      {
                default:
        case eConstructor.EM4CONST_IDENTITY:
          makeIdentity();
          break;
        case eConstructor.EM4CONST_NOTHING:
          break;
        case eConstructor.EM4CONST_COPY:
          this = other;
          break;
        case eConstructor.EM4CONST_TRANSPOSED:
          other.getTransposed(this);
          break;
        case eConstructor.EM4CONST_INVERSE:
          if (!other.getInverse(this))
            memset(M.ptr, 0, 16*T.sizeof);
          break;
        case eConstructor.EM4CONST_INVERSE_TRANSPOSED:
          if (!other.getInverse(this))
            memset(M.ptr, 0, 16*T.sizeof);
          else
            this=getTransposed();
          break;
      }
    }

    //! Simple operator for directly accessing every element of the matrix.
    ref T at(const int row, const int col)
    {
      return M[ row * 4 + col ];
    }

    //! Simple operator for directly accessing every element of the matrix.
    ref const(T) at(const int row, const int col) const { return M[row * 4 + col]; }

    //! Simple operator for linearly accessing every element of the matrix.
    ref T opIndex(uint index)
    {
      return M[index];
    }

    //! Simple operator for linearly accessing every element of the matrix.
    ref const(T) opIndex(uint index) const { return M[index]; }

    void opIndexAssign(T val, uint index)  { M[index] = val; }
    void opIndexAssign(const T val, uint index) const { (cast(T[16]) M)[] = val; }

    //! Sets this matrix equal to the other matrix.
    CMatrix4!(T) opAssign(const CMatrix4!(T) other)
    {
      memcpy(M.ptr, other.M.ptr, 16*T.sizeof);

      return this;
    }

    //! Sets all elements of this matrix to the value.
    CMatrix4!(T) opAssign(const T scalar)
    {
        M[] = scalar;
        return this;
    }

    //! Returns pointer to internal array
    const T* pointer() { return cast(T*) M.ptr; }
    T* pointer()
    {
      return M.ptr;
    }

    //! Returns true if other matrix is equal to this matrix.
    bool opEquals(const ref CMatrix4!(T) other) const
    {
        return M[] == other.M[];
    }

    //! Add another matrix.
    CMatrix4!(T) opAdd(const CMatrix4!(T) other) const
    {
        CMatrix4!(T) temp;
        temp.M[] = M[] + other.M[];
        return temp;
    }

    //! Add another matrix.
    CMatrix4!(T) opAddAssign(const CMatrix4!(T) other)
    {
        M[] += other.M[];
        return this;
    }

    //! Subtract another matrix.
    CMatrix4!(T) opSub(const CMatrix4!(T) other) const
    {
        CMatrix4!(T) temp;
        temp.M[] = M[] - other.M[];
        return temp;
    }

    //! Subtract another matrix.
    CMatrix4!(T) opSubAssign(const CMatrix4!(T) other)
    {
        M[] -= other.M[];
        return this;
    }

    //! set this matrix to the product of two matrices
    CMatrix4!(T) setbyproduct(const CMatrix4!(T) other_a, const CMatrix4!(T) other_b )
    {
      return setbyproduct_nocheck(other_a,other_b);
    }

    //! Set this matrix to the product of two matrices
    /** no optimization used,
    use it if you know you never have a identity matrix */
    CMatrix4!(T) setbyproduct_nocheck(const CMatrix4!(T) other_a,const CMatrix4!(T) other_b )
    {
      const T *m1 = other_a.pointer();
      const T *m2 = other_b.pointer();

      M[0] = m1[0]*m2[0] + m1[4]*m2[1] + m1[8]*m2[2] + m1[12]*m2[3];
      M[1] = m1[1]*m2[0] + m1[5]*m2[1] + m1[9]*m2[2] + m1[13]*m2[3];
      M[2] = m1[2]*m2[0] + m1[6]*m2[1] + m1[10]*m2[2] + m1[14]*m2[3];
      M[3] = m1[3]*m2[0] + m1[7]*m2[1] + m1[11]*m2[2] + m1[15]*m2[3];

      M[4] = m1[0]*m2[4] + m1[4]*m2[5] + m1[8]*m2[6] + m1[12]*m2[7];
      M[5] = m1[1]*m2[4] + m1[5]*m2[5] + m1[9]*m2[6] + m1[13]*m2[7];
      M[6] = m1[2]*m2[4] + m1[6]*m2[5] + m1[10]*m2[6] + m1[14]*m2[7];
      M[7] = m1[3]*m2[4] + m1[7]*m2[5] + m1[11]*m2[6] + m1[15]*m2[7];

      M[8] = m1[0]*m2[8] + m1[4]*m2[9] + m1[8]*m2[10] + m1[12]*m2[11];
      M[9] = m1[1]*m2[8] + m1[5]*m2[9] + m1[9]*m2[10] + m1[13]*m2[11];
      M[10] = m1[2]*m2[8] + m1[6]*m2[9] + m1[10]*m2[10] + m1[14]*m2[11];
      M[11] = m1[3]*m2[8] + m1[7]*m2[9] + m1[11]*m2[10] + m1[15]*m2[11];

      M[12] = m1[0]*m2[12] + m1[4]*m2[13] + m1[8]*m2[14] + m1[12]*m2[15];
      M[13] = m1[1]*m2[12] + m1[5]*m2[13] + m1[9]*m2[14] + m1[13]*m2[15];
      M[14] = m1[2]*m2[12] + m1[6]*m2[13] + m1[10]*m2[14] + m1[14]*m2[15];
      M[15] = m1[3]*m2[12] + m1[7]*m2[13] + m1[11]*m2[14] + m1[15]*m2[15];

      return this;
    }

    //! Multiply by another matrix.
    CMatrix4!(T) opMul(const CMatrix4!(T) m2) const
    {
      CMatrix4!(T) m3;

      T *m1 = this.pointer();

      m3[0] = m1[0]*m2[0] + m1[4]*m2[1] + m1[8]*m2[2] + m1[12]*m2[3];
      m3[1] = m1[1]*m2[0] + m1[5]*m2[1] + m1[9]*m2[2] + m1[13]*m2[3];
      m3[2] = m1[2]*m2[0] + m1[6]*m2[1] + m1[10]*m2[2] + m1[14]*m2[3];
      m3[3] = m1[3]*m2[0] + m1[7]*m2[1] + m1[11]*m2[2] + m1[15]*m2[3];

      m3[4] = m1[0]*m2[4] + m1[4]*m2[5] + m1[8]*m2[6] + m1[12]*m2[7];
      m3[5] = m1[1]*m2[4] + m1[5]*m2[5] + m1[9]*m2[6] + m1[13]*m2[7];
      m3[6] = m1[2]*m2[4] + m1[6]*m2[5] + m1[10]*m2[6] + m1[14]*m2[7];
      m3[7] = m1[3]*m2[4] + m1[7]*m2[5] + m1[11]*m2[6] + m1[15]*m2[7];

      m3[8] = m1[0]*m2[8] + m1[4]*m2[9] + m1[8]*m2[10] + m1[12]*m2[11];
      m3[9] = m1[1]*m2[8] + m1[5]*m2[9] + m1[9]*m2[10] + m1[13]*m2[11];
      m3[10] = m1[2]*m2[8] + m1[6]*m2[9] + m1[10]*m2[10] + m1[14]*m2[11];
      m3[11] = m1[3]*m2[8] + m1[7]*m2[9] + m1[11]*m2[10] + m1[15]*m2[11];

      m3[12] = m1[0]*m2[12] + m1[4]*m2[13] + m1[8]*m2[14] + m1[12]*m2[15];
      m3[13] = m1[1]*m2[12] + m1[5]*m2[13] + m1[9]*m2[14] + m1[13]*m2[15];
      m3[14] = m1[2]*m2[12] + m1[6]*m2[13] + m1[10]*m2[14] + m1[14]*m2[15];
      m3[15] = m1[3]*m2[12] + m1[7]*m2[13] + m1[11]*m2[14] + m1[15]*m2[15];
      return m3;
    }

    //! Multiply by another matrix.
    CMatrix4!(T) opMulAssign(const CMatrix4!(T) other)
    {
      CMatrix4!(T) temp = CMatrix4!(T)( this );
      return setbyproduct_nocheck( temp, other );
    }

    //! Multiply by scalar.
    CMatrix4!(T) opMul(const T scalar) const
    {
        CMatrix4!(T) temp;
        temp.M[] = M[] * scalar;
        return temp;
    }

    //! Multiply by scalar.
    CMatrix4!(T) opMulAssign(const T scalar)
    {
        M[] *= scalar;
        return this;
    }

    CMatrix4!(T) opMul(const T scalar, const CMatrix4!(T) mat)
    {
      return mat*scalar;
    }

    //! Set matrix to identity.
    CMatrix4!(T) makeIdentity()
    {
        M[] = 0;
        M[0] = M[5] = M[10] = M[15] = cast(T)1;

        return this;
    }

    //! Returns true if the matrix is the identity matrix
    bool isIdentity() const
    {
      if (!stolen.math.equals( M[ 0], cast(T)1 ) ||
          !stolen.math.equals( M[ 5], cast(T)1 ) ||
          !stolen.math.equals( M[10], cast(T)1 ) ||
          !stolen.math.equals( M[15], cast(T)1 ))
        return false;

      for (int i=0; i<4; ++i)
        for (int j=0; j<4; ++j)
          if ((j != i) && (!iszero(this.at(i,j))))
            return false;

      return true;
    }

    //! Returns true if the matrix is orthogonal
    bool isOrthogonal() const
    {
      T dp=M[0] * M[4 ] + M[1] * M[5 ] + M[2 ] * M[6 ] + M[3 ] * M[7 ];
      if (!iszero(dp))
        return false;
      dp = M[0] * M[8 ] + M[1] * M[9 ] + M[2 ] * M[10] + M[3 ] * M[11];
      if (!iszero(dp))
        return false;
      dp = M[0] * M[12] + M[1] * M[13] + M[2 ] * M[14] + M[3 ] * M[15];
      if (!iszero(dp))
        return false;
      dp = M[4] * M[8 ] + M[5] * M[9 ] + M[6 ] * M[10] + M[7 ] * M[11];
      if (!iszero(dp))
        return false;
      dp = M[4] * M[12] + M[5] * M[13] + M[6 ] * M[14] + M[7 ] * M[15];
      if (!iszero(dp))
        return false;
      dp = M[8] * M[12] + M[9] * M[13] + M[10] * M[14] + M[11] * M[15];
      return (iszero(dp));
    }

    //! Returns true if the matrix is the identity matrix
    bool isIdentity_integer_base () const
    {
      if(IR(M[0])!=F32_VALUE_1)  return false;
      if(IR(M[1])!=0)      return false;
      if(IR(M[2])!=0)      return false;
      if(IR(M[3])!=0)      return false;

      if(IR(M[4])!=0)      return false;
      if(IR(M[5])!=F32_VALUE_1)  return false;
      if(IR(M[6])!=0)      return false;
      if(IR(M[7])!=0)      return false;

      if(IR(M[8])!=0)      return false;
      if(IR(M[9])!=0)      return false;
      if(IR(M[10])!=F32_VALUE_1)  return false;
      if(IR(M[11])!=0)    return false;

      if(IR(M[12])!=0)    return false;
      if(IR(M[13])!=0)    return false;
      if(IR(M[13])!=0)    return false;
      if(IR(M[15])!=F32_VALUE_1)  return false;

      return true;
    }

    //! Set the translation of the current matrix. Will erase any previous values.
    CMatrix4!(T) setTranslation( const vector3!T translation )
    {
      M[12] = translation.x;
      M[13] = translation.y;
      M[14] = translation.z;

      return this;
    }

    //! Gets the current translation
    vector3!T getTranslation() const
    {
      return vector3!T(M[12], M[13], M[14]);
    }

    //! Set the inverse translation of the current matrix. Will erase any previous values.
    CMatrix4!(T) setInverseTranslation( const vector3!T translation )
    {
      M[12] = -translation.x;
      M[13] = -translation.y;
      M[14] = -translation.z;

      return this;
    }

    //! Make a rotation matrix from Euler angles. The 4th row and column are unmodified.
    CMatrix4!(T) setRotationRadians( const vector3!T rotation )
    {
      const double cr = cos( rotation.x );
      const double sr = sin( rotation.x );
      const double cp = cos( rotation.y );
      const double sp = sin( rotation.y );
      const double cy = cos( rotation.z );
      const double sy = sin( rotation.z );

      M[0] = cast(T)( cp*cy );
      M[1] = cast(T)( cp*sy );
      M[2] = cast(T)( -sp );

      const double srsp = sr*sp;
      const double crsp = cr*sp;

      M[4] = cast(T)( srsp*cy-cr*sy );
      M[5] = cast(T)( srsp*sy+cr*cy );
      M[6] = cast(T)( sr*cp );

      M[8] = cast(T)( crsp*cy+sr*sy );
      M[9] = cast(T)( crsp*sy-sr*cy );
      M[10] = cast(T)( cr*cp );

      return this;
    }

    //! Make a rotation matrix from Euler angles. The 4th row and column are unmodified.
    CMatrix4!(T) setRotationDegrees( const vector3!T rotation )
    {
        BREAKPOINT;
        assert(0);
        //return setRotationRadians( (vector3!T(rotation)) * cast(T) DEGTORAD );
    }

    //! Returns the rotation, as set by setRotation().
    /** This code was orginally written by by Chev. */
    vector3!T getRotationDegrees() const
    {
        BREAKPOINT;
        assert(0);
        /*
      const CMatrix4!(T) mat = this;
      const vector3!T scale = getScale();
      const vector3d!(double) invScale = vector3d!(double)(reciprocal(scale.x),reciprocal(scale.y),reciprocal(scale.z));

      double Y = -asin(mat[2]*invScale.x);
      const double C = cos(Y);
      Y *= RADTODEG64;

      double rotx, roty, X, Z;

      if (!iszero(C))
      {
        const double invC = reciprocal(C);
        rotx = mat[10] * invC * invScale.z;
        roty = mat[6] * invC * invScale.y;
        X = atan2( roty, rotx ) * RADTODEG64;
        rotx = mat[0] * invC * invScale.x;
        roty = mat[1] * invC * invScale.x;
        Z = atan2( roty, rotx ) * RADTODEG64;
      }
      else
      {
        X = 0.0;
        rotx = mat[5] * invScale.y;
        roty = -mat[4] * invScale.y;
        Z = atan2( roty, rotx ) * RADTODEG64;
      }

      // fix values that get below zero
      // before it would set (!) values to 360
      // that were above 360:
      if (X < 0.0) X += 360.0;
      if (Y < 0.0) Y += 360.0;
      if (Z < 0.0) Z += 360.0;

      return vector3!T(cast(T)X,cast(T)Y,cast(T)Z);
        */
    }

    //! Make an inverted rotation matrix from Euler angles.
    /** The 4th row and column are unmodified. */
    CMatrix4!(T) setInverseRotationRadians( const vector3!T rotation )
    {
      double cr = cos( rotation.x );
      double sr = sin( rotation.x );
      double cp = cos( rotation.y );
      double sp = sin( rotation.y );
      double cy = cos( rotation.z );
      double sy = sin( rotation.z );

      M[0] = cast(T)( cp*cy );
      M[4] = cast(T)( cp*sy );
      M[8] = cast(T)( -sp );

      double srsp = sr*sp;
      double crsp = cr*sp;

      M[1] = cast(T)( srsp*cy-cr*sy );
      M[5] = cast(T)( srsp*sy+cr*cy );
      M[9] = cast(T)( sr*cp );

      M[2] = cast(T)( crsp*cy+sr*sy );
      M[6] = cast(T)( crsp*sy-sr*cy );
      M[10] = cast(T)( cr*cp );

      return this;
    }

    //! Make an inverted rotation matrix from Euler angles.
    /** The 4th row and column are unmodified. */
    CMatrix4!(T) setInverseRotationDegrees( const vector3!T rotation )
    {
        BREAKPOINT;
        assert(0);
        //return setInverseRotationRadians( (vector3!T(rotation)) * DEGTORAD );
    }

    //! Set Scale
    CMatrix4!(T) setScale( const vector3!T scale )
    {
      M[0] = scale.x;
      M[5] = scale.y;
      M[10] = scale.z;

      return this;
    }

    //! Set Scale
    CMatrix4!(T) setScale( const T scale ) { return setScale(vector3!T(scale,scale,scale)); }

    //! Get Scale
    vector3!T getScale() const
    {
      // See http://www.robertblum.com/articles/2005/02/14/decomposing-matrices

      // Deal with the 0 rotation case first
      // Prior to Irrlicht 1.6, we always returned this value.
      if(iszero(M[1]) && iszero(M[2]) &&
        iszero(M[4]) && iszero(M[6]) &&
        iszero(M[8]) && iszero(M[9]))
        return vector3!T(M[0], M[5], M[10]);

      // We have to do the full calculation.
      return vector3!T(sqrt(M[0] * M[0] + M[1] * M[1] + M[2] * M[2]),
                sqrt(M[4] * M[4] + M[5] * M[5] + M[6] * M[6]),
                sqrt(M[8] * M[8] + M[9] * M[9] + M[10] * M[10]));
    }

    //! Translate a vector by the inverse of the translation part of this matrix.
    void inverseTranslateVect( ref vector3!float vect ) const
    {
      vect.x = vect.x-M[12];
      vect.y = vect.y-M[13];
      vect.z = vect.z-M[14];
    }

    //! Rotate a vector by the inverse of the rotation part of this matrix.
    void inverseRotateVect( ref vector3!float vect ) const
    {
      vector3!float tmp = vect;
      vect.x = tmp.x*M[0] + tmp.y*M[1] + tmp.z*M[2];
      vect.y = tmp.x*M[4] + tmp.y*M[5] + tmp.z*M[6];
      vect.z = tmp.x*M[8] + tmp.y*M[9] + tmp.z*M[10];
    }

    //! Rotate a vector by the rotation part of this matrix.
    void rotateVect( ref vector3!float vect ) const
    {
      vector3!float tmp = vect;
      vect.x = tmp.x*M[0] + tmp.y*M[4] + tmp.z*M[8];
      vect.y = tmp.x*M[1] + tmp.y*M[5] + tmp.z*M[9];
      vect.z = tmp.x*M[2] + tmp.y*M[6] + tmp.z*M[10];
    }

    //! An alternate transform vector method, writing into a second vector
    void rotateVect(ref vector3!float vout, const vector3!float vin) const
    {
      vout.x = vin.x*M[0] + vin.y*M[4] + vin.z*M[8];
      vout.y = vin.x*M[1] + vin.y*M[5] + vin.z*M[9];
      vout.z = vin.x*M[2] + vin.y*M[6] + vin.z*M[10];
    }

    //! An alternate transform vector method, writing into an array of 3 floats
    void rotateVect(T* vout,const vector3!float vin) const
    {
      vout[0] = vin.x*M[0] + vin.y*M[4] + vin.z*M[8];
      vout[1] = vin.x*M[1] + vin.y*M[5] + vin.z*M[9];
      vout[2] = vin.x*M[2] + vin.y*M[6] + vin.z*M[10];
    }

    //! Transforms the vector by this matrix
    auto transformVect(vector3!float vect)
    {
        float[3] vector;

        auto x = vect.x*M[0] + vect.y*M[4] + vect.z*M[8] + M[12];
        auto y = vect.x*M[1] + vect.y*M[5] + vect.z*M[9] + M[13];
        auto z = vect.x*M[2] + vect.y*M[6] + vect.z*M[10] + M[14];
        return vector3!float(x,y,z);
    }
    void transformVect( ref vector3!float vect) const
    {
        float[3] vector;

        vector[0] = vect.x*M[0] + vect.y*M[4] + vect.z*M[8] + M[12];
        vector[1] = vect.x*M[1] + vect.y*M[5] + vect.z*M[9] + M[13];
        vector[2] = vect.x*M[2] + vect.y*M[6] + vect.z*M[10] + M[14];
        vect.x = vector[0];
      vect.y = vector[1];
      vect.z = vector[2];
    }

    //! Transforms input vector by this matrix and stores result in output vector
    void transformVect(ref vector3!float vout, const vector3!float vin ) const
    {
      vout.x = vin.x*M[0] + vin.y*M[4] + vin.z*M[8] + M[12];
      vout.y = vin.x*M[1] + vin.y*M[5] + vin.z*M[9] + M[13];
      vout.z = vin.x*M[2] + vin.y*M[6] + vin.z*M[10] + M[14];
    }

    //! An alternate transform vector method, writing into an array of 4 floats
    void transformVect(T* vout,const vector3!float vin) const
    {
      vout[0] = vin.x*M[0] + vin.y*M[4] + vin.z*M[8] + M[12];
      vout[1] = vin.x*M[1] + vin.y*M[5] + vin.z*M[9] + M[13];
      vout[2] = vin.x*M[2] + vin.y*M[6] + vin.z*M[10] + M[14];
      vout[3] = vin.x*M[3] + vin.y*M[7] + vin.z*M[11] + M[15];
    }

    //! Translate a vector by the translation part of this matrix.
    void translateVect( ref vector3!float vect ) const
    {
      vect.x = vect.x+M[12];
      vect.y = vect.y+M[13];
      vect.z = vect.z+M[14];
    }

    //! Transforms a plane by this matrix
    void transformPlane( ref plane3d!(float) plane) const
    {
      vector3!float member;
      // Transform the plane member point, i.e. rotate, translate and scale it.
      transformVect(member, plane.getMemberPoint());

      // Transform the normal by the transposed inverse of the matrix
      CMatrix4!(T) transposedInverse = CMatrix4!(T)(this, eConstructor.EM4CONST_INVERSE_TRANSPOSED);
      vector3!float normal = plane.Normal;
      transposedInverse.transformVect(normal);

      plane.setPlane(member, normal);
    }

    //! Transforms a plane by this matrix
    void transformPlane( const plane3d!(float) vin, ref plane3d!(float) vout) const
    {
      vout = cast (plane3d!(float)) vin;
      transformPlane( vout );
    }

    //! Transforms a axis aligned bounding box
    /** The result box of this operation may not be accurate at all. For
    correct results, use transformBoxEx() */
    void transformBox(ref aabbox3d!(float) box) const
    {
      transformVect(box.MinEdge);
      transformVect(box.MaxEdge);
      box.repair();
    }

    //! Transforms a axis aligned bounding box
    /** The result box of this operation should by accurate, but this operation
    is slower than transformBox(). */
    void transformBoxEx(ref aabbox3d!(float) box) const
    {
      const float[3] Amin = [box.MinEdge.x, box.MinEdge.y, box.MinEdge.z];
      const float[3] Amax = [box.MaxEdge.x, box.MaxEdge.y, box.MaxEdge.z];

      float[3] Bmin;
      float[3] Bmax;

      Bmin[0] = Bmax[0] = M[12];
      Bmin[1] = Bmax[1] = M[13];
      Bmin[2] = Bmax[2] = M[14];

      const CMatrix4!(T) m = this;

      for (uint i; i < 3; ++i)
      {
        for (uint j; j < 3; ++j)
        {
          const float a = m.at(j,i) * Amin[j];
          const float b = m.at(j,i) * Amax[j];

          if (a < b)
          {
            Bmin[i] += a;
            Bmax[i] += b;
          }
          else
          {
            Bmin[i] += b;
            Bmax[i] += a;
          }
        }
      }

      box.MinEdge.x = Bmin[0];
      box.MinEdge.y = Bmin[1];
      box.MinEdge.z = Bmin[2];

      box.MaxEdge.x = Bmax[0];
      box.MaxEdge.y = Bmax[1];
      box.MaxEdge.z = Bmax[2];
    }

    //! Multiplies this matrix by a 1x4 matrix
    void multiplyWith1x4Matrix(T* matrix) const
    {
      /*
      0  1  2  3
      4  5  6  7
      8  9  10 11
      12 13 14 15
      */

      T[4] mat;
      mat[0] = matrix[0];
      mat[1] = matrix[1];
      mat[2] = matrix[2];
      mat[3] = matrix[3];

      matrix[0] = M[0]*mat[0] + M[4]*mat[1] + M[8]*mat[2] + M[12]*mat[3];
      matrix[1] = M[1]*mat[0] + M[5]*mat[1] + M[9]*mat[2] + M[13]*mat[3];
      matrix[2] = M[2]*mat[0] + M[6]*mat[1] + M[10]*mat[2] + M[14]*mat[3];
      matrix[3] = M[3]*mat[0] + M[7]*mat[1] + M[11]*mat[2] + M[15]*mat[3];
    }

    //! Calculates inverse of matrix. Slow.
    /** \return Returns false if there is no inverse matrix.*/
    bool makeInverse()
    {
      CMatrix4!(T) temp;

      if (getInverse(temp))
      {
        this = temp;
        return true;
      }

      return false;
    }

    //! Inverts a primitive matrix which only contains a translation and a rotation
    /** \param out: where result matrix is written to. */
    bool getInversePrimitive ( ref CMatrix4!(T) vout ) const
    {
      vout.M[0 ] = M[0];
      vout.M[1 ] = M[4];
      vout.M[2 ] = M[8];
      vout.M[3 ] = 0;

      vout.M[4 ] = M[1];
      vout.M[5 ] = M[5];
      vout.M[6 ] = M[9];
      vout.M[7 ] = 0;

      vout.M[8 ] = M[2];
      vout.M[9 ] = M[6];
      vout.M[10] = M[10];
      vout.M[11] = 0;

      vout.M[12] = cast(T)-(M[12]*M[0] + M[13]*M[1] + M[14]*M[2]);
      vout.M[13] = cast(T)-(M[12]*M[4] + M[13]*M[5] + M[14]*M[6]);
      vout.M[14] = cast(T)-(M[12]*M[8] + M[13]*M[9] + M[14]*M[10]);
      vout.M[15] = 1;

      return true;
    }

    //! Gets the inversed matrix of this one
    /** \param out: where result matrix is written to.
    \return Returns false if there is no inverse matrix. */
    bool getInverse(ref CMatrix4!(T) vout) const
    {
      /// Calculates the inverse of this Matrix
      /// The inverse is calculated using Cramers rule.
      /// If no inverse exists then 'false' is returned.

      const CMatrix4!(T) m = this;

      float d = (m.at(0, 0) * m.at(1, 1) - m.at(0, 1) * m.at(1, 0)) * (m.at(2, 2) * m.at(3, 3) - m.at(2, 3) * m.at(3, 2)) -
        (m.at(0, 0) * m.at(1, 2) - m.at(0, 2) * m.at(1, 0)) * (m.at(2, 1) * m.at(3, 3) - m.at(2, 3) * m.at(3, 1)) +
        (m.at(0, 0) * m.at(1, 3) - m.at(0, 3) * m.at(1, 0)) * (m.at(2, 1) * m.at(3, 2) - m.at(2, 2) * m.at(3, 1)) +
        (m.at(0, 1) * m.at(1, 2) - m.at(0, 2) * m.at(1, 1)) * (m.at(2, 0) * m.at(3, 3) - m.at(2, 3) * m.at(3, 0)) -
        (m.at(0, 1) * m.at(1, 3) - m.at(0, 3) * m.at(1, 1)) * (m.at(2, 0) * m.at(3, 2) - m.at(2, 2) * m.at(3, 0)) +
        (m.at(0, 2) * m.at(1, 3) - m.at(0, 3) * m.at(1, 2)) * (m.at(2, 0) * m.at(3, 1) - m.at(2, 1) * m.at(3, 0));

      if( iszero ( d ) )
        return false;

      d = reciprocal ( d );

      vout.at(0, 0) = d * (m.at(1, 1) * (m.at(2, 2) * m.at(3, 3) - m.at(2, 3) * m.at(3, 2)) +
          m.at(1, 2) * (m.at(2, 3) * m.at(3, 1) - m.at(2, 1) * m.at(3, 3)) +
          m.at(1, 3) * (m.at(2, 1) * m.at(3, 2) - m.at(2, 2) * m.at(3, 1)));
      vout.at(0, 1) = d * (m.at(2, 1) * (m.at(0, 2) * m.at(3, 3) - m.at(0, 3) * m.at(3, 2)) +
          m.at(2, 2) * (m.at(0, 3) * m.at(3, 1) - m.at(0, 1) * m.at(3, 3)) +
          m.at(2, 3) * (m.at(0, 1) * m.at(3, 2) - m.at(0, 2) * m.at(3, 1)));
      vout.at(0, 2) = d * (m.at(3, 1) * (m.at(0, 2) * m.at(1, 3) - m.at(0, 3) * m.at(1, 2)) +
          m.at(3, 2) * (m.at(0, 3) * m.at(1, 1) - m.at(0, 1) * m.at(1, 3)) +
          m.at(3, 3) * (m.at(0, 1) * m.at(1, 2) - m.at(0, 2) * m.at(1, 1)));
      vout.at(0, 3) = d * (m.at(0, 1) * (m.at(1, 3) * m.at(2, 2) - m.at(1, 2) * m.at(2, 3)) +
          m.at(0, 2) * (m.at(1, 1) * m.at(2, 3) - m.at(1, 3) * m.at(2, 1)) +
          m.at(0, 3) * (m.at(1, 2) * m.at(2, 1) - m.at(1, 1) * m.at(2, 2)));
      vout.at(1, 0) = d * (m.at(1, 2) * (m.at(2, 0) * m.at(3, 3) - m.at(2, 3) * m.at(3, 0)) +
          m.at(1, 3) * (m.at(2, 2) * m.at(3, 0) - m.at(2, 0) * m.at(3, 2)) +
          m.at(1, 0) * (m.at(2, 3) * m.at(3, 2) - m.at(2, 2) * m.at(3, 3)));
      vout.at(1, 1) = d * (m.at(2, 2) * (m.at(0, 0) * m.at(3, 3) - m.at(0, 3) * m.at(3, 0)) +
          m.at(2, 3) * (m.at(0, 2) * m.at(3, 0) - m.at(0, 0) * m.at(3, 2)) +
          m.at(2, 0) * (m.at(0, 3) * m.at(3, 2) - m.at(0, 2) * m.at(3, 3)));
      vout.at(1, 2) = d * (m.at(3, 2) * (m.at(0, 0) * m.at(1, 3) - m.at(0, 3) * m.at(1, 0)) +
          m.at(3, 3) * (m.at(0, 2) * m.at(1, 0) - m.at(0, 0) * m.at(1, 2)) +
          m.at(3, 0) * (m.at(0, 3) * m.at(1, 2) - m.at(0, 2) * m.at(1, 3)));
      vout.at(1, 3) = d * (m.at(0, 2) * (m.at(1, 3) * m.at(2, 0) - m.at(1, 0) * m.at(2, 3)) +
          m.at(0, 3) * (m.at(1, 0) * m.at(2, 2) - m.at(1, 2) * m.at(2, 0)) +
          m.at(0, 0) * (m.at(1, 2) * m.at(2, 3) - m.at(1, 3) * m.at(2, 2)));
      vout.at(2, 0) = d * (m.at(1, 3) * (m.at(2, 0) * m.at(3, 1) - m.at(2, 1) * m.at(3, 0)) +
          m.at(1, 0) * (m.at(2, 1) * m.at(3, 3) - m.at(2, 3) * m.at(3, 1)) +
          m.at(1, 1) * (m.at(2, 3) * m.at(3, 0) - m.at(2, 0) * m.at(3, 3)));
      vout.at(2, 1) = d * (m.at(2, 3) * (m.at(0, 0) * m.at(3, 1) - m.at(0, 1) * m.at(3, 0)) +
          m.at(2, 0) * (m.at(0, 1) * m.at(3, 3) - m.at(0, 3) * m.at(3, 1)) +
          m.at(2, 1) * (m.at(0, 3) * m.at(3, 0) - m.at(0, 0) * m.at(3, 3)));
      vout.at(2, 2) = d * (m.at(3, 3) * (m.at(0, 0) * m.at(1, 1) - m.at(0, 1) * m.at(1, 0)) +
          m.at(3, 0) * (m.at(0, 1) * m.at(1, 3) - m.at(0, 3) * m.at(1, 1)) +
          m.at(3, 1) * (m.at(0, 3) * m.at(1, 0) - m.at(0, 0) * m.at(1, 3)));
      vout.at(2, 3) = d * (m.at(0, 3) * (m.at(1, 1) * m.at(2, 0) - m.at(1, 0) * m.at(2, 1)) +
          m.at(0, 0) * (m.at(1, 3) * m.at(2, 1) - m.at(1, 1) * m.at(2, 3)) +
          m.at(0, 1) * (m.at(1, 0) * m.at(2, 3) - m.at(1, 3) * m.at(2, 0)));
      vout.at(3, 0) = d * (m.at(1, 0) * (m.at(2, 2) * m.at(3, 1) - m.at(2, 1) * m.at(3, 2)) +
          m.at(1, 1) * (m.at(2, 0) * m.at(3, 2) - m.at(2, 2) * m.at(3, 0)) +
          m.at(1, 2) * (m.at(2, 1) * m.at(3, 0) - m.at(2, 0) * m.at(3, 1)));
      vout.at(3, 1) = d * (m.at(2, 0) * (m.at(0, 2) * m.at(3, 1) - m.at(0, 1) * m.at(3, 2)) +
          m.at(2, 1) * (m.at(0, 0) * m.at(3, 2) - m.at(0, 2) * m.at(3, 0)) +
          m.at(2, 2) * (m.at(0, 1) * m.at(3, 0) - m.at(0, 0) * m.at(3, 1)));
      vout.at(3, 2) = d * (m.at(3, 0) * (m.at(0, 2) * m.at(1, 1) - m.at(0, 1) * m.at(1, 2)) +
          m.at(3, 1) * (m.at(0, 0) * m.at(1, 2) - m.at(0, 2) * m.at(1, 0)) +
          m.at(3, 2) * (m.at(0, 1) * m.at(1, 0) - m.at(0, 0) * m.at(1, 1)));
      vout.at(3, 3) = d * (m.at(0, 0) * (m.at(1, 1) * m.at(2, 2) - m.at(1, 2) * m.at(2, 1)) +
          m.at(0, 1) * (m.at(1, 2) * m.at(2, 0) - m.at(1, 0) * m.at(2, 2)) +
          m.at(0, 2) * (m.at(1, 0) * m.at(2, 1) - m.at(1, 1) * m.at(2, 0)));

      return true;
    }

    //! Builds a right-handed perspective projection matrix based on a field of view
    CMatrix4!(T) buildProjectionMatrixPerspectiveFovRH(float fieldOfViewRadians, float aspectRatio, float zNear, float zFar)
    {
/*
        const double h = reciprocal(tan(fieldOfViewRadians*0.5));
        assert(aspectRatio!=0.0f); //divide by zero
        const T w = h / aspectRatio;
*/        
        const double w = reciprocal(tan(fieldOfViewRadians*0.5));
        assert(aspectRatio!=0.0f); //divide by zero
        const T h = w * aspectRatio; // 1/w * ratio = 1/(w / ratio)) = 1/with * 1/ratio = 1/width * 1/(height/width) = 1/width * width/height yay

        assert(zNear!=zFar); //divide by zero
        M[0] = w;
        M[1] = 0;
        M[2] = 0;
        M[3] = 0;

        M[4] = 0;
        M[5] = cast(T)h;
        M[6] = 0;
        M[7] = 0;

        M[8] = 0;
        M[9] = 0;
        M[10] = cast(T)(zFar/(zNear-zFar)); // DirectX version
        //    M[10] = (T)(zFar+zNear/(zNear-zFar)); // OpenGL version
        M[11] = -1;

        M[12] = 0;
        M[13] = 0;
        M[14] = cast(T)(zNear*zFar/(zNear-zFar)); // DirectX version
        //    M[14] = (T)(2.0f*zNear*zFar/(zNear-zFar)); // OpenGL version
        M[15] = 0;

        return this;
    }

    //! Builds a frustum projection matrix, (identicle to opengl.glFrustum)
    CMatrix4!(T) buildProjectionMatrixFrustum(float left, float right, float bottom, float top, float zNear, float zFar)
    {
      assert(zNear!=zFar); //divide by zero

      M[0] = (zNear*2) / (right - left);
      M[1] = 0;
      M[2] = (right + left) / (right - left);
      M[3] = 0;

      M[4] = 0;
      M[5] = (zNear*2) / (top - bottom);
      M[6] = (top + bottom) / (top - bottom);
      M[7] = 0;

      M[8] = 0;
      M[9] = 0;
      M[10] = -((zFar + zNear) / (zFar - zNear));
      M[11] = -((2 * zFar * zNear) / (zFar - zNear));

      M[12] = 0;
      M[13] = 0;
      M[14] = -1;
      M[15] = 0;

      return this;
    }

    //! Builds a left-handed perspective projection matrix based on a field of view
    CMatrix4!(T) buildProjectionMatrixPerspectiveFovLH(float fieldOfViewRadians, float aspectRatio, float zNear, float zFar)
    {
      const double h = reciprocal(tan(fieldOfViewRadians*0.5));
      assert(aspectRatio!=0.0f); //divide by zero
      const T w = cast(T)(h / aspectRatio);

      assert(zNear!=zFar); //divide by zero
      M[0] = w;
      M[1] = 0;
      M[2] = 0;
      M[3] = 0;

      M[4] = 0;
      M[5] = cast(T)h;
      M[6] = 0;
      M[7] = 0;

      M[8] = 0;
      M[9] = 0;
      M[10] =cast (T)(zFar/(zFar-zNear));
      M[11] = 1;

      M[12] = 0;
      M[13] = 0;
      M[14] = cast(T)(-zNear*zFar/(zFar-zNear));
      M[15] = 0;

      return this;
    }

    //! Builds a right-handed perspective projection matrix.
    CMatrix4!(T) buildProjectionMatrixPerspectiveRH(float widthOfViewVolume, float heightOfViewVolume, float zNear, float zFar)
    {
      assert(widthOfViewVolume!=0.0f); //divide by zero
      assert(heightOfViewVolume!=0.0f); //divide by zero
      assert(zNear!=zFar); //divide by zero
      M[0] = cast(T)(2*zNear/widthOfViewVolume);
      M[1] = 0;
      M[2] = 0;
      M[3] = 0;

      M[4] = 0;
      M[5] = cast(T)(2*zNear/heightOfViewVolume);
      M[6] = 0;
      M[7] = 0;

      M[8] = 0;
      M[9] = 0;
      M[10] = cast(T)(zFar/(zNear-zFar));
      M[11] = -1;

      M[12] = 0;
      M[13] = 0;
      M[14] = cast(T)(zNear*zFar/(zNear-zFar));
      M[15] = 0;

      return this;
    }

    //! Builds a left-handed perspective projection matrix.
    CMatrix4!(T) buildProjectionMatrixPerspectiveLH(float widthOfViewVolume, float heightOfViewVolume, float zNear, float zFar)
    {
      assert(widthOfViewVolume!=0.0f); //divide by zero
      assert(heightOfViewVolume!=0.0f); //divide by zero
      assert(zNear!=zFar); //divide by zero
      M[0] = cast(T)(2*zNear/widthOfViewVolume);
      M[1] = 0;
      M[2] = 0;
      M[3] = 0;

      M[4] = 0;
      M[5] = cast(T)(2*zNear/heightOfViewVolume);
      M[6] = 0;
      M[7] = 0;

      M[8] = 0;
      M[9] = 0;
      M[10] = cast(T)(zFar/(zFar-zNear));
      M[11] = 1;

      M[12] = 0;
      M[13] = 0;
      M[14] = cast(T)(zNear*zFar/(zNear-zFar));
      M[15] = 0;

      return this;
    }

    //! Builds a left-handed orthogonal projection matrix.
    CMatrix4!(T) buildProjectionMatrixOrthoLH(float widthOfViewVolume, float heightOfViewVolume, float zNear, float zFar)
    {
      assert(widthOfViewVolume!=0.0f); //divide by zero
      assert(heightOfViewVolume!=0.0f); //divide by zero
      assert(zNear!=zFar); //divide by zero
      M[0] = cast(T)(2/widthOfViewVolume);
      M[1] = 0;
      M[2] = 0;
      M[3] = 0;

      M[4] = 0;
      M[5] = cast(T)(2/heightOfViewVolume);
      M[6] = 0;
      M[7] = 0;

      M[8] = 0;
      M[9] = 0;
      M[10] = cast(T)(1/(zFar-zNear));
      M[11] = 0;

      M[12] = 0;
      M[13] = 0;
      M[14] = cast(T)(zNear/(zNear-zFar));
      M[15] = 1;

      return this;
    }

    //! Builds a right-handed orthogonal projection matrix.
    CMatrix4!(T) buildProjectionMatrixOrthoRH(float widthOfViewVolume, float heightOfViewVolume, float zNear, float zFar)
    {
      assert(widthOfViewVolume!=0.0f); //divide by zero
      assert(heightOfViewVolume!=0.0f); //divide by zero
      assert(zNear!=zFar); //divide by zero
      M[0] = cast(T)(2/widthOfViewVolume);
      M[1] = 0;
      M[2] = 0;
      M[3] = 0;

      M[4] = 0;
      M[5] = cast(T)(2/heightOfViewVolume);
      M[6] = 0;
      M[7] = 0;

      M[8] = 0;
      M[9] = 0;
      M[10] = cast(T)(1/(zNear-zFar));
      M[11] = 0;

      M[12] = 0;
      M[13] = 0;
      M[14] = cast(T)(zNear/(zNear-zFar));
      M[15] = -1;

      return this;
    }

    //! Builds a left-handed look-at matrix.
    CMatrix4!(T) buildCameraLookAtMatrixLH(
        const vector3!float position,
        const vector3!float target,
        const vector3!float upVector)
    {
      vector3!float zaxis = target - position;
      zaxis.normalizeThis();

      vector3!float xaxis = upVector.crossProduct(zaxis);
      xaxis.normalizeThis();

      vector3!float yaxis = zaxis.crossProduct(xaxis);

      M[0] = cast(T)xaxis.x;
      M[1] = cast(T)yaxis.x;
      M[2] = cast(T)zaxis.x;
      M[3] = 0;

      M[4] = cast(T)xaxis.y;
      M[5] = cast(T)yaxis.y;
      M[6] = cast(T)zaxis.y;
      M[7] = 0;

      M[8] = cast(T)xaxis.z;
      M[9] = cast(T)yaxis.z;
      M[10] = cast(T)zaxis.z;
      M[11] = 0;

      M[12] = cast(T)-xaxis.dotProduct(position);
      M[13] = cast(T)-yaxis.dotProduct(position);
      M[14] = cast(T)-zaxis.dotProduct(position);
      M[15] = 1;

      return this;
    }

    //! Builds a right-handed look-at matrix.
    CMatrix4!(T) buildCameraLookAtMatrixRH(
        const vector3!float position,
        const vector3!float target,
        const vector3!float upVector)
    {
      vector3!float zaxis = position - target;
      zaxis.normalizeThis();

      vector3!float xaxis = upVector.crossProduct(zaxis);
      xaxis.normalizeThis();

      vector3!float yaxis = zaxis.crossProduct(xaxis);

      M[0] = cast(T)xaxis.x;
      M[1] = cast(T)yaxis.x;
      M[2] = cast(T)zaxis.x;
      M[3] = 0;

      M[4] = cast(T)xaxis.y;
      M[5] = cast(T)yaxis.y;
      M[6] = cast(T)zaxis.y;
      M[7] = 0;

      M[8] = cast(T)xaxis.z;
      M[9] = cast(T)yaxis.z;
      M[10] = cast(T)zaxis.z;
      M[11] = 0;

      M[12] = cast(T)-xaxis.dotProduct(position);
      M[13] = cast(T)-yaxis.dotProduct(position);
      M[14] = cast(T)-zaxis.dotProduct(position);
      M[15] = 1;

      return this;
    }

    //! Builds a matrix that flattens geometry into a plane.
    /** \param light: light source
    \param plane: plane into which the geometry if flattened into
    \param point: value between 0 and 1, describing the light source.
    If this is 1, it is a point light, if it is 0, it is a directional light. */
    CMatrix4!(T) buildShadowMatrix(const vector3!float light, plane3df plane, float point=1.0f)
    {
      plane.Normal.normalizeThis();
      const float d = plane.Normal.dotProduct(light);

      M[ 0] = cast(T)(-plane.Normal.x * light.x + d);
      M[ 1] = cast(T)(-plane.Normal.x * light.y);
      M[ 2] = cast(T)(-plane.Normal.x * light.z);
      M[ 3] = cast(T)(-plane.Normal.x * point);

      M[ 4] = cast(T)(-plane.Normal.y * light.x);
      M[ 5] = cast(T)(-plane.Normal.y * light.y + d);
      M[ 6] = cast(T)(-plane.Normal.y * light.z);
      M[ 7] = cast(T)(-plane.Normal.y * point);

      M[ 8] = cast(T)(-plane.Normal.z * light.x);
      M[ 9] = cast(T)(-plane.Normal.z * light.y);
      M[10] = cast(T)(-plane.Normal.z * light.z + d);
      M[11] = cast(T)(-plane.Normal.z * point);

      M[12] = cast(T)(-plane.D * light.x);
      M[13] = cast(T)(-plane.D * light.y);
      M[14] = cast(T)(-plane.D * light.z);
      M[15] = cast(T)(-plane.D * point + d);

      return this;
    }


    //! Creates a new matrix as interpolated matrix from two other ones.
    /** \param b: other matrix to interpolate with
    \param time: Must be a value between 0 and 1. */
    CMatrix4!(T) interpolate(const CMatrix4!(T) b, float time) const
    {
      CMatrix4!(T) mat;

      for (uint i=0; i < 16; i += 4)
      {
        mat.M[i+0] = cast(T)(M[i+0] + ( b.M[i+0] - M[i+0] ) * time);
        mat.M[i+1] = cast(T)(M[i+1] + ( b.M[i+1] - M[i+1] ) * time);
        mat.M[i+2] = cast(T)(M[i+2] + ( b.M[i+2] - M[i+2] ) * time);
        mat.M[i+3] = cast(T)(M[i+3] + ( b.M[i+3] - M[i+3] ) * time);
      }
      return mat;
    }

    //! Gets transposed matrix
    CMatrix4!(T) getTransposed() const
    {
      CMatrix4!(T) t;
      getTransposed ( t );
      return t;
    }

    //! Gets transposed matrix
    void getTransposed(ref CMatrix4!(T) o ) const
    {
      o[ 0] = M[ 0];
      o[ 1] = M[ 4];
      o[ 2] = M[ 8];
      o[ 3] = M[12];

      o[ 4] = M[ 1];
      o[ 5] = M[ 5];
      o[ 6] = M[ 9];
      o[ 7] = M[13];

      o[ 8] = M[ 2];
      o[ 9] = M[ 6];
      o[10] = M[10];
      o[11] = M[14];

      o[12] = M[ 3];
      o[13] = M[ 7];
      o[14] = M[11];
      o[15] = M[15];
    }

    //! Builds a matrix that rotates from one vector to another
    /** \param from: vector to rotate from
    \param to: vector to rotate to
      */
    CMatrix4!(T) buildRotateFromTo(const vector3!float from, const vector3!float to)
    {
      // unit vectors
      vector3!float f = from;
      vector3!float t = to;
      f.normalizeThis();
      t.normalizeThis();

      // axis multiplication by sin
      vector3!float vs = t.crossProduct ( f );

      // axis of rotation
      vector3!float v = vs;
      v.normalizeThis();

      // cosinus angle
      T ca = f.dotProduct ( t );

      vector3!float vt = v * ( cast(T) 1 - ca );

      M[0] = vt.x * v.x + ca;
      M[5] = vt.y * v.y + ca;
      M[10] = vt.z * v.z + ca;

      vt.x *= v.y;
      vt.z *= v.x;
      vt.y *= v.z;

      M[1] = vt.x - vs.z;
      M[2] = vt.z + vs.y;
      M[3] = cast(T) 0;

      M[4] = vt.x + vs.z;
      M[6] = vt.y - vs.x;
      M[7] = cast(T) 0;

      M[8] = vt.z - vs.y;
      M[9] = vt.y + vs.x;
      M[11] = cast(T) 0;

      M[12] = cast(T) 0;
      M[13] = cast(T) 0;
      M[14] = cast(T) 0;
      M[15] = cast(T) 1;

      return this;
    }

    //! Builds a combined matrix which translates to a center before rotation and translates from origin afterwards
    /** \param center Position to rotate around
    \param translate Translation applied after the rotation
      */
    void setRotationCenter(const vector3!float center, const vector3!float translation)
    {
      M[12] = -M[0]*center.x - M[4]*center.y - M[8]*center.z + (center.x - translation.x );
      M[13] = -M[1]*center.x - M[5]*center.y - M[9]*center.z + (center.y - translation.y );
      M[14] = -M[2]*center.x - M[6]*center.y - M[10]*center.z + (center.z - translation.z );
      M[15] = cast (T) 1.0;
    }

    //! Builds a matrix which rotates a source vector to a look vector over an arbitrary axis
    /** \param camPos: viewer position in world coo
    \param center: object position in world-coo and rotation pivot
    \param translation: object final translation from center
    \param axis: axis to rotate about
    \param from: source vector to rotate from
      */
    void buildAxisAlignedBillboard(const vector3!float camPos,
          const vector3!float center,
          const vector3!float translation,
          const vector3!float axis,
          const vector3!float from)
    {
      // axis of rotation
      vector3!float up = axis;
      up.normalizeThis();

      vector3!float forward = camPos - center;
      forward.normalizeThis();

      vector3!float right = up.crossProduct ( forward );
      right.normalizeThis();

      // correct look vector
      vector3!float look = right.crossProduct ( up );

      // rotate from to

      // axis multiplication by sin
      vector3!float vs = look.crossProduct ( from );

      // cosinus angle
      float ca = from.dotProduct ( look );

      vector3!float vt = up * ( 1.0f - ca );

      M[0] = vt.x * up.x + ca;
      M[5] = vt.y * up.y + ca;
      M[10] = vt.z * up.z + ca;

      vt.x *= up.y;
      vt.z *= up.x;
      vt.y *= up.z;

      M[1] = vt.x - vs.z;
      M[2] = vt.z + vs.y;
      M[3] = cast(T) 0;

      M[4] = vt.x + vs.z;
      M[6] = vt.y - vs.x;
      M[7] = cast(T) 0;

      M[8] = vt.z - vs.y;
      M[9] = vt.y + vs.x;
      M[11] = cast(T) 0;

      setRotationCenter ( center, translation );
    }

    /*
      construct 2D Texture transformations
      rotate about center, scale, and transform.
    */
    //! Set to a texture transformation matrix with the given parameters.
    CMatrix4!(T) buildTextureTransform( float rotateRad,
        const vector2!float rotatecenter,
        const vector2!float translate,
        const vector2!float scale)
    {
      const float c = cos(rotateRad);
      const float s = sin(rotateRad);

      M[0] = cast(T)(c * scale.x);
      M[1] = cast(T)(s * scale.y);
      M[2] = 0;
      M[3] = 0;

      M[4] = cast(T)(-s * scale.x);
      M[5] = cast(T)(c * scale.y);
      M[6] = 0;
      M[7] = 0;

      M[8] = cast(T)(c * scale.x * rotatecenter.x + -s * rotatecenter.y + translate.x);
      M[9] = cast(T)(s * scale.y * rotatecenter.x +  c * rotatecenter.y + translate.y);
      M[10] = 1;
      M[11] = 0;

      M[12] = 0;
      M[13] = 0;
      M[14] = 0;
      M[15] = 1;

      return this;
    }

    //! Set texture transformation rotation
    /** Rotate about z axis, recenter at (0.5,0.5).
    Doesn't clear other elements than those affected
    \param radAngle Angle in radians
    \return Altered matrix */
    CMatrix4!(T) setTextureRotationCenter( float rotateRad )
    {
      const float c = cos(rotateRad);
      const float s = sin(rotateRad);
      M[0] = cast(T)c;
      M[1] = cast(T)s;

      M[4] = cast(T)-s;
      M[5] = cast(T)c;

      M[8] = cast(T)(0.5f * ( s - c) + 0.5f);
      M[9] = cast(T)(-0.5f * ( s + c) + 0.5f);

      return this;
    }

    //! Set texture transformation translation
    /** Doesn't clear other elements than those affected.
    \param x Offset on x axis
    \param y Offset on y axis
    \return Altered matrix */
    CMatrix4!(T) setTextureTranslate( float x, float y )
    {
      M[8] = cast(T)x;
      M[9] = cast(T)y;

      return this;
    }

    //! Set texture transformation translation, using a transposed representation
    /** Doesn't clear other elements than those affected.
    \param x Offset on x axis
    \param y Offset on y axis
    \return Altered matrix */
    CMatrix4!(T) setTextureTranslateTransposed( float x, float y )
    {
      M[2] = cast(T)x;
      M[6] = cast(T)y;

      return this;
    }

    //! Set texture transformation scale
    /** Doesn't clear other elements than those affected.
    \param sx Scale factor on x axis
    \param sy Scale factor on y axis
    \return Altered matrix. */
    CMatrix4!(T) setTextureScale( float sx, float sy )
    {
      M[0] = cast(T)sx;
      M[5] = cast(T)sy;

      return this;
    }

    //! Set texture transformation scale, and recenter at (0.5,0.5)
    /** Doesn't clear other elements than those affected.
    \param sx Scale factor on x axis
    \param sy Scale factor on y axis
    \return Altered matrix. */
    CMatrix4!(T) setTextureScaleCenter( float sx, float sy )
    {
      M[0] = cast(T)sx;
      M[5] = cast(T)sy;
      M[8] = cast(T)(0.5f - 0.5f * sx);
      M[9] = cast(T)(0.5f - 0.5f * sy);

      return this;
    }

    //! Sets all matrix data members at once
    CMatrix4!(T) setM(const T* data)
    {
      memcpy(M.ptr, data, 16*T.sizeof);

      return this;
    }

    //! Sets if the matrix is definitely identity matrix
    void setDefinitelyIdentityMatrix( bool isDefinitelyIdentityMatrix){}

    //! Gets if the matrix is definitely identity matrix
    bool getDefinitelyIdentityMatrix() const { return false; }

    //! Compare two matrices using the equal method
    bool equals(const CMatrix4!(T) other, const T tolerance=cast(T) ROUNDING_ERROR_f64) const
    {
      for (int i; i < 16; ++i)
        if (!stolen.math.equals(M[i], other.M[i], tolerance))
          return false;

      return true;
    }

  private:
    //! Matrix data, stored in row-major order
    T[16] M = [  1,0,0,0,
          0,1,0,0,
          0,0,1,0,
          0,0,0,1];
};

alias CMatrix4!(float) matrix4;

//! global const identity matrix
immutable IdentityMatrix = CMatrix4!(float)();