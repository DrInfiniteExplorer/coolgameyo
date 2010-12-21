
#include "include.h"
#include "Game.h"

int main() {


    IrrlichtDevice *pDevice = createDevice(EDT_SOFTWARE);

    /* Connect to server */
    /* Create world */

    /* connection to server lies in world? World handles everything, ie
    connection and irrlicht and mainlooping and a list of critters(dwarves etc)
    and all stuff? */

    /* Create dwarf to play if non was assigned by server */
    /* Durr, regarding ^, server should create and always assign a dwarf!!! (or give list to choose from) */

    /* World->SetDudeToControl(pDwarf); */
    /* How to actually handle that? I mean like should one enter DF-style-mode if NULL is passed? */
    /* Camera information like position is handled by world anyway? */

    Game game(pDevice, true, true);

    game.run();



    pDevice->drop();

    return 0;
}














