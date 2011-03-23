
import engine.irrlicht;

import world;
import camera;
import vbomaker;

class Renderer{
	World world;	
	IVideoDriver driver;
    VBOMaker vboMaker;
		
	uint texture2D;
	uint textureAtlas;
	float oglVersion;
		
	this(World w, IVideoDriver d)
	{
		world = w;
		driver = d;
		
		
		
	}
	~this()
	{
	}
		
	void render(Camera camera)
	{        
		//Render world
		renderWorld(camera);
		//Render dudes
		//Render foilage and other cosmetics
		//Render HUD/GUI
		//Render some stuff deliberately offscreen, just to be awesome.
		
	}
	
	void renderWorld(Camera camera)
	{
//		auto vboList = vboMaker.getVBOs();
		
        //Get list of vbo's
        //Do culling
        //Render vbo's.
        
	}
}

