module main;

import std.stdio;
import engine.irrlicht;
import util;

int main(string[] argv)
{
    Game game(true, true, true);
    game.run();

	return 0;
}
