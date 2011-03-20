
import util;
import engine.irrlicht;

class Camera{
	vec3d position;
	vec3d targetDir;
	
	this(){
		position.set(0,0,0);
		targetDir.set(0, 1, 0); //Look into scene
	}
	
	void getProjectionMatrix(out matrix4 proj){
		const f32 FOV_Radians = degToRad(90.f);
		const f32 aspect = 4.0f/3.0f;
		const f32 _near = 0.5f;
		const f32 _far = 1000.0f;
		proj.buildProjectionMatrixPerspectiveFovRH(FOV_Radians, aspect, _near, _far);		
	}
	
	void getViewMatrix(out matrix4 view){
		//TODO: Rework this. At laaarge distances from origin, floats will not do;
		//Will have to do remove the integer part of the position from the variable passed here,
		//and move blocks with that amount before sending them to ogl.
		view.buildCameraLookAtMatrixRH(convert<f32,f64>(m_position), convert<f32,f64>(m_position)+m_targetDir, vec3f(0.0f, 0.0f, 1.0f)); 
	}
	
	vec3i getPosition(){
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
	
	const double PI2 = PI64*2.0;
	void mouseMove(int dx, int dy){
		matrix4 mat;
		double degZ; //Degrees rotation around Z-axis(up).
		double degX; //Degrees rotation around X-axis(left->right-axis)
		degZ = dx;
		degX = dy;

		swap(targetDir.Y, targetDir.Z);
		vec3d tmpRot = targetDir.getHorizontalAngle();

		tmpRot.X+=degX;
		tmpRot.Y+=degZ;
		//TODO: Fix so that tmpRot.X c [85, 0]u[275,360]
		mat.setRotationDegrees(tmpRot);
		mat.transformVect(targetDir, vec3f(0.0f, 0.0f, 1.0f));
		swap(m_targetDir.Y, m_targetDir.Z);
		targetDir.normalize();
	}

	void axisMove(double forward, double right, double up){
		vec3d _fwd = targetDir;
		vec3d; _up(0.0, 0.0, 1.0);
		vec3d _right = _fwd.crossProduct(_up).normalize();
		vec3d movement = _fwd*forward + _up*up + _right*right;
		position += movement;
	}	
}