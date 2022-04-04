Shader "Unlit/Depth2"
{
    SubShader {
        Tags {           
            "RenderType" = "Opaque"
        }

        Pass {
            Fog { Mode Off }
            Cull front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct v2f {
                float4 pos : SV_POSITION;
                float2 depth:TEXCOORD0;
            };

            uniform float _gShadowBias;

            v2f vert (appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pos.z += _gShadowBias;
                o.depth = o.pos.zw;

                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET
            {
                float depth = i.depth.x/i.depth.y;
            #if defined (SHADER_TARGET_GLSL) 
                depth = depth*0.5 + 0.5; //(-1, 1)-->(0, 1)
            #elif defined (UNITY_REVERSED_Z)
                depth = 1 - depth;       //(1, 0)-->(0, 1)
            #endif

                float depth2 = depth*depth;
                float depth3 = depth2 *depth;
                float depth4 = depth3*depth;

                // return float4(depth,depth2,depth3,depth4);
                return depth;
            }
            ENDCG 
        }    
    }
}
