
import engine.irrlicht;
import world;
import camera;
import renderer;
import scheduler;

class Game : IEventReceiver{
	
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
			sex.DriverType = E_DRIVER_TYPE.EDT_OPENGL;
			sex.Bits = 32;
			sex.ZBufferBits = 16; //Or 32? Make settingable?
			sex.Fullscreen = false;
			sex.Vsync = false;
			sex.AntiAlias = sex.Fullscreen ? 8 : 0; //this is FSAA
			sex.HighPrecisionFPU = false; //test false also.
			sex.EventReceiver = this;
			device = createDeviceEx(sex);
			scheduler = new Scheduler(world, 0);
			renderer = new Renderer(world, device.getVideoDriver());
			camera = new Camera();
		}
	}
	~this(){		
	}	
	
	
	void run(){
		
	}
}
