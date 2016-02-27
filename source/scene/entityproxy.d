module scene.entityproxy;

import std.exception;

import graphics.camera;

import scene.scenemanager;
import scene.meshnode;
import scene.instancemanager;

import entities.entity;

import cgy.debug_.debug_ : BREAK_IF;

class EntityProxy {
    SceneManager sceneManager;

    this(SceneManager _sceneManager, Entity entity) {
        sceneManager = _sceneManager;
        animState = new AnimationState;
        init(entity);
    }
    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {

        mainMesh.destroy();
        destroyed = true;
    }

    void init(Entity entity) {
        auto type = entity.type;

        skeleton = sceneManager.loadSkeleton(type.model.skeletonName);
        auto model  = sceneManager.loadModel(type.model.name);

        auto mesh = model.meshes[0];

        mainMesh = new MeshNode(mesh, animState);

        skeleton.startAnimation("idle", animState);

        skeleton.register(mainMesh.mesh, &mainInstanceData);

        //bodyMesh.setPosition(unit.pos.value);
        auto derp = type.model.meshTextures;
        //If a unit has the same amount of textures for each mesh, will always select
        //a 'matching pair'. Maybe think about this, and be smart about it, in the future.
        auto texturePath = "models/" ~ derp[entity.entityId % derp.length];
        auto texIdx = mainMesh.setTexture(sceneManager, texturePath);

        mainInstanceData.texIdx = texIdx;
        pos = entity.pos.value;
    }

    void preRender(Camera camera) {
        mainInstanceData.pos = (pos - camera.getPosition()).convert!float;
    }

    vec3d pos;

    AnimationState animState;
    Skeleton skeleton;

    InstanceData* mainInstanceData;
    MeshNode mainMesh;
}
