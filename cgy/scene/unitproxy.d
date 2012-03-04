module scene.unitproxy;

import std.exception;

import scene.scenemanager;
import scene.modelnode;
import scene.instancemanager;

import unit;

import util.util;

class UnitProxy {
    SceneManager sceneManager;

    this(SceneManager _sceneManager, Unit unit) {
        sceneManager = _sceneManager;
        animState = new AnimationState;
        init(unit);
    }
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {

        bodyModel.destroy();
        destroyed = true;
    }

    void init(Unit unit) {
        auto type = unit.type;

        skeleton = sceneManager.loadSkeleton(type.model.skeletonName);
        auto model  = sceneManager.loadModel(type.model.name);

        bodyModel = new ModelNode(model, animState);
        bodyModel.setPosition(unit.pos.value);
        foreach(idx, mesh ; model.meshes) {
            auto meshName = mesh.name;
            enforce(meshName in type.model.meshTextures, "Cant find " ~ meshName ~ " in loaded derps!");
            auto derp = type.model.meshTextures[meshName];
            //If a unit has the same amount of textures for each mesh, will always select
            //a 'matching pair'. Maybe think about this, and be smart about it, in the future.
            auto texturePath = "models/" ~ derp[unit.unitId % derp.length];
            bodyModel.setTexture(idx, sceneManager, texturePath);
        }


        skeleton.startAnimation("idle", animState);
        skeleton.register(bodyModel);
    }

    AnimationState animState;
    Skeleton skeleton;

    ModelNode hairNode;
    ModelNode bodyModel;
}
