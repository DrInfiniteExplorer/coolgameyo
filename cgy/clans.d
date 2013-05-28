module clans;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import clan;
import json;
import game;
import modules.module_;
import util.singleton;
import worldstate.worldstate;

final class Clans : Module {

    mixin Singleton!();

    private Clan[] clans;
    WorldState worldState;

    void init(WorldState _worldState) {
        worldState = _worldState;
    }

    auto getClans() {
        return clans;
    }

    override void update(WorldState world) {
        foreach(clan ; clans) {
            clan.update(world);
        }
    }

    override void serializeModule() {}
    override void deserializeModule() {}


    void addClan(Clan clan)
    in{
        foreach(c ; clans) {
            assert(c != clan, "Trying to add a clan which is already part of thw world");
        }
    }
    body{
        clans ~= clan;
        worldState.addListener(clan);
    }

    void serializeClans() {

        util.filesystem.mkdir(g_worldPath ~ "/world/clans/");

        auto clanList = encode(array(map!q{a.clanId}(clans)));
        auto jsonRoot = Value([
            "clanList" : clanList,
        ]);
        auto jsonString = json.prettifyJSON(jsonRoot);

        std.file.write(g_worldPath ~ "/world/clans/clans.json", jsonString);

        foreach(clan ; clans) {
            clan.serialize();
        }
    }

    void deserializeClans() {
        import gaia;
        int[] clanList;
        loadJSON(g_worldPath ~ "/world/clans/clans.json").
            readJSONObject("clanList", &clanList);

        foreach(clanId ; clanList) {
            Clan clan = Gaia();
            if(clanId) {
                clan = new NormalClan();
                clan.init(worldState);
            }
            clan.deserialize(clanId);
        }
    }

    Clan getClanById(int clanId) {
        foreach(clan ; clans) {
            if(clan.clanId == clanId) return clan;
        }
        enforce(false, "Could not find clan with specified id: " ~ to!string(clanId));
        return null;
    }

    Unit getUnitById(int unitId) {
        foreach(clan ; clans) {
            auto unit = clan.getUnitById(unitId);
            if(unit !is null) {
                return unit;
            }
        }
        return null;
    }





}
