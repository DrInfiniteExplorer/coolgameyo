
#include "include.h"
#include "Game.h"
#include "Util.h"

#include "UnitModule.h"

int main()
{
    Util::Test();

    IrrlichtDevice *pDevice = createDevice(EDT_OPENGL); /* Plol har riktig dator nu. Ingen ändrar. */
    /* Dessutom om vi kodar i opengl kan vi dra nytta av OpenCL senare kanske */

    /* Connect to server */
    /* Create world */
    World* world = new World(pDevice->getVideoDriver());

    vec2i xy(20,30);

    auto u = new Unit;
    u->pos = world->getTopTilePos(xy);
    u->pos.Z += 1;

    world->addUnit(u);

    world->floodFillVisibility(xy);

    /* connection to server lies in world? World handles everything, ie
    connection and irrlicht and mainlooping and a list of critters(dwarves etc)
    and all stuff? */

    /* Create dwarf to play if non was assigned by server */
    /* Durr, regarding ^, server should create and always assign a dwarf!!! (or give list to choose from) */

    /* World->SetDudeToControl(pDwarf); */
    /* How to actually handle that? I mean like should one enter DF-style-mode if NULL is passed? */
    /* Camera information like position is handled by world anyway? */






    //BREAKPOINT;

    Game game(pDevice, world, true, true);

    game.run();



    pDevice->drop();

    return 0;
}














