
import engine.irrlicht;
import World;
import Camera;
import Renderer;
import Scheduler;

class Game{
	
	IrrlichtDevice	device;
	World			world;
	Camera			camera;
	Renderer		renderer;
	Scheduler		scheduler;
	bool			isClient;
	bool			isServer;
	bool			isWorker;
	bool			keymap[256];	
	
	this(bool serv, bool clie, bool work){
		isServer = serv;
		isClient = clie;
		isWorker = work;
		world = new World();
		if(isClient){        
			SIrrlichtCreationParameters sex;
			sex.DriverType = EDT_OPENGL;
			sex.Bits = 32;
			sex.ZBufferBits = 16; //Or 32? Make settingable?
			sex.Fullscreen = false;
			sex.Vsync = false;
			sex.AntiAlias = sex.Fullscreen ? 8 : 0; //this is FSAA
			sex.HighPrecisionFPU = false; //test false also.
			sex.EventReceiver = this;
			sex.UsePerformanceTimer = true;
			m_pDevice = createDeviceEx(sex);
			m_sched = new Scheduler(m_pWorld, m_pDevice.getTimer());
			m_pRenderer = new Renderer(m_pWorld, m_pDevice.getVideoDriver());
			m_pCamera = new Camera();
		}
	}
	~this(){		
	}	
	
	
	void run(){
		
	}
}
