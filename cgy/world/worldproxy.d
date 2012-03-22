module world.worldproxy;

import unit;
import entities.entity;
import pos;
import world.world;
import changes.changes;

interface WorldProxy {
    World unsafeGetWorld();

    void setTile(TilePos tp, Tile t);
    void damageTile(TilePos tp, int damage);
    void removeTile(TilePos tp);

    void createUnit(Unit unit);
    void removeUnit(Unit unit);
    void moveUnit(Unit unit, UnitPos pos, uint ticksToArrive);

    void setIntent(Unit unit, string id, string intent);
    void setAction(Unit unit, string id, string intent);

    void createEntity(Entity e);
    void removeEntity(Entity e);

    void moveEntity(Entity e, EntityPos pos);
    void pickupEntity(Entity e, Unit u);
    void depositEntity(Entity e, Unit u, Entity target);
    void activateEntity(Unit u, Entity e);

    void addCustomChange(CustomChange c);

    Tile getTile(TilePos tp);
}
