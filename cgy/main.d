module main;

import std.stdio;
//import engine.irrlicht;

import game;
import util;


int main(string[] argv)
{
    Game game = new Game(true, true, true);
    game.run();

	return 0;
}
