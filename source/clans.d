module clans;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import clan;
import game;
import modules.module_;
import cgy.util.singleton;
import cgy.util.json;
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

        cgy.util.filesystem.mkdir(g_worldPath ~ "/world/clans/");

        auto clanList = array(map!q{a.clanId}(clans)).toJSON;
        auto jsonRoot = JSONValue([
            "clanList" : clanList,
        ]);
        auto jsonString = jsonRoot.toString;

        std.file.write(g_worldPath ~ "/world/clans/clans.json", jsonString);

        foreach(clan ; clans) {
            clan.serialize();
        }
    }

    void deserializeClans() {
        import gaia;
        int[] clanList;
        loadJSON(g_worldPath ~ "/world/clans/clans.json")["clanList"].unJSON(clanList);

        foreach(clanId ; clanList) {
            Clan clan = Gaia();
            if(clanId) {
                clan = new NormalClan(clanId);
                clan.init(worldState);
            }
            clan.deserialize();
        }
    }

    Clan getClanById(int clanId) {
        foreach(clan ; clans) {
            if(clan.clanId == clanId) return clan;
        }
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

    Entity getEntityById(int entityId) {
        foreach(clan ; clans) {
            auto entity = clan.getEntityById(entityId);
            if(entity !is null) {
                return entity;
            }
        }
        return null;
    }





}
