module graphics.camera;

import std.algorithm;

import stolen.all;
import util;
alias util.convert convert;

class Camera{
	vec3d position;
	vec3f targetDir;
	
	this(){
		position.set(0,-1,0);
		targetDir.set(0, 1, 0); //Look into scene
	}
	
	matrix4 getProjectionMatrix(){
		const float FOV_Radians = degToRad(90.f);
		const float aspect = 4.0f/3.0f;
		const float _near = 0.5f;
		const float _far = 1000.0f;
        matrix4 proj;
		proj.buildProjectionMatrixPerspectiveFovRH(FOV_Radians, aspect, _near, _far);		
        return proj;
	}
	
	matrix4 getViewMatrix(){
		//TODO: Rework this. At laaarge distances from origin, floats will not do;
		//Will have to do remove the integer part of the position from the variable passed here,
		//and move blocks with that amount before sending them to ogl.
        matrix4 view;
		view.buildCameraLookAtMatrixRH(convert!float(position), convert!float(position)+targetDir, vec3f(0.0f, 0.0f, 1.0f)); 
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
		targetDir = util.convert!float(dir).normalize();
	}
	void setTarget(vec3d target){
		targetDir = util.convert!float(target-position).normalize();
	}
	
	const double PI2 = PI64*2.0;
	void mouseMove(int dx, int dy){
		matrix4 mat;
		double degZ; //Degrees rotation around Z-axis(up).
		double degX; //Degrees rotation around X-axis(left->right-axis)
		degZ = dx;
		degX = dy;

		swap(targetDir.Y, targetDir.Z);
		vec3f tmpRot = targetDir.getHorizontalAngle();

		tmpRot.X+=degX;
		tmpRot.Y+=degZ;
		//TODO: Fix so that tmpRot.X c [85, 0]u[275,360]
		mat.setRotationDegrees(tmpRot);
		mat.transformVect(targetDir, vec3f(0.0f, 0.0f, 1.0f));
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
