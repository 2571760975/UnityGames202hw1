using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightCamera : MonoBehaviour
{
    public Shader shader;
    Camera myCamera;

    private void Awake() 
    {
        myCamera = this.GetComponent<Camera>();
        myCamera.SetReplacementShader(shader,"");
        Shader.SetGlobalTexture("_ShadowMap",myCamera.targetTexture);
    }
    // Update is called once per frame
    void Update()
    {
        //方案1
        Shader.SetGlobalMatrix("_ShadowLauncherMatrix", transform.worldToLocalMatrix);//保存将世界坐标转换到光源坐标的矩阵
        Shader.SetGlobalVector("_ShadowLauncherParam", new Vector4(myCamera.orthographicSize, myCamera.nearClipPlane, myCamera.farClipPlane));//存储相机内参
        //方案2
        GetLightProjectMatrix(myCamera);
    }

    void  GetLightProjectMatrix(Camera camera)
	{
		Matrix4x4 worldToView = camera.worldToCameraMatrix;
		Matrix4x4 projection  = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
		Matrix4x4 lightProjecionMatrix =  projection * worldToView;
		Shader.SetGlobalMatrix ("_LightProjection", lightProjecionMatrix);
	}

}
