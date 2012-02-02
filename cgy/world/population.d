

module world.population;


import world.world;
import clan;


private mixin template WorldPopulationMixin() {

    private Clan[] clans;

    void addClan(Clan clan)
    in{
        foreach(c ; clans) {
            assert(c != clan, "Trying to add a clan which is already part of thw world");
        }
    }
    body{
        clans ~= clan;
    }

    private void serializeClans() {

        util.filesystem.mkdir("saves/current/world/clans/");

        int GetClanId(Clan clan) {
            return clan.clanId;
        }

        //auto clanList = encode(array(map!GetClanId(clans)));
        auto clanList = encode(array(map!q{a.clanId}(clans)));
        auto jsonRoot = Value([
            "clanList" : clanList,
        ]);
        auto jsonString = json.prettifyJSON(jsonRoot);

        std.file.write("saves/current/world/clans/clans.json", jsonString);

        foreach(clan ; clans) {
            clan.serialize();
        }
    }

    private void deserializeClans() {
        auto content = readText("saves/current/world/clans/clans.json");
        auto jsonRoot = json.parse(content);
        int[] clanList;
        json.read(clanList, jsonRoot["clanList"]);

        foreach(clanId ; clanList) {
            auto clan = new Clan(this);
            clan.deserialize(clanId);
        }
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



