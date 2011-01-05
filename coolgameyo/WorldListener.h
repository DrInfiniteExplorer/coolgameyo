#pragma once

class WorldListener {
public:
    virtual void notifyTileChange(vec3i tile) { }
    virtual void notifySectorLoad(vec3i sectorPos) { }
    virtual void notifySectorUnload(vec3i sectorPos) { }
};
