module graphics.camera;

import std.algorithm;
import std.conv;
import std.math : PI;
import std.stdio;

import cgy.stolen.all;
import cgy.math.math;
import cgy.math.quat;

import settings;
import cgy.util.util;


class Camera{
    vec3d position = vec3d(0);
    quatd viewQuat = quatd(1, 0, 0, 0);
    float pitch = 0;
    vec3d targetDir = vec3d(0, 1, 0);

    float farPlane;
    float nearPlane;
    float speed = 1.0;
    bool mouseMoveEnabled = true;
    bool printPosition = false;

    this() {
        farPlane = renderSettings.farPlane;
        nearPlane = renderSettings.nearPlane;
    }

    matrix4 getProjectionMatrix(float Near = -1.0f, float Far = -1.0f){
        float FOV_Radians = degToRad(cast(float)renderSettings.fieldOfView);
        float aspect = renderSettings.aspectRatio;
        float _near = nearPlane;
        float _far = farPlane;
        if(Near != -1.0f) {
            _near = Near;
        }
        if(Far != -1.0f) {
            _far = Far;
        }
        matrix4 proj;
        proj.buildProjectionMatrixPerspectiveFovRH(FOV_Radians, aspect, _near, _far);
        return proj;
    }

    void getRayParameters(ref vec3d UpperLeft, ref vec3d _toRight, ref vec3d _toDown){
        immutable vec3d _up = vec3d(0.0f, 0.0f, 1.0f);
        vec3d right = targetDir.crossProduct(_up).normalizeThis();
        vec3d up = right.crossProduct(targetDir).normalizeThis();
        auto dX = tan(degToRad(renderSettings.fieldOfView * 0.5f));
        auto leftmost = right * -dX;
        auto toRight = 2.0f * dX * right;
        auto dY =  dX / renderSettings.aspectRatio; //width / (width/height)
        auto upper = up * dY;
        auto toDown = -2.0f * dY * up;

        UpperLeft = targetDir + leftmost + upper;
        _toRight = toRight;
        _toDown = toDown;
    }
    
    void getRayFromScreenCoords(vec2i coords, ref vec3d start, ref vec3d dir){
        vec3d UL, toRight, toDown;
        getRayParameters(UL, toRight, toDown);
        double percentX = to!double(coords.x) / to!double(renderSettings.windowWidth);
        double percentY = to!double(coords.y) / to!double(renderSettings.windowHeight);
        dir = (UL + percentX*toRight + percentY * toDown).normalizeThis();
        start = position;
    }
    

    matrix4 getViewMatrix(){
        //TODO: Rework this. At laaarge distances from origin, floats will not do;
        //Will have to do remove the integer part of the position from the variable passed here,
        //and move blocks with that amount before sending them to ogl.
        matrix4 view;
        view.buildCameraLookAtMatrixRH(
                                       position.convert!float(),
                                       (position+targetDir).convert!float(),
                                       vec3f(0.0f, 0.0f, 1.0f)
                                       );
        return view;
    }

    matrix4 getTargetMatrix(){
        matrix4 view;
        view.buildCameraLookAtMatrixRH(
                                       vec3f(0.0f, 0.0f, 0.0f),
                                       targetDir.convert!float(),
                                       vec3f(0.0f, 0.0f, 1.0f)
                                       );
        return view;
    }


    //Implement yaaargh
    bool inFrustum(T)(T t){
        return true;
    }

    vec3d getPosition(){
        return position;
    }
    void setPosition(vec3d pos){
        position = pos;
    }

    void setTargetDir(vec3d dir){
        //dir.set(1,1,1);
        targetDir = dir.normalizeThis();
        auto xyLen = sqrt(dir.x^^2 + dir.y^^2);
        pitch = atan2(dir.z, xyLen);

        auto pitchQuat = quatd.rotationQuat(pitch, 0, -1, 0);
        viewQuat = quatd(1, 0, 0, 0);
        viewQuat = viewQuat * pitchQuat;

        auto rot = atan2(dir.y, dir.x);
        auto rotQuat = quatd.rotationQuat(rot, 0, 0, 1);
        viewQuat = rotQuat * pitchQuat;
        msg(targetDir);
        msg(viewQuat.rotate(vec3d(1, 0, 0)));

        //Does not work perfectly, since it's done as one rotation, messing up stuff sortof like :P
        //viewQuat = quatd.stealRotation(vec3d(0, 1, 0), targetDir);
        if(printPosition) {
            msg("targetDir:", targetDir);
        }
    }
    void setTarget(vec3d target){
        setTargetDir((target-position).normalizeThis());
    }
    vec3d getTargetDir() const {
        return targetDir;
    }

    static immutable double PI2 = PI*2.0;
    void mouseLook(int dx, int dy){
        if(!mouseMoveEnabled) return;

        double degZ; //Degrees rotation around Z-axis(up).
        double degX; //Degrees rotation around X-axis(left->right-axis)
        degZ = -dx * controlSettings.mouseSensitivityX;
        degX = -dy * controlSettings.mouseSensitivityY;

        auto radX = degX * DegToRad;
        auto radZ = degZ * DegToRad;
        if(pitch + radX + 0.05 > PI_2) {
            radX = PI_2 - pitch - 0.05;
        }
        if(pitch + radX - 0.05 < -PI_2) {
            radX = -PI_2 - pitch + 0.05;
        }
        pitch += radX;

        auto rotQuat = quaternion!double.rotationQuat(radZ, 0, 0, 1);
        auto pitchQuat = quaternion!double.rotationQuat(radX, 0, -1, 0);
        viewQuat = rotQuat * viewQuat * pitchQuat;
        targetDir = viewQuat.rotate(vec3d(1, 0, 0));
        if(printPosition) {
            msg("targetDir:", targetDir);
        }
    }

    void rotateAround(float focusDistance, int dx, int dy) {
        auto focusPoint = position + targetDir * focusDistance;
        auto fromFocus = targetDir * -focusDistance;

        mouseLook(dx, dy);
        position = focusPoint - targetDir * focusDistance;
    }

    void relativeAxisMove(double right, double forward, double up){
        vec3d _fwd = targetDir.convert!double();
        vec3d _up = vec3d(0.0, 0.0, 1.0);
        vec3d _right = _fwd.crossProduct(_up).normalizeThis();
        vec3d movement = _fwd*forward + _up*up + _right*right;
        position += movement;
        if(printPosition) {
            msg("position:", position);
        }
    }
    void absoluteAxisMove(double x, double y, double z){
        position += vec3d(x, y, z);
        if(printPosition) {
            msg("position:", position);
        }
    }
}
