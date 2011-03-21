
import engine.irrlicht;

import world;
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
		
	void render()
	{
		//Render world
		renderWorld();
		//Render dudes
		//Render foilage and other cosmetics
		//Render HUD/GUI
		//Render some stuff deliberately offscreen, just to be awesome.
		
	}
	
	void renderWorld()
	{
//		auto vboList = vboMaker.getVBOs();
		
	}
}

