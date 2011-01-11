#include "UnitModule.h"

#include "Util.h"



UnitModule::UnitModule(World* world)
    : Module(world)
{
}

void UnitModule::tick()
{
    foreach (sit, units) {
        foreach (it, sit->second) {
            if (it->delay == 0) {
                it->delay = it->unit->tick(world);
            } else {
                it->delay -= 1;
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

