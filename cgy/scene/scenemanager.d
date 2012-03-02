

module scene.scenemanager;

import std.conv;

import scene.instancemanager;
import scene.modelnode;

import graphics.camera;
import graphics.shader;
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

alias ShaderProgram!("VP") SceneNodeShader;

struct InstanceData {
    vec3f pos;
    vec3f rot;
    uint animationIndex;
    uint frameIndex;
}



//Rename to SkeletonGroup, because yeah?
final class Skeleton {


    SceneManager sceneManager;
    int[string] animations; //List of animationname-to-animationindex

    InstanceManager[CGYMesh] meshInstanceManagers;

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
            if(mesh in meshInstanceManagers) {
                meshInstanceManagers[mesh].register(modelNode);
                return;
            }
            auto im = new InstanceManager(sceneManager, mesh);
            meshInstanceManagers[mesh] = im;
            im.register(modelNode);
        }
        
    }


    void unregister(ModelNode modelNode) {
        
        foreach(mesh ; modelNode.meshes) {
            meshInstanceManagers[mesh].unregister(modelNode);
        }
        
    }


    void render(Camera camera) {

        foreach(instanceManager; meshInstanceManagers) {
            instanceManager.render(camera);
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
        bodyModel.setPosition(unit.pos.value);

        skeleton.startAnimation("idle", animState);
        skeleton.register(bodyModel);
    }

    AnimationState animState;
    Skeleton skeleton;

    ModelNode bodyModel;
}

final class SceneManager {

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
    cgyModel[] newModels;
    cgyModel loadModel(string modelName) {
        if(modelName in models) {
            return models[modelName];
        }
        cgyModel model = new cgyModel();
        newModels ~= model;

        auto file = readText("models/" ~ modelName);
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

        //auto file = readText(skeletonName);
        //auto skeletonData = parse(file);
        //skeleton.loadSkeleton(skeletonData);
        skeletons[skeletonName] = skeleton;
        pragma(msg, "implement skeleton loading");
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
    private SceneNodeShader loadShader(string shaderPath) {
        auto vertexPath = shaderPath ~ ".vert";
        auto fragmentPath = shaderPath ~ ".frag";
        auto shader = new SceneNodeShader(vertexPath, fragmentPath);

        shader.bindAttribLocation(0, "position");
        shader.bindAttribLocation(1, "texcoord");
        shader.bindAttribLocation(2, "normal");
        shader.bindAttribLocation(3, "bones");
        shader.bindAttribLocation(4, "weights");

        shader.bindAttribLocation(5, "pos");
        shader.bindAttribLocation(6, "rot");
        shader.bindAttribLocation(7, "animationIndex");
        shader.bindAttribLocation(8, "frameIndex");
        shader.link();

        shader.use();
        shader.VP = shader.getUniformLocation("VP");
        shader.use(false);


        /*
            code to detect which variables and things are used in the shader.
            and to bind attributes and the like.
        */

        return shader;
    }

    void renderScene(Camera camera) {
        /*
        foreach(typeList ; sceneNodes) {
            foreach(node ; typeList) {
                node.render();
            }
        }
        */
        
        foreach(model ; newModels) {
            model.prepare();
        }
        newModels.length = 0;

        foreach(skeleton ; skeletons) {
            skeleton.render(camera);
        }
    }

};


