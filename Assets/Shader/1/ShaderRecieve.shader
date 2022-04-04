Shader "Unlit/ShaderRecieve"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color) = (1,1,1,1)
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

        struct appdata{
            float4 vertex : POSITION;
            float2 shadowUV : TEXCOORD0;

        };

        struct v2f
        {
            float2 uv:TEXCOORD0;
            float4 vertex : SV_POSITION;
            float4 shadowPos:TEXCOORD1;
        };

        sampler2D _MainTex;
        float4 _MainTex_ST;
        sampler2D _ShadowMap;
        float4x4 _ShadowLauncherMatrix;
        float3 _ShadowLauncherParam;
        float4 _BaseColor;

        //基于shadowmap的硬阴影
        float HardShadow(v2f i)
        {
            // float4 shadow = tex2Dproj(_ShadowMap,i.shadowPos);//拿到坐标在光源场景下的深度
            // float shadowAlpha = shadow.r;//拿到深度值
            // float2 clipalpha = saturate((0.5-abs(i.shadowPos.xy - 0.5))*20);//限定在0-1之间
            // shadowAlpha *= clipalpha.x * clipalpha.y;

            // float depth = 1-UNITY_SAMPLE_DEPTH(shadow);
            // shadowAlpha*=step(depth,i.shadowPos.z);//如果depth<shadowPos就没有被遮挡
            // return shadowAlpha;
            float4 shadow = tex2Dproj(_ShadowMap,i.shadowPos);
            float texturedepth = shadow.r;
            float depth = i.shadowPos.z/i.shadowPos.w;
            #if UNITY_REVERSED_Z
                depth = 1 - depth; //(1, 0)-->(0, 1)
            #else
                depth = depth * 0.5 + 0.5; //(-1, 1)-->(0, 1)
            #endif

            float shadowAlpha  = (texturedepth) > (depth) ? 1 : 0;
            return shadowAlpha;
        }
        
        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);//MVP矩阵
            float4 worldPos = mul(unity_ObjectToWorld,v.vertex);//模型空间转换到世界空间,相当于进行了model矩阵
            float4 shadowPos = mul(_ShadowLauncherMatrix,worldPos);//从世界坐标到光源坐标
            shadowPos.xy = (shadowPos.xy/_ShadowLauncherParam.x+1)/2;//再将-1,1范围转换到0,1范围用于读取shadowMap中的深度
            shadowPos.z = (shadowPos.z / shadowPos.w - _ShadowLauncherParam.y)  / (_ShadowLauncherParam.z - _ShadowLauncherParam.y);//初始化深度
            

            o.shadowPos = shadowPos;
            o.uv = TRANSFORM_TEX(v.shadowUV, _MainTex);//读取uv
            return o;
        }      
        float4 frag(v2f i):SV_Target
        {
            float4 color = tex2D(_MainTex,i.uv);//拿到主颜色
            float shadowAlpha=0.0;
            shadowAlpha = HardShadow(i);  
            color.rgb *=(1-shadowAlpha)*_BaseColor.rgb;//阴影能见度加上材质本身的颜色
            // float4 shadow = tex2Dproj(_ShadowMap,i.shadowPos);//拿到坐标在光源场景下的深度

            return color;
        }
        ENDCG
        }
    }
}
