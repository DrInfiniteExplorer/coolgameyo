// Copyright (C) 2002-2010 Nikolaus Gebhardt
// This file is part of the "Irrlicht Engine".
// For conditions of distribution and use, see copyright notice in irrlicht.h

module cgy.stolen.math;

import std.algorithm;
public import std.math;

const int ROUNDING_ERROR_S32;
const float ROUNDING_ERROR_f32 = 0.000001f;
const double ROUNDING_ERROR_f64 = 0.00000001;

const int F32_VALUE_1	=	0x3f800000;

//! Constant for PI.
const float PI		= 3.14159265359f;

//! Constant for reciprocal of PI.
const float RECIPROCAL_PI	= 1.0f/PI;

//! Constant for half of PI.
const float HALF_PI	= PI/2.0f;

//! Constant for 64bit PI.
const double PI64		= 3.1415926535897932384626433832795028841971693993751;

//! Constant for 64bit reciprocal of PI.
const double RECIPROCAL_PI64 = 1.0/PI64;

//! 32bit Constant for converting from degrees to radians
const float DEGTORAD = PI / 180.0f;

//! 32bit constant for converting from radians to degrees (formally known as GRAD_PI)
const float RADTODEG   = 180.0f / PI;

//! 64bit constant for converting from degrees to radians (formally known as GRAD_PI2)
const double DEGTORAD64 = PI64 / 180.0;

//! 64bit constant for converting from radians to degrees
const double RADTODEG64 = 180.0 / PI64;

//! Utility function to convert a radian value to degrees
/** Provided as it can be clearer to write radToDeg(X) than RADTODEG * X
\param radians	The radians value to convert to degrees.
*/
float radToDeg(float radians)
{
	return RADTODEG * radians;
}

//! Utility function to convert a radian value to degrees
/** Provided as it can be clearer to write radToDeg(X) than RADTODEG * X
\param radians	The radians value to convert to degrees.
*/
double radToDeg(double radians)
{
	return RADTODEG64 * radians;
}

//! Utility function to convert a degrees value to radians
/** Provided as it can be clearer to write degToRad(X) than DEGTORAD * X
\param degrees	The degrees value to convert to radians.
*/
float degToRad(float degrees)
{
	return DEGTORAD * degrees;
}

//! Utility function to convert a degrees value to radians
/** Provided as it can be clearer to write degToRad(X) than DEGTORAD * X
\param degrees	The degrees value to convert to radians.
*/
double degToRad(double degrees)
{
	return DEGTORAD64 * degrees;
}

float round32( float x )
{
	return floor( x + 0.5f );
}

double clamp (double value, double low, double high)
{
	return min(max(value,low), high);
}

int clamp (int value, int low, int high)
{
	return min(max(value,low), high);
}

//! returns if a equals b, taking possible rounding errors into account
bool equals(const double a, const double b, const double tolerance = ROUNDING_ERROR_f64)
{
	return (a + tolerance >= b) && (a - tolerance <= b);
}

//! returns if a equals b, taking possible rounding errors into account
bool equals(const float a, const float b, const float tolerance = ROUNDING_ERROR_f32)
{
	return (a + tolerance >= b) && (a - tolerance <= b);
}

//! returns if a equals b, taking an explicit rounding tolerance into account
bool equals(const int a, const int b, const int tolerance = ROUNDING_ERROR_S32)
{
	return (a + tolerance >= b) && (a - tolerance <= b);
}

//! returns if a equals zero, taking rounding errors into account
bool iszero(const double a, const double tolerance = ROUNDING_ERROR_f64)
{
	return fabs(a) <= tolerance;
}

//! returns if a equals zero, taking rounding errors into account
bool iszero(const float a, const float tolerance = ROUNDING_ERROR_f32)
{
	return fabs(a) <= tolerance;
}

//! returns if a equals not zero, taking rounding errors into account
bool isnotzero(const float a, const float tolerance = ROUNDING_ERROR_f32)
{
	return fabs(a) > tolerance;
}

//! returns if a equals zero, taking rounding errors into account
bool iszero(const int a, const int tolerance = 0)
{
	return ( a & 0x7ffffff ) <= tolerance;
}

//! returns if a equals zero, taking rounding errors into account
bool iszero(const uint a, const uint tolerance = 0)
{
	return a <= tolerance;
}

union inttofloat { uint u; int s; float f; };

uint IR(float x) {inttofloat tmp; tmp.f=x; return tmp.u;}
float FR(int x) {inttofloat tmp; tmp.u=x; return tmp.f;}

bool F32_LOWER_0(float n)			{ return ((n) <  0.0f); }
bool F32_LOWER_EQUAL_0(float n)		{ return ((n) <= 0.0f); }
bool F32_GREATER_0(float n)			{ return ((n) >  0.0f); }
bool F32_GREATER_EQUAL_0(float n)	{ return ((n) >= 0.0f); }
bool F32_EQUAL_1(float n)			{ return ((n) == 1.0f); }
bool F32_EQUAL_0(float n)			{ return  ((n) == 0.0f); }
bool F32_A_GREATER_B(float a,float b)	{ return  ((a) > (b)); }

float reciprocal( float f )
{
	return 1.0 / f;
}

void clearFPUException ()
{
	asm
	{
		fnclex;
	}
}

int s32_min(int a, int b)
{
	const int mask = (a - b) >> 31;
	return (a & mask) | (b & ~mask);
}

int s32_max(int a, int b)
{
	const int mask = (a - b) >> 31;
	return (b & mask) | (a & ~mask);
}

int s32_clamp (int value, int low, int high)
{
	return s32_min(s32_max(value,low), high);
}

// integer log2 of a float ieee 754. TO_DO: non ieee floating point
static int s32_log2_f32( float f)
{
	uint x = IR ( f );
	return ((x & 0x7F800000) >> 23) - 127;
}

static int s32_log2_s32(uint x)
{
	return s32_log2_f32( cast(float) x);
}

//! conditional set based on mask and arithmetic shift
uint if_c_a_else_b ( const uint condition, const uint a, const uint b )
{
	return ( ( -condition >> 31 ) & ( a ^ b ) ) ^ b;
}

float fract ( float x )
{
	return x - floor ( x );
}

