using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraControl : MonoBehaviour
{
    private void Start() {
        Camera.main.depthTextureMode = DepthTextureMode.Depth;
    }
}
