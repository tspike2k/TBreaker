// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module math;

public {
    import core.math : fabs, cos;
    import std.math : floor, abs, sgn, ceil, sqrt, signbit;
}

private {
    import logging : toPrint;
}

alias sign  = sgn;
alias signf = sgn;

// 
// Types
//

@nogc nothrow:

alias Vect2 = Vect!2;
alias Vect3 = Vect!3;
alias Vect4 = Vect!4;

union Vect(uint length)
if (length >= 2 && length <= 4)
{
    @toPrint struct
    {
        float x = 0.0f;
        float y = 0.0f;
        static if(length >= 3)
        {
            float z = 0.0f;
        }
        static if(length >= 4)
        {
            float w = 0.0f;
        }
    };

    static if (length >= 3)
    {
        struct
        {
            float r; float g; float b;
            static if (length >= 4)
            {
                float a;
            }
        };
    }
    
    struct {float s; float t;};
    struct {float u; float v;};
    float[length] c;
    
    // TODO: Implement the following operation?
    // Vect2 operator-(const Vect2 a);
    
    Vect opBinary(string op)(Vect rhs)
    {
        Vect result = void;
        static if (op == "+")
        {
            static foreach(i; 0 .. c.length)
            {
                result.c[i] = c[i] + rhs.c[i];
            }
        }
        else static if (op == "-")
        {
            static foreach(i; 0 .. c.length)
            {
                result.c[i] = c[i] - rhs.c[i];
            }
        }
        else static assert(0);
        return result;
    }
    
    Vect opBinary(string op)(float rhs)
    {
        Vect result = void;
        static if (op == "*")
        {
            static foreach(i; 0 .. c.length)
            {
                result.c[i] = c[i] * rhs;
            }
        }
        else static assert(0);
        return result;
    }
    
    void opOpAssign(string op)(float rhs)
    {
        static if(op == "*")
        {
            static foreach(i; 0 .. c.length)
            {
                c[i] *= rhs;
            }
        }
        else static assert(0);
    }
    
    void opOpAssign(string op)(Vect rhs)
    {
        static if(op == "+")
        {
            static foreach(i; 0 .. c.length)
            {
                c[i] += rhs.c[i];
            }
        }
        else if(op == "-")
        {
            static foreach(i; 0 .. c.length)
            {
                c[i] -= rhs.c[i];
            }
        }
        else static assert(0);
    }
    
    auto opBinaryRight(string op, T)(T inp)
    {
        return this.opBinary!(op)(inp);
    }
}

struct Mat4
{
    float[16] c;
    
    alias c this;
};

struct Rect
{
    float x = 0.0f, y = 0.0f, w = 0.0f, h = 0.0f;
};

//
// Utility function
//

pragma(inline, true) T min(T)(T a, T b) {return a < b ? a : b;}
pragma(inline, true) T max(T)(T a, T b) {return a > b ? a : b;}
pragma(inline, true) T clamp(T)(T a, T min, T max) {return a < min ? min : (a > max ? max : a);}

/*
pragma(inline, true) T abs(T)(T a, T b)
if (!is(T == float) && !is(T == double))
{
    return a * ((a > 0) - (a < 0));
}*/

// 
// Misc math operations
//

float lerp(float start, float end, float t)
{
    float result = (end * t) + (start * (1.0f - t));
    return result;
}

Vect2 normalizeSafe(Vect2 v)
{
    // TODO(tspike): Make an intrinsics.h file to wrap around this!
    float magnitude = sqrt(v.x * v.x + v.y * v.y);
        
    // TODO(tspike): Is there a way to do this without branches?
    Vect2 result = Vect2(0.0f, 0.0f);
    if (v.x != 0.0f) result.x = v.x / magnitude;
    if (v.y != 0.0f) result.y = v.y / magnitude;
    
    return result;
}

Vect2 normalizeUnsafe(Vect2 v)
{
    assert(v.x != 0.0f);
    assert(v.y != 0.0f);
    
    // TODO(tspike): Make an intrinsics.h file to wrap around this!
    float magnitude = sqrt(v.x * v.x + v.y * v.y);
    
    Vect2 result = void;
    result.x = v.x / magnitude;
    result.y = v.y / magnitude;    
    
    return result;
}

float dotProduct(Vect2 a, Vect2 b)
{
    return a.x * b.x + a.y * b.y;
}

float distanceBetween(Vect2 a, Vect2 b)
{
    Vect2 diff;
    
    diff = a - b;
    // TODO(tspike): Make an intrinsics.h file to wrap around this!
    return sqrt(diff.x * diff.x + diff.y * diff.y);
}

bool isPowerOfTwo(int n)
{
    bool result = (n > 0 && (n & (n - 1)) == 0);
    return result;
}

bool circlesOverlap(Vect2 centerA, float radiusA, Vect2 centerB, float radiusB)
{
    Vect2 diff = centerB - centerA;                            
    if(dotProduct(diff, diff) <= (radiusA + radiusB) * (radiusA + radiusB))
    {
        return true;
    }
    
    return false;
}

float distanceSquared(Vect2 a, Vect2 b)
{
    Vect2 diff = b - a;
    return diff.x*diff.x + diff.y*diff.y;
}

bool pointInsideRect(Vect2 p, Rect r)
{
    return p.x >= r.x && p.x <= r.x + r.w &&
        p.y >= r.y && p.y <= r.y + r.h;
}

bool rectsOverlap(Rect a, Rect b)
{
    return !(
        a.x + a.w <= b.x
        || a.x >= b.x + b.w
        || a.y >= b.y + b.h
        || a.y + a.h <= b.y
    );
}

Vect2 calcIntersection(Vect2 s1, Vect2 e1, Vect2 s2, Vect2 e2)
{
    // Source:
    // http://rosettacode.org/wiki/Find_the_intersection_of_two_lines#C.23
    float a1 = e1.y - s1.y;
    float b1 = s1.x - e1.x;
    float c1 = a1 * s1.x + b1 * s1.y;

    float a2 = e2.y - s2.y;
    float b2 = s2.x - e2.x;
    float c2 = a2 * s2.x + b2 * s2.y;

    float delta = a1 * b2 - a2 * b1;
    //If lines are parallel, the result will be (NaN, NaN).
    if (delta == 0.0f)
    {
        return Vect2(float.nan, float.nan);
    }   

    return Vect2((b2 * c1 - b1 * c2) / delta, (a1 * c2 - a2 * c1) / delta);
}