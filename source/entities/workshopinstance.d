module entities.workshop;

import entities.entity;
import entitytypemanager;
import cgy.util.pos;



class WorkshopInstance {
    Entity[] input;  // Ska dessa vara Entity[] lr nagot annat (typ en stockpile)?
	Entity[] output;
	RecipyType currentRecipy;
	int ticksBuilt;
	Entity* parent;

	this(Entity* _parent)
	{
		parent = _parent;
	}

	public void Build()
	{
	}

	public void AddToInput(Entity entity)
	{
	}

	public Entity TakeFromOutput(string id, int quantity)
	{
		return null;
	}

	public TilePos GetInputPos()
	{
		return parent.pos.tilePos();
	}

	public TilePos GetOutputPos()
	{
		return parent.pos.tilePos();
	}

	public TilePos GetWorkPos()
	{
		return parent.pos.tilePos();
	}
}
