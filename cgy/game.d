import std.stdio;

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
	bool			keyMap[256];	
	
	this(bool serv, bool clie, bool work){
		isServer = serv;
		isClient = clie;
		isWorker = work;
		world = new World();
		if(isClient){        
			SIrrlichtCreationParameters sex = new SIrrlichtCreationParameters();
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
        while(device.run()){
            if(keyMap[EKEY_CODE.KEY_KEY_W]){
                camera.axisMove( 0.1, 0.0, 0.0);
            }
            if(keyMap[EKEY_CODE.KEY_KEY_S]){
                camera.axisMove(-0.1, 0.0, 0.0);
            }
            if(keyMap[EKEY_CODE.KEY_KEY_A]){
                camera.axisMove( 0.0,-0.1, 0.0);
            }
            if(keyMap[EKEY_CODE.KEY_KEY_D]){
                camera.axisMove( 0.0, 0.1, 0.0);
            }
            if(keyMap[EKEY_CODE.KEY_SPACE]){
                camera.axisMove( 0.1, 0.0, 0.1);
            }
            if(keyMap[EKEY_CODE.KEY_LCONTROL]){
                camera.axisMove( 0.1, 0.0, 0.1);
            }
            device.getVideoDriver().beginScene();
            renderer.render(camera);
            device.getVideoDriver().endScene();
        }		
	}
    
    bool onKey(const SEvent.SKeyInput event){        
        keyMap[event.Key] = event.PressedDown;        
        return false;
    }
    
    bool onMouse(const SEvent.SMouseInput event){
        if(event.Event == EMOUSE_INPUT_EVENT.EMIE_MOUSE_MOVED){
            auto wndDim = device.getVideoDriver().getScreenSize();
            auto ScreenCenterX = wndDim.Width / 2;
            auto ScreenCenterY = wndDim.Height/ 2;   // <-- luben's settings. yeah.
            int dx, dy;
            dx = event.X - ScreenCenterX;
            dy = event.Y - ScreenCenterY;
            if(dx!=0 || dy!=0){
                device.getCursorControl().setPosition(ScreenCenterX, ScreenCenterY);
                camera.mouseMove( dx,  dy);
            }
        }        
        return false;
    }
    
	bool OnEvent(const SEvent event){
        switch(event.EventType){
            case EEVENT_TYPE.EET_KEY_INPUT_EVENT:
                return onKey(event.KeyInput);
            case EEVENT_TYPE.EET_MOUSE_INPUT_EVENT:
                return onMouse(event.MouseInput);
            default:
        }
        return false;
    }
    
}
