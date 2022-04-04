Shader "Unlit/Shadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            //提前定义
            uniform sampler2D_float _CameraDepthTexture;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD2;
            };

            v2f vert(appdata_base i)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(i.vertex);
                o.uv = i.texcoord.xy;
                return o;
            }

            fixed4 frag(v2f i) : SV_TARGET
            {
                //兼容问题
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture,i.uv));
                depth = Linear01Depth(depth);//UNITY_SAMPLE_DEPTH得到的深度值往往是非线性的
                return fixed4(depth,depth,depth,1);
            }

            ENDCG
        }
    }
}
