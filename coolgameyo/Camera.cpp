#include "Camera.h"


Camera::Camera(void)
    : m_targetDir(0, 1, 0) //Look into scene.
{
}


Camera::~Camera(void)
{
}

void Camera::getProjectionMatrix(matrix4 &out){
    //TODO: Rethink camera class. Build projection, view matrix not very often. Make own view matrix, keep local up/right/fwd?
    const f32 FOV_Radians = degToRad(90.f);
    const f32 aspect = 4.0f/3.0f;
    const f32 _near = 0.5f;
    const f32 _far = 1000.0f;
    out.buildProjectionMatrixPerspectiveFovRH(FOV_Radians, aspect, _near, _far);
}

void Camera::getViewMatrix(matrix4 &out){
    //TODO: Rework this. At laaarge distances from origin, floats will not do;
    //Will have to do remove the integer part of the position from the variable passed here,
    //and move blocks with that amount before sending them to ogl.
    out.buildCameraLookAtMatrixRH(convert<f32,f64>(m_position), convert<f32,f64>(m_position)+m_targetDir, vec3f(0.0f, 0.0f, 1.0f)); 
}

vec3d Camera::getPosition() const
{
    return m_position;
}

void Camera::setPosition(const vec3d position){
    m_position = position;
}


void Camera::setTargetDir(const vec3f dir){
    m_targetDir = dir;
}

void Camera::setTarget(const vec3d target){
    m_targetDir = convert<float, double>((target-m_position)).normalize();
}

const f64 PI2 = PI64*2.0;
void Camera::mouseMove(s16 dx, s16 dy){
    matrix4 mat;
    f32 degZ; //Degrees rotation around Z-axis(up).
    f32 degX; //Degrees rotation around X-axis(left->right-axis)
    degZ = dx;
    degX = dy;

    //vec3f tmp(m_targetDir.X, m_targetDir.Z, m_targetDir.Y);
    core::swap(m_targetDir.Y, m_targetDir.Z);
    vec3f tmpRot = m_targetDir.getHorizontalAngle();

//    tmpRot.X = clamp(tmpRot.X, -89.0f, 89.0f);
    tmpRot.X+=degX;
    tmpRot.Y+=degZ;
    //TODO: Fix so that tmpRot.X € [85, 0]u[275,360]
    mat.setRotationDegrees(tmpRot);
    mat.transformVect(m_targetDir, vec3f(0.0f, 0.0f, 1.0f));
    core::swap(m_targetDir.Y, m_targetDir.Z);
    m_targetDir.normalize();


/*
    m_targetDir.rotateYZBy(degX);
    m_targetDir.Z = core::clamp(m_targetDir.Z, -0.95f, 0.95f);
    m_targetDir.normalize();
    m_targetDir.rotateXYBy(degZ);
    m_targetDir.normalize();
*/
/*
    matrix4 mat;
    mat.setRotationDegrees(vec3f(degX, 0.f, degZ));
    mat.transformVect(m_targetDir);
    m_targetDir.normalize();
*/
/*
    quaternion q;
    vec3f roted;
    roted.Z = sin(degX*0.01f);
    roted.X = sin(degZ*0.01f);
    roted.Y = cos(degZ*0.01f);

    float len = sqrt(1-roted.Z*roted.Z);
    roted.X *= len;
    roted.Y *= len;

    q.rotationFromTo(vec3f(0.0f, 1.0f, 0.0f), roted);

    m_targetDir = q*m_targetDir;
*/

}

void Camera::axisMove(f32 forward, f32 right, f32 up){
    vec3f _fwd = m_targetDir;
    vec3f _up(0.0f, 0.0f, 1.0f);
    vec3f _right = _fwd.crossProduct(_up);
    vec3f movement = _fwd*forward + _up*up + _right*right;
    m_position += convert<f64, f32>(movement);
}



