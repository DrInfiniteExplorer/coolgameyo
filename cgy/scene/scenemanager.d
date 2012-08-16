

module scene.scenemanager;

import std.conv;

import scene.instancemanager;
import scene.meshnode;
import scene.entityproxy;
import scene.unitproxy;
import scene.texturearray;

import graphics.camera;
import graphics.image;
import graphics.models.cgymodel;
import graphics.shader;
import modelparser.cgyparser;

import entities.entity;

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

alias ShaderProgram!("VP", "texUnit") SceneNodeShader;

struct InstanceData {
    vec3f pos;  //Updated to be camera-relative each frame in proxy.preRender
    vec3f rot;
    vec3f scale = vec3f(1.0f);
    uint animationIndex;
    uint frameIndex;
    uint texIdx;
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


    void register(CGYMesh mesh, InstanceData** ptrPtr) {
        
        if(mesh in meshInstanceManagers) {
            meshInstanceManagers[mesh].register(ptrPtr);
            return;
        }
        auto im = new InstanceManager(sceneManager, mesh);
        meshInstanceManagers[mesh] = im;
        im.register(ptrPtr);
        
    }


    void unregister(CGYMesh mesh, InstanceData** ptrPtr) {
        meshInstanceManagers[mesh].unregister(ptrPtr);
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


final class SceneManager {

    SceneNode[][SceneNodeType.Count] sceneNodes;
    UnitProxy[uint] unitProxies;
    EntityProxy[uint] entityProxies;

    uint meshPartCount = 0;
    uint[string] meshNameToInt;

    cgyModel[string] models;
    cgyModel[] newModels; //To be uploaded on first use

    Skeleton[string] skeletons;

    SceneNodeShader[string] shaders;

    TextureArray[uint] textureArrays;

    this() {
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        foreach(proxy ; unitProxies) {
            proxy.destroy();
        }
        foreach(proxy ; entityProxies) {
            proxy.destroy();
        }
        foreach(model ; models) {
            model.destroy();
        }
        foreach(skeleton ; skeletons) {
            skeleton.destroy();
        }
        foreach(shader ; shaders) {
            shader.destroy();
        }
        foreach(textureArray ; textureArrays) {
            textureArray.destroy();
        }



        shaders = null;
        destroyed = true;
    }






    UnitProxy getProxy(Unit unit) {
        if(unit.id in unitProxies) {
            return unitProxies[unit.id];
        }
        auto proxy = new UnitProxy(this, unit);
        unitProxies[unit.id] = proxy;
        return proxy;
    }
    void removeProxy(Unit unit) {
        UnitProxy* proxy = unit.id in unitProxies;
        if(proxy is null) return;
        unitProxies.remove(unit.id);
        proxy.destroy();
    }



    EntityProxy getProxy(Entity entity) {
        if(entity.entityId in entityProxies) {
            return entityProxies[entity.entityId];
        }
        auto proxy = new EntityProxy(this, entity);
        entityProxies[entity.entityId] = proxy;
        return proxy;
    }
    void removeProxy(Entity entity) {
        EntityProxy* proxy = entity.entityId in entityProxies;
        if(proxy is null) return;
        entityProxies.remove(entity.entityId);
        proxy.destroy();
    }








    void newNode(SceneNode node) {
        //Make sure we dont have it already
        sceneNodes[node.getType()] ~= node;
    }

    uint getMeshId(string meshName, int meshPart) {
        auto str = meshName ~ to!string(meshPart);
        if(str in meshNameToInt) {
            return meshNameToInt[str];
        }
        meshNameToInt[str] = meshPartCount;
        meshPartCount += 1;
        return meshPartCount - 1;
    }

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
        shader.bindAttribLocation(9, "texIdx");
        shader.bindAttribLocation(10, "scale");
        shader.link();

        shader.use();
        shader.VP = shader.getUniformLocation("VP");
        shader.texUnit = shader.getUniformLocation("texUnit");
        shader.setUniform(shader.texUnit, 3); //Hardcoded texture unit 3
        shader.use(false);


        /*
            code to detect which variables and things are used in the shader.
            and to bind attributes and the like.
        */

        return shader;
    }

    TextureArray loadArrayTexture(string texture, out uint arrayIdx) {
        TextureArray ret;
        Image image = Image(texture);
        uint hash = 10_000 * image.imgWidth + image.imgHeight;
        if(hash !in textureArrays) {
            ret = new TextureArray();
            textureArrays[hash] = ret;
        } else {
            ret = textureArrays[hash];
        }
        arrayIdx = ret.loadImage(texture, image);
        return ret;
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

        foreach(unitId, unitProxy ; unitProxies) {
            unitProxy.preRender(camera);
        }

        foreach(entityId, entityProxy ; entityProxies) {
            entityProxy.preRender(camera);
        }

        foreach(skeleton ; skeletons) {
            skeleton.render(camera);
        }
    }

};


