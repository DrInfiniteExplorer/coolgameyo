module treemanager;

import std.exception;
import std.stdio;
import std.random;
import std.conv;
import std.math;
import std.array;

import entities.entity;
import entities.treelikeinstance;
import entitytypemanager;

import graphics.debugging;

import stolen.aabbox3d;

import util.math;
import util.singleton;
import util.util;

import worldstate.worldstate;
import worldstate.sector;
import worldstate.block;


import tiletypemanager;

class TreeManager {


    mixin Singleton!();
    private this() {}

    WorldState world;

    int debugIdCounter = 0;
    bool drawDebugLines = true;
    bool drawTiles = true;
    bool drawLeafs = true;
    bool[10] drawBranchId;

	void init(WorldState w)
    {
		world = w;
        for (int i = 0; i < 10; i++) {
            drawBranchId[i] = true;
        }
	}


}


