

module scene.scenemanager;

import std.algorithm;
import std.conv;
import std.exception;

import scene.modelnode;

import graphics.shader;
import graphics.models.md5model;
import modelparser.md5parser;

import unit;
import util.filesystem;
import util.util;


enum SceneNodeType {
    Model,
    ParticleHost,
    Billboard,
    Sprite, //Same as billboard but locked?
    Count,
}

interface SceneNode {
    void setPosition(vec3d pos);
    vec3d getPosition();

    SceneNodeType getType();

    void render();
};

alias ShaderProgram!() SceneNodeShader;

class Skeleton {

    SceneManager sceneManager;
    int[string] animations; //List of animationname-to-animationindex

    this(SceneManager _sceneManager) {
        sceneManager = _sceneManager;
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
    }


    ModelNode[][md5Mesh] modelNodes;

    void register(ModelNode modelNode) {
        foreach(mesh ; modelNode.meshes) {
            modelNodes[mesh] ~= modelNode;
        }
    }

    void unregister(ModelNode modelNode) {
        foreach(mesh ; modelNode.meshes) {
            ModelNode[]* nodes = &modelNodes[mesh];
            auto idx = countUntil(*nodes, modelNode);
            enforce(-1 != idx, "Error, trying to remove unexistant thing from skeletonlist");
            (*nodes)[idx] = (*nodes)[$-1];
            (*nodes).length = (*nodes).length - 1;
        }
    }

    void startAnimation(string animName, AnimationState animState) {
        animState.frameIndex = 0;
        animState.animationIndex = 0;
        if(animName in animations) {
            animState.animationIndex = animations[animName];
        }
    }
}

final class AnimationState {
    uint animationIndex;
    uint frameIndex;
}

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

        skeleton = sceneManager.loadSkeleton(type.skeletonName);
        auto model  = sceneManager.loadModel(type.modelName);

        bodyModel = new ModelNode(model, animState);

        skeleton.startAnimation("idle", animState);
        skeleton.register(bodyModel);
    }

    AnimationState animState;
    Skeleton skeleton;

    ModelNode bodyModel;
}

class SceneManager {

    SceneNode[][SceneNodeType.Count] sceneNodes;

    this() {
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        foreach(shader ; shaders) {
            shader.destroy();
        }
        shaders = null;
        destroyed = true;
    }



    UnitProxy[uint] unitProxies;
    UnitProxy getProxy(Unit unit) {
        if(unit.unitId in unitProxies) {
            return unitProxies[unit.unitId];
        }
        auto proxy = new UnitProxy(this, unit);
        unitProxies[unit.unitId] = proxy;
        return proxy;
    }
    void removeProxy(Unit unit) {
        UnitProxy* proxy = unit.unitId in unitProxies;
        if(proxy is null) return;
        unitProxies.remove(unit.unitId);
        proxy.destroy();
    }



    void newNode(SceneNode node) {
        //Make sure we dont have it already
        sceneNodes[node.getType()] ~= node;
    }

    uint meshPartCount = 0;
    uint[string] meshNameToInt;
    uint getMeshId(string meshName, int meshPart) {
        auto str = meshName ~ to!string(meshPart);
        if(str in meshNameToInt) {
            return meshNameToInt[str];
        }
        meshNameToInt[str] = meshPartCount;
        meshPartCount += 1;
        return meshPartCount - 1;
    }

    md5Model[string] models;
    md5Model loadModel(string modelName) {
        if(modelName in models) {
            return models[modelName];
        }
        md5Model model = new md5Model();

        auto file = readText(modelName);
        auto meshData = parseModel(file);
        model.loadMesh(meshData);
        models[modelName] = model;
        return model;
    }

    Skeleton[string] skeletons;
    Skeleton loadSkeleton(string skeletonName) {
        if(skeletonName in skeletons) {
            return skeletons[skeletonName];
        }
        Skeleton skeleton = new Skeleton(this);

        auto file = readText(skeletonName);
        //auto skeletonData = parse(file);
        //skeleton.loadSkeleton(skeletonData);
        //skeletons[skeletonName] = skeleton;
        enforce(0, "implement");
        return skeleton;
    }


    SceneNodeShader[string] shaders;
    SceneNodeShader getShader(string shaderPath) {
        if(shaderPath in shaders) {
            return shaders[shaderPath];
        }
        auto shader = loadShader(shaderPath);
        shaders[shaderPath] = shader;
        return shader;
    }
    SceneNodeShader loadShader(string shaderPath) {
        auto vertexPath = shaderPath ~ ".vert";
        auto fragmentPath = shaderPath ~ ".frag";
        auto shader = new SceneNodeShader(vertexPath, fragmentPath);

        /*
            code to detect which variables and things are used in the shader.
            and to bind attributes and the like.
        */

        return shader;
    }

    void renderScene() {
        foreach(typeList ; sceneNodes) {
            foreach(node ; typeList) {
                node.render();
            }
        }
    }

};


