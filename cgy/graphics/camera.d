module graphics.camera;

import std.algorithm;
import std.conv;
import std.math : PI;
import std.stdio;

import stolen.all;
import math.math;
import math.quat;

import settings;
import util.util;


class Camera{
    vec3d position = vec3d(0);
    quatd viewQuat = quatd(1, 0, 0, 0);
    float pitch = 0;
    vec3d targetDir = vec3d(0, 1, 0);

    matrix4 getProjectionMatrix(float Near = -1.0f, float Far = -1.0f){
        float FOV_Radians = degToRad(cast(float)renderSettings.fieldOfView);
        float aspect = renderSettings.aspectRatio;
        float _near = renderSettings.nearPlane;
        float _far = renderSettings.farPlane;
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
        vec3d right = targetDir.crossProduct(_up).normalize();
        vec3d up = right.crossProduct(targetDir).normalize();
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
        dir = (UL + percentX*toRight + percentY * toDown).normalize();   
        //dir = (targetDir + leftmost + upper).normalize();   
        //msg(percentX, " ", percentY);
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
        targetDir = dir.normalize();
        auto xyLen = sqrt(dir.x^^2 + dir.y^^2);
        pitch = atan2(dir.z, xyLen);
        auto rot = atan2(dir.y, dir.x);
        viewQuat = quatd.rotationQuat(pitch, 1, 0, 0);
        viewQuat = viewQuat * quatd.rotationQuat(rot, 0, 0, 1);
    }
    void setTarget(vec3d target){
        setTargetDir((target-position).normalize());
    }
    vec3d getTargetDir() const {
        return targetDir;
    }

    const double PI2 = PI*2.0;
    void mouseMove(int dx, int dy){
        //matrix4 mat;
        double degZ; //Degrees rotation around Z-axis(up).
        double degX; //Degrees rotation around X-axis(left->right-axis)
        degZ = -dx * controlSettings.mouseSensitivityX;
        degX = -dy * controlSettings.mouseSensitivityY;

        auto rotQuat = quaternion!double.rotationQuat(degZ * DegToRad, 0, 0, 1);

        degX *= DegToRad;
        if(pitch + degX + 0.05 > PI_2) {
            degX = PI_2 - pitch - 0.05;
        }
        if(pitch + degX - 0.05 < -PI_2) {
            degX = -PI_2 - pitch + 0.05;
        }
        pitch += degX;

        auto pitchQuat = quaternion!double.rotationQuat(degX, 1, 0, 0);

        //auto rot = pitchQuat * rotQuat;
        //targetDir = rot.rotate(targetDir);
        //targetDir = rotQuat.rotate(targetDir);
        //targetDir = pitchQuat.rotateDerp(targetDir);
        viewQuat = rotQuat * viewQuat * pitchQuat;
        //viewQuat = pitchQuat * viewQuat;
        targetDir = viewQuat.rotate(vec3d(0, 1, 0));


    }

    void axisMove(double right, double forward, double up){
        vec3d _fwd = targetDir.convert!double();
            vec3d _up = vec3d(0.0, 0.0, 1.0);
        vec3d _right = _fwd.crossProduct(_up).normalize();
        vec3d movement = _fwd*forward + _up*up + _right*right;
        position += movement;
    }
}
