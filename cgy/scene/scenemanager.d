

module scene.scenemanager;

import std.algorithm;
import std.conv;
import std.exception;

import scene.modelnode;

import graphics.shader;
import graphics.ogl;
import graphics.models.cgymodel;
import modelparser.cgyparser;

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

struct InstanceData {
    vec3f pos;
    vec3f rot;
    uint animationIndex;
    uint frameIndex;
}

class InstanceManager {
    ModelNode[] nodes;
    cgyMesh mesh;

    this(cgyMesh _mesh) {
        mesh = _mesh;
        resizeInstanceVBO(32);
    }

    uint instanceVBO;
    size_t instanceSize;
    void resizeInstanceVBO(size_t size) {
        //TODO: Copy old values when resizeing the buffer
        //Shrink if size is less or equal to half of current
        if(2 * size <= instanceSize) {
            //Also copy current instance values before this!
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glDeleteBuffers(1, &instanceVBO);
            instanceVBO = 0;
            instanceSize = size;
        }
        if(size > instanceSize) {
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glDeleteBuffers(1, &instanceVBO);
            instanceVBO = 0;
            instanceSize = instanceSize + instanceSize/2;
        }
        if(instanceVBO == 0) {
            glGenBuffers(1, &instanceVBO);
            glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
            size_t size = InstanceData.sizeof * instanceSize;
            glBufferData(GL_ARRAY_BUFFER, size, null, GL_DYNAMIC_DRAW);
        }
    }

    void moveInstanceData(size_t from, size_t to) {
        InstanceData data;
        glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
        glGetBufferSubData(GL_ARRAY_BUFFER, InstanceData.sizeof * from, InstanceData.sizeof, &data);
        glBufferSubData(GL_ARRAY_BUFFER, InstanceData.sizeof * to,   InstanceData.sizeof, &data);
    }

    void register(ModelNode modelNode) {
        nodes ~= modelNode;
        resizeInstanceVBO(nodes.length);
        
    }
    void unregister(ModelNode modelNode) {
        auto idx = countUntil(nodes, modelNode);
        enforce(-1 != idx, "Error, trying to remove unexistant thing from InstanceManager");
        moveInstanceData(nodes.length-1, idx);
        resizeInstanceVBO(nodes.length-1);
        nodes[idx] = nodes[$-1];
        nodes.length = nodes.length - 1;
    }

    void render() {
        
        //Bind mesh data & textures
        //Aquire instance-vbo's
        //glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
        //foreach(instance ; modelList) {
            //Populate instance-vbo's
        //}
        //Render instances
        
    }
}

//Rename to SkeletonGroup, because yeah?
class Skeleton {


    SceneManager sceneManager;
    int[string] animations; //List of animationname-to-animationindex

    InstanceManager[cgyMesh] meshInstanceManagers;

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


    void register(ModelNode modelNode) {
        
        foreach(mesh ; modelNode.meshes) {
            InstanceManager *ptrManager = mesh in meshInstanceManagers;
            if(ptrManager is null) {
                auto im = new InstanceManager(mesh);
                meshInstanceManagers[mesh] = im;
                im.register(modelNode);
                return;
            }
            ptrManager.register(modelNode);
        }
        
    }


    void unregister(ModelNode modelNode) {
        
        foreach(mesh ; modelNode.meshes) {
            meshInstanceManagers[mesh].unregister(modelNode);
        }
        
    }

    void startAnimation(string animName, AnimationState animState) {
        animState.frameIndex = 0;
        animState.animationIndex = 0;
        if(animName in animations) {
            animState.animationIndex = animations[animName];
        }
    }



    void render() {
        
        foreach(instanceManager; meshInstanceManagers) {
            instanceManager.render();
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

    cgyModel[string] models;
    cgyModel loadModel(string modelName) {
        if(modelName in models) {
            return models[modelName];
        }
        cgyModel model = new cgyModel();

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
        /*
        foreach(typeList ; sceneNodes) {
            foreach(node ; typeList) {
                node.render();
            }
        }
        */

        foreach(skeleton ; skeletons) {
            skeleton.render();
        }
    }

};


