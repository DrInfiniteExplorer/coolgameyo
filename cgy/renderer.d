
import World;
import engine.irrlicht;

class Renderer{
	World world;	
	IVideoDriver driver;
	
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
}

