#pragma once

#include <map>
#include <vector>
#include <assert.h>

#include "os.h"

using namespace irr;
using namespace irr::core;
using namespace irr::scene;
using namespace irr::video;


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
inline A GetFlag(A &val, B flag) {
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
