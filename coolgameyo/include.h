#pragma once

#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <utility>

//#include <thread>

#include "os.h"

#define assert(X) do { if (!(X)) BREAKPOINT; } while (0)

using namespace irr;
using namespace irr::core;
using namespace irr::scene;
using namespace irr::video;

template <typename A, typename B>
inline vector3d<A> convert(const vector3d<B> in){
    return vector3d<A>(
        (A)in.X,
        (A)in.Y,
        (A)in.Z);
}

typedef vector3d<f64> vec3d;
typedef vector3df vec3f;
typedef vector3di vec3i;
typedef vector2di vec2i;

template <typename A, typename B>
inline void SetFlag(A &val, B flag) {
    val |= flag;
}

template <typename A, typename B>
inline void ClearFlag(A &val, B flag) {
    val &= ~flag;
}

template <typename A, typename B>
inline A GetFlag(A val, B flag) {
    return val & flag;
}

template <typename A, typename B>
inline void SetFlag(A &val, B flag, bool Value) {
    if (Value) {
        SetFlag(val, flag);
    } else {
        ClearFlag(val, flag);
    }
}


#define foreach(it, container) \
    for (auto it = (container).begin(); it != (container).end(); ++it)


// blah llhas