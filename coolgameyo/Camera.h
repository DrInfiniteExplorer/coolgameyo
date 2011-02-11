#pragma once

#include "include.h"

class Camera
{
private:
    vec3d m_position;
    vec3f m_targetDir;

public:
    Camera(void);
    ~Camera(void);

    void getProjectionMatrix(matrix4 &out);
    void getViewMatrix(matrix4 &out);

    vec3d getPosition() const;
    void setPosition(const vec3d position);

    /*  Set direction to look in. Not absolute position, just a direction vector.  */
    void setTargetDir(const vec3f dir);
    void setTarget(const vec3d target);

    /*  Makes a first-person-looking-like movement  */
    void mouseMove(s16 dx, s16 dy);
    void axisMove(f32 forward, f32 right, f32 up);
};

