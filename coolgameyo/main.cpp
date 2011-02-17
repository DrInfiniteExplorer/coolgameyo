
#include "include.h"
#include "Game.h"
#include "Util.h"

#include "UnitModule.h"

int main()
{
    Util::Test();

    printf("Block: %d\nSector: %d\n", sizeof (Block), sizeof (Sector));

    /* Connect to server */
    /* Create world */
/*
    World* world = new World(pDevice->getVideoDriver());

    vec2i xy(20,30);

    auto u = new Unit;
    u->pos = world->getTopTilePos(xy);
    u->pos.Z += 1;

    world->addUnit(u);

    world->floodFillVisibility(xy);
*/

    /* connection to server lies in world? World handles everything, ie
    connection and irrlicht and mainlooping and a list of critters(dwarves etc)
    and all stuff? */

    /* Create dwarf to play if non was assigned by server */
    /* Durr, regarding ^, server should create and always assign a dwarf!!! (or give list to choose from) */

    /* World->SetDudeToControl(pDwarf); */
    /* How to actually handle that? I mean like should one enter DF-style-mode if NULL is passed? */
    /* Camera information like position is handled by world anyway? */

    Game game(true, true, true);

    game.run();

    return 0;
}














