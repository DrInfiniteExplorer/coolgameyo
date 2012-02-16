module graphics.camera;

import std.algorithm;
import std.conv;
import std.stdio;

import stolen.all;

import settings;
import util.util;

alias util.util.convert convert;

class Camera{
    vec3d position;
    vec3d targetDir;

    this(){
        position.set(0,-1,0);
        targetDir.set(0, 1, 0); //Look into scene
    }

    matrix4 getProjectionMatrix(){
        float FOV_Radians = degToRad(cast(float)renderSettings.fieldOfView);
        float aspect = renderSettings.aspectRatio;
        float _near = renderSettings.nearPlane;
        float _far = renderSettings.farPlane;
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
        double percentX = to!double(coords.X) / to!double(renderSettings.windowWidth);
        double percentY = to!double(coords.Y) / to!double(renderSettings.windowHeight);
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
            convert!float(position),
            convert!float(position+targetDir),
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
    }
    void setTarget(vec3d target){
        targetDir = (target-position).normalize();
    }
    vec3d getTargetDir() const {
        return targetDir;
    }

    const double PI2 = PI64*2.0;
    void mouseMove(int dx, int dy){
        matrix4 mat;
        double degZ; //Degrees rotation around Z-axis(up).
        double degX; //Degrees rotation around X-axis(left->right-axis)
        degZ = dx * controlSettings.mouseSensitivityX;
        degX = dy * controlSettings.mouseSensitivityY;

        swap(targetDir.Y, targetDir.Z);
        auto temp = convert!float(targetDir);
        vec3f tmpRot = temp.getHorizontalAngle();

        tmpRot.X+=degX;
        tmpRot.Y+=degZ;
		if(tmpRot.X > 180){
			tmpRot.X -= 360;
		}
		if (tmpRot.X >= 89.0f) tmpRot.X = 89.0f;
		else if (tmpRot.X <= -89.0f) tmpRot.X = -89.0f;
        
        mat.setRotationDegrees(tmpRot);
        mat.transformVect(temp, vec3f(0.0f, 0.0f, 1.0f));
        targetDir = convert!double(temp);
        swap(targetDir.Y, targetDir.Z);
        targetDir.normalize();
    }

    void axisMove(double right, double forward, double up){
        vec3d _fwd = convert!double(targetDir);
            vec3d _up = vec3d(0.0, 0.0, 1.0);
        vec3d _right = _fwd.crossProduct(_up).normalize();
        vec3d movement = _fwd*forward + _up*up + _right*right;
        position += movement;
    }
}
