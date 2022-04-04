Shader "Unlit/ShadowMapping"
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
            // make fog work

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

            sampler2D _LightDepthTexture;
            float4x4 _worldToLightClipMat;

            float _LightTexturePixelWidth;
            float _LightTexturePixelHeight;
            float _BlockerSearchWidth;
            float _LightWidth;
            float2 poissonDisk[32];

            #define PI 3.141592653589793
            #define PI2 6.283185307179586
            #define EPS 1e-3

            #define NUM_SAMPLES 30
            #define NUM_RINGS 10


            float rand_2to1(float2 uv ) { 
            // 0 - 1
                float a = 12.9898, b = 78.233, c = 43758.5453;
                float dt = dot( uv.xy, float2( a,b ) ), sn = fmod( dt, PI );
                return frac(sin(sn) * c);
            }

            void poissonDiskSamples(float2 randomSeed)
            {
                float numSampes = NUM_SAMPLES;
                float numRings = 10;
                float angleStep = UNITY_TWO_PI * numRings / numSampes;
                float invNumSamples = 1.0 / numSampes;
            
                float angle = rand_2to1(randomSeed) * UNITY_TWO_PI;
                float radius = invNumSamples;
                float radiusStep = radius;
            
                for(int i = 0; i < numSampes; i++)
                {
                    poissonDisk[i] = float2(cos(angle), sin(angle) * pow(radius, 0.75));
                    radius += radiusStep;
                    angle += angleStep;
                }
            }

            float findBlocker(float zReceiver,float2 uv)
            {
                int step  = 3.0;
                float average_depth = 0.0;
                float count = 0.0005;//防止除于0
                for(int i = -step ;i<=step ;i++)
                {
                    for(int j = -step ;j<=step ;j++)
                    {
                        float2 uvOffset = float2(i,j)/step *_BlockerSearchWidth;

                        float sampleDepth = tex2D(_LightDepthTexture,uv + uvOffset).r;
                        if(sampleDepth < zReceiver)
                        {
                            count += 1;
                            average_depth += sampleDepth;
                        }
                    }
                }
                float result = average_depth/count;
                return result;
            }
            

            float PCFSample(float depth, float2 uv,int _FilterSize)
            {
                float shadow = 0.0;
                float2 texelSize = float2(_LightTexturePixelWidth,_LightTexturePixelHeight);
                texelSize = 1/texelSize;
                for(int x = -_FilterSize; x<= _FilterSize;x++)
                {
                    for(int y = -_FilterSize;y<= _FilterSize;y++)
                    {
                        float2 uv_offset = float2(x,y)*texelSize;
                        float Samepledepth = tex2D(_LightDepthTexture,uv+uv_offset).r;
                        shadow += Samepledepth > depth ? 1 : 0;
                    }
                }
                float total = (_FilterSize*2+1)*(_FilterSize*2+1);
                shadow /= total;

                return shadow;
            }

            float HardShadow(v2f i)
            {
                //得到光源下的深度
                float4 realPos = ComputeScreenPos(i.shadowPos);//该函数得到齐次坐标下的屏幕坐标值
                float texDepth = tex2Dproj(_LightDepthTexture, realPos).r;//tex2Dproj将输入的UV xy坐标除以其w坐标。这是将坐标从正交投影转换为透视投影
                float depth = i.shadowPos.z/i.shadowPos.w;

                #if UNITY_REVERSED_Z
                    depth = 1 - depth;//和反向深度有关
                #else
                    depth = depth*0.5 + 0.5;//转换到0-1中进行比较
                #endif

                float shadow = (texDepth) > (depth) ? 1 : 0;
                return shadow;
            }

            float HardShadow2(v2f i)
            {
                i.shadowPos.xy = i.shadowPos.xy/i.shadowPos.w;
                float2 uv = i.shadowPos.xy;
                uv = uv*0.5 + 0.5;

                float depth = i.shadowPos.z/i.shadowPos.w;
            #if defined (UNITY_REVERSED_Z)
                depth = 1 - depth;  //(1, 0)-->(0, 1)
            #else
                depth = depth*0.5 + 0.5;     //(-1, 1)-->(0, 1)
            #endif

                float4 col = tex2D(_LightDepthTexture,uv);
                float sampleDepth = col.r;
                float shadow = (sampleDepth) > (depth) ? 1:0;
                return shadow;
            }

            float ShadowWithPCF(v2f i )
            {
                i.shadowPos.xy = i.shadowPos.xy/i.shadowPos.w;
                float2 uv = i.shadowPos.xy;
                uv = uv*0.5 + 0.5;

                float depth = i.shadowPos.z/i.shadowPos.w;
            #if defined (UNITY_REVERSED_Z)
                depth = 1 - depth;  //(1, 0)-->(0, 1)
            #else
                depth = depth*0.5 + 0.5;     //(-1, 1)-->(0, 1)
            #endif
                int _FilterSize = 1;
                float shadow = PCFSample(depth,uv,_FilterSize);
                return shadow;
            }

            float ShadowWithPCSS(v2f i)
            {
                i.shadowPos.xy = i.shadowPos.xy/i.shadowPos.w;
                float2 uv = i.shadowPos.xy;
                uv = uv*0.5 + 0.5;
                poissonDiskSamples(uv);

                float depth = i.shadowPos.z/i.shadowPos.w;
            #if defined (UNITY_REVERSED_Z)
                depth = 1 - depth;  //(1, 0)-->(0, 1)
            #else
                depth = depth*0.5 + 0.5;     //(-1, 1)-->(0, 1)
            #endif

                // STEP 1: avgblocker depth
                float zBlocker = findBlocker(depth,uv);
                if(zBlocker < EPS) return 1.0;
                if(zBlocker > 1.0) return 0.0;

                // STEP 2: penumbra size
                float wPenumbra = (depth - zBlocker) * _LightWidth / zBlocker;
                // float realFilterSize = wPenumbra /depth;//只有在世界空间中计算时才需要

                //Step3 PCF

                float textureSize = float(_LightTexturePixelWidth);
                float filterRange = 1.0 / textureSize * wPenumbra;
                int noShadowCount = 0;
                for( int i = 0; i < NUM_SAMPLES; i ++ ) {
                    float2 sampleCoord = poissonDisk[i] * filterRange + uv;

                    float closestDepth = tex2D(_LightDepthTexture, sampleCoord).r; 
                    if(depth < closestDepth){
                    noShadowCount += 1;
                    }
                }
                float shadow = float(noShadowCount) / float(NUM_SAMPLES);

                return shadow;
            }
            float Chebychev(float t,float variance,float mean)
            {
                float variance2 = variance*variance;
                return variance2/(variance2 +(t - mean)*(t-mean));
            }

            float ShadowWithVssm(v2f i)
            {
                i.shadowPos.xy = i.shadowPos.xy/i.shadowPos.w;
                float2 uv = i.shadowPos.xy;
                uv = uv*0.5 + 0.5;

                float depth = i.shadowPos.z/i.shadowPos.w;
            #if defined (UNITY_REVERSED_Z)
                depth = 1 - depth;  //(1, 0)-->(0, 1)
            #else
                depth = depth*0.5 + 0.5;     //(-1, 1)-->(0, 1)
            #endif

                float4 depthTexture =  tex2D(_LightDepthTexture,uv);
                // STEP 1: avgblocker depth
                float BlockerAverage = depthTexture.r;
                float BlockerAverage2 = depthTexture.g;
                float Blockervariance = clamp(BlockerAverage2 - BlockerAverage * BlockerAverage, 0, 1);

                float BlockerUp =  BlockerAverage - Chebychev(depth,Blockervariance,BlockerAverage)*depth;
                float BlockerDown = 1 - Chebychev(depth,Blockervariance,BlockerAverage);
                float zBlocker = BlockerUp / BlockerDown;

                // STEP 2: penumbra size
                float wPenumbra = (depth - zBlocker) * _LightWidth / zBlocker;

                //Step3 VSM
                return 0;

            }

            float4 DepthTexture(v2f i)
            {
                i.shadowPos.xy = i.shadowPos.xy/i.shadowPos.w;
                float2 uv = i.shadowPos.xy;
                uv = uv*0.5 + 0.5;
                float4 col = tex2D(_LightDepthTexture,uv);

                return col;
            }



            v2f vert (appdata v)
            {
                v2f o;
                float4 ShadowworldPos = mul(unity_ObjectToWorld,v.vertex);
                float4 shadowClipPos = mul(_worldToLightClipMat,ShadowworldPos);
                
                o.shadowPos = shadowClipPos;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.shadowUV, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // float shadow = HardShadow2(i);
                float4 depthColor = DepthTexture(i);

                //USEPCF
                // float shadow = ShadowWithPCF(i);

                //USEPCSS
                float shadow = ShadowWithPCSS(i);

                //USEVSSM
                // float shadow = ShadowWithVssm(i);

                col *= shadow;

                return col;
            }
            ENDCG
        }
    }
}
