module scene.unitproxy;

import std.exception;

import graphics.camera;

import scene.scenemanager;
import scene.meshnode;
import scene.instancemanager;

import unit;

import cgy.debug_.debug_ : BREAK_IF;
import cgy.math.vector : vec3f;

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

        bodyMesh.destroy();
        destroyed = true;
    }

    void init(Unit unit) {
        auto type = unit.type;

        skeleton = sceneManager.loadSkeleton(type.model.skeletonName);
        auto model  = sceneManager.loadModel(type.model.name);

        auto mesh = model.meshes[0];

        bodyMesh = new MeshNode(mesh, animState);

        skeleton.startAnimation("idle", animState);

        skeleton.register(bodyMesh.mesh, &bodyInstanceData);

        //bodyMesh.setPosition(unit.pos.value);
        auto derp = type.model.meshTextures;
        //If a unit has the same amount of textures for each mesh, will always select
        //a 'matching pair'. Maybe think about this, and be smart about it, in the future.
        auto texturePath = "models/" ~ derp[unit.id % derp.length];
        auto texIdx = bodyMesh.setTexture(sceneManager, texturePath);

        bodyInstanceData.texIdx = texIdx;
        pos = unit.pos.value;
    }

    void setDestination(vec3d dest, uint ticksToArrive) {
        //TODO: Add code to move unit depending on things.
        pos = dest;
    }

    void preRender(Camera camera) {
        bodyInstanceData.pos = (pos - camera.getPosition()).convert!float;
        bodyInstanceData.scale = scale;
        
    }

    vec3d pos;
    vec3f scale = vec3f(1.0f);

    AnimationState animState;
    Skeleton skeleton;

    MeshNode hairNode;

    InstanceData* bodyInstanceData;
    MeshNode bodyMesh;
}
