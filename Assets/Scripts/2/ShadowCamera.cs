using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShadowCamera : MonoBehaviour
{

    private Camera _lightCamera;
    private RenderTexture lightDepthTexture;

    public GameObject lightObj;
    public Shader shader;
    public RenderTexture lightDepthTextureTest;

    private void Start() {
        _lightCamera = CreateLightCamera();
    }

    public Camera CreateLightCamera()
    {
        GameObject goLightCamera = new GameObject("Shadow Camera");
        Camera LightCamera = goLightCamera.AddComponent<Camera>();
        LightCamera.backgroundColor = Color.white;
        LightCamera.clearFlags = CameraClearFlags.SolidColor;
        LightCamera.orthographic = true;
        LightCamera.orthographicSize = 6f;
        LightCamera.nearClipPlane = 0.3f;
        LightCamera.farClipPlane = 50;
        LightCamera.enabled = false;


        if(!LightCamera.targetTexture)
        {
            LightCamera.targetTexture = lightDepthTextureTest;
        }

        lightDepthTexture = lightDepthTextureTest;
        
        float LightWidth = LightCamera.orthographicSize;
        float BlockerSearchWidth = LightWidth/LightCamera.orthographicSize;

        Shader.SetGlobalTexture("_LightDepthTexture",lightDepthTexture);
        Shader.SetGlobalFloat("_LightTexturePixelWidth",lightDepthTexture.width);
        Shader.SetGlobalFloat("_LightTexturePixelHeight",lightDepthTexture.height);
        Shader.SetGlobalFloat("_BlockerSearchWidth",BlockerSearchWidth);
        Shader.SetGlobalFloat("_LightWidth",LightWidth);

        return LightCamera;
    }

    void Update () {
    //    FitToScene;
        _lightCamera.transform.parent = lightObj.transform;
        _lightCamera.transform.localPosition = Vector3.zero;
       _lightCamera.transform.localRotation = new UnityEngine.Quaternion();
        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(_lightCamera.projectionMatrix, false);
        Shader.SetGlobalMatrix("_worldToLightClipMat", projectionMatrix * _lightCamera.worldToCameraMatrix);
        Shader.SetGlobalFloat("_gShadowStrength", 0.5f);
        Shader.SetGlobalFloat("_gShadowBias", 0.005f);
        _lightCamera.RenderWithShader(shader,"");
        
    }

}
