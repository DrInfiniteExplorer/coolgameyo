module commands;

import std.array : split;
import std.conv : to;


import changes.worldproxy : WorldProxy;
import clans : Clans;
import game : game;
import globals : g_worldPath;
import math.vector;
import playerinformation : PlayerInformation;
import unit;
import unittypemanager : unitTypeManager;
import util.pos;
import util.filesystem : exists;
import util.socket : sendString;
import util.util : BREAKPOINT, BREAK_IF;
import worldstate.worldstate : WorldState;

final class Commands {

    alias void delegate(PlayerInformation player, WorldProxy, string, string[]) CommandHandler;
    CommandHandler[string] registeredCommands;


    WorldProxy commandProxy;

    this(WorldState worldState) {
        commandProxy = new WorldProxy(worldState);
        addCommand("ProperlyConnected", &properlyConnected);
        addCommand("PlayerMove", &playerMove);
        addCommand("DamageTile", &damageTile);
    }

    void addCommand(string command, CommandHandler handler) {
        registeredCommands[command] = handler;
    }

    void handleCommand(PlayerInformation player, string line) {
        auto words = line.split();
        auto command = words[0];
        if(command in registeredCommands) {
            registeredCommands[command](player, commandProxy, line, words);
        }
    }

    void properlyConnected(PlayerInformation player, WorldProxy proxy, string line, string[] words) {
        auto path = g_worldPath ~ "/players/" ~ player.name ~ ".json";
        //If has unit, send unit-id to be controlled
        if(exists(path)) {
            BREAKPOINT;
        } else {
            //Else add unit & send unit-id to be controlled.
            //For now just ignore unit creation and assume control of unit 0

            auto unit = newUnit();
            auto unitPos = game.topOfTheWorld(game.spawnPoint.TileXYPos);
            unit.pos = unitPos;
            unit.type = unitTypeManager.byName("dwarf");
            unit.clan = Clans().getClanById(1);
            proxy.createUnit(unit);

            player.unitId = unit.id;
            player.unit = unit;
            player.commSock.sendString("controlUnit:" ~ player.unitId.to!string);
        }
        /*
        string playerName = words[1];
        float x = to!float(words[2]);
        float y = to!float(words[3]);
        float z = to!float(words[4]);
        auto player = game.players[playerName];
        proxy.moveUnit(player.unit, vec3d(x,y,z).UnitPos, 1);
        */
    }

    void playerMove(PlayerInformation player, WorldProxy proxy, string line, string[] words) {
        string playerName = words[1];
        float x = to!float(words[2]);
        float y = to!float(words[3]);
        float z = to!float(words[4]);
        auto playerr = game.players[playerName];
        BREAK_IF(playerr !is player);
        proxy.moveUnit(player.unit, vec3d(x,y,z).UnitPos, 1);
    }
    void damageTile(PlayerInformation player, WorldProxy proxy, string line, string[] words) {
        int x = to!int(words[1]);
        int y = to!int(words[2]);
        int z = to!int(words[3]);
        int damage = to!int(words[4]);
        proxy.damageTile(vec3i(x,y,z).TilePos, damage);
    }

}




