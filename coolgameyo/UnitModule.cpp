#include "UnitModule.h"

#include "Util.h"



UnitModule::UnitModule(World* world)
    : Module(world)
{
}

void UnitModule::tick()
{
    for (auto sit = units.begin(); sit != units.end(); ++sit) {
        for (auto it = sit->second.begin(); it != sit->second.end(); ++it) {
            if (it->delay == 0) {
                it->delay = it->unit->tick();
            }
        }
    }
}

void UnitModule::notifySectorLoad(vec3i sectorPos)
{
    units[sectorPos] = std::vector<U>(); // ????????? behövs inte? :P
}
void UnitModule::notifySectorUnoad(vec3i sectorPos)
{
    units.erase(sectorPos);
}

void UnitModule::addUnit(Unit* unit)
{
    units[GetSectorPosition(unit->pos)].push_back(U(0,unit));
}

