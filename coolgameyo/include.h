
#include "os.h"

#include <map>

using namespace irr;
using namespace irr::core;
using namespace irr::scene;
using namespace irr::video;


typedef vector3df fVec3;
typedef vector3di iVec3;
typedef vector2di iVec2;

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
