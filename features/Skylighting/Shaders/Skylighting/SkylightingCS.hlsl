#include "../Common/DeferredShared.hlsli"
#include "../Common/FrameBuffer.hlsl"
#include "../Common/GBuffer.hlsli"
#include "../Common/VR.hlsli"

Texture2D<unorm float> DepthTexture : register(t0);

struct PerGeometry
{
	float4 VPOSOffset;
	float4 ShadowSampleParam;    // fPoissonRadiusScale / iShadowMapResolution in z and w
	float4 EndSplitDistances;    // cascade end distances int xyz, cascade count int z
	float4 StartSplitDistances;  // cascade start ditances int xyz, 4 int z
	float4 FocusShadowFadeParam;
	float4 DebugColor;
	float4 PropertyColor;
	float4 AlphaTestRef;
	float4 ShadowLightParam;  // Falloff in x, ShadowDistance squared in z
	float4x3 FocusShadowMapProj[4];
#if !defined(VR)
	float4x3 ShadowMapProj[1][3];
	float4x4 CameraViewProjInverse2[1];
#else
	float4x3 ShadowMapProj[2][3];
	float4x4 CameraViewProjInverse2[2];
#endif  // VR
};

Texture2DArray<unorm float> TexShadowMapSampler : register(t1);
StructuredBuffer<PerGeometry> perShadow : register(t2);
Texture2DArray<float4> BlueNoise : register(t3);
Texture2D<unorm float> OcclusionMapSampler : register(t4);
Texture2D<unorm float> OcclusionMapTranslucentSampler : register(t5);
Texture2D<unorm half3> NormalRoughnessTexture : register(t6);

RWTexture2D<unorm half2> SkylightingTextureRW : register(u0);

cbuffer PerFrame : register(b0)
{
	row_major float4x4 OcclusionViewProj;
	float4 ShadowDirection;
};

SamplerState LinearSampler : register(s0);
SamplerComparisonState ShadowSamplerPCF : register(s1);

half GetBlueNoise(half2 uv)
{
	return BlueNoise[uint3(uv % 128, FrameCount % 64)];
}

half GetScreenDepth(half depth)
{
	return (CameraData.w / (-depth * CameraData.z + CameraData.x));
}

//#define SHADOWMAP
#define PI 3.1415927

#if !defined(SHADOWMAP)
[numthreads(8, 8, 1)] void main(uint3 globalId
								: SV_DispatchThreadID) {
	float2 uv = float2(globalId.xy + 0.5) * BufferDim.zw * DynamicResolutionParams2.xy;
	uint eyeIndex = GetEyeIndexFromTexCoord(uv);

	half3 normalGlossiness = NormalRoughnessTexture[globalId.xy];
	half3 normalVS = DecodeNormal(normalGlossiness.xy);
	half3 normalWS = normalize(mul(CameraViewInverse[eyeIndex], half4(normalVS, 0)));
	half roughness = 1.0 - normalGlossiness.z;

	float rawDepth = DepthTexture[globalId.xy];

	float4 positionCS = float4(2 * float2(uv.x, -uv.y + 1) - 1, rawDepth, 1);

	float4 positionMS = mul(CameraViewProjInverse[eyeIndex], positionCS);
	positionMS.xyz = positionMS.xyz / positionMS.w;

	float3 startPositionMS = positionMS;

	half noise = GetBlueNoise(globalId.xy) * 2.0 * PI;

	half2x2 rotationMatrix = half2x2(cos(noise), sin(noise), -sin(noise), cos(noise));

	half2 PoissonDisk[16] = {
		half2(-0.94201624, -0.39906216),
		half2(0.94558609, -0.76890725),
		half2(-0.094184101, -0.92938870),
		half2(0.34495938, 0.29387760),
		half2(-0.91588581, 0.45771432),
		half2(-0.81544232, -0.87912464),
		half2(-0.38277543, 0.27676845),
		half2(0.97484398, 0.75648379),
		half2(0.44323325, -0.97511554),
		half2(0.53742981, -0.47373420),
		half2(-0.26496911, -0.41893023),
		half2(0.79197514, 0.19090188),
		half2(-0.24188840, 0.99706507),
		half2(-0.81409955, 0.91437590),
		half2(0.19984126, 0.78641367),
		half2(0.14383161, -0.14100790)
	};

	uint sampleCount = 16;

	half2 skylighting = 0;

	float occlusionThreshold = mul(OcclusionViewProj, float4(positionMS.xyz, 1)).z;

	half3 V = normalize(positionMS.xyz);
	half3 R = reflect(V, normalWS);

	bool fadeOut = length(startPositionMS) > 256;

	half2 weights = 0.0;

	[unroll] for (uint i = 0; i < sampleCount; i++)
	{
		half2 offset = mul(PoissonDisk[i].xy, rotationMatrix);
		half shift = half(i) / half(sampleCount);
		half radius = length(offset);

		positionMS.xy = startPositionMS + offset * 128;

		half2 occlusionPosition = mul((float2x4)OcclusionViewProj, float4(positionMS.xyz, 1));
		occlusionPosition.y = -occlusionPosition.y;
		half2 occlusionUV = occlusionPosition.xy * 0.5 + 0.5;

		half3 offsetDirection = normalize(half3(offset.xy, 0));

		if ((occlusionUV.x == saturate(occlusionUV.x) && occlusionUV.y == saturate(occlusionUV.y)) || !fadeOut) {
			half shadowMapValues = OcclusionMapSampler.SampleCmpLevelZero(ShadowSamplerPCF, occlusionUV, occlusionThreshold - (1e-2 * 0.05 * radius));
			half shadowMapTranslucentValues = OcclusionMapTranslucentSampler.SampleCmpLevelZero(ShadowSamplerPCF, occlusionUV, occlusionThreshold - (1e-2 * 0.05 * radius));

			half3 H = normalize(-offsetDirection + V);
			half NoH = dot(normalWS, H);
			half a = NoH * roughness;
			half k = roughness / (1.0 - NoH * NoH + a * a);
			half ggx = k * k * (1.0 / PI);

			half2 contributions = half2(dot(normalWS.xyz, offsetDirection.xyz) * 0.5 + 0.5, ggx);

			skylighting += shadowMapValues * contributions;
			weights += contributions;
		} else {
			skylighting++;
			weights++;
		}
	}

	skylighting.xy /= weights.xy;

	weights = 0.0;
	half2 skylightingTranslucent = 0;

	[unroll] for (uint i = 0; i < sampleCount; i++)
	{
		half2 offset = mul(PoissonDisk[i].xy, rotationMatrix);
		half shift = half(i) / half(sampleCount);
		half radius = length(offset);

		positionMS.xy = startPositionMS + offset * 256;

		half2 occlusionPosition = mul((float2x4)OcclusionViewProj, float4(positionMS.xyz, 1));
		occlusionPosition.y = -occlusionPosition.y;
		half2 occlusionUV = occlusionPosition.xy * 0.5 + 0.5;

		half3 offsetDirection = normalize(half3(offset.xy, 0));

		if ((occlusionUV.x == saturate(occlusionUV.x) && occlusionUV.y == saturate(occlusionUV.y)) || !fadeOut) {
			half shadowMapValues = OcclusionMapTranslucentSampler.SampleCmpLevelZero(ShadowSamplerPCF, occlusionUV, occlusionThreshold - (1e-2 * 0.05 * radius));
			half shadowMapTranslucentValues = OcclusionMapTranslucentSampler.SampleCmpLevelZero(ShadowSamplerPCF, occlusionUV, occlusionThreshold - (1e-2 * 0.05 * radius));

			half3 H = normalize(-offsetDirection + V);
			half NoH = dot(normalWS, H);
			half a = NoH * roughness;
			half k = roughness / (1.0 - NoH * NoH + a * a);
			half ggx = k * k * (1.0 / PI);

			half2 contributions = half2(dot(normalWS.xyz, offsetDirection.xyz) * 0.5 + 0.5, ggx);

			skylightingTranslucent += shadowMapValues * contributions;
			weights += contributions;
		} else {
			skylightingTranslucent++;
			weights++;
		}
	}

	skylightingTranslucent.xy /= weights.xy;

	skylighting = min(skylighting, lerp(0.5, 1.0, skylightingTranslucent));

	SkylightingTextureRW[globalId.xy] = saturate(skylighting);
}
#else
[numthreads(8, 8, 1)] void main(uint3 globalId
								: SV_DispatchThreadID) {
	float2 uv = float2(globalId.xy + 0.5) * BufferDim.zw * DynamicRes.zw;
	uint eyeIndex = GetEyeIndexFromTexCoord(uv);

	half3 normalGlossiness = NormalRoughnessTexture[globalId.xy];
	half3 normalVS = DecodeNormal(normalGlossiness.xy);
	half3 normalWS = normalize(mul(CameraViewInverse[eyeIndex], half4(normalVS, 0)));
	half roughness = 1.0 - normalGlossiness.z;

	float rawDepth = DepthTexture[globalId.xy];

	float4 positionCS = float4(2 * float2(uv.x, -uv.y + 1) - 1, rawDepth, 1);

	PerGeometry sD = perShadow[0];

	sD.EndSplitDistances.x = GetScreenDepth(sD.EndSplitDistances.x);
	sD.EndSplitDistances.y = GetScreenDepth(sD.EndSplitDistances.y);
	sD.EndSplitDistances.z = GetScreenDepth(sD.EndSplitDistances.z);
	sD.EndSplitDistances.w = GetScreenDepth(sD.EndSplitDistances.w);

	float4 positionMS = mul(sD.CameraViewProjInverse[eyeIndex], positionCS);
	positionMS.xyz = positionMS.xyz / positionMS.w;

	float3 startPositionMS = positionMS;

	half fadeFactor = pow(saturate(dot(positionMS.xyz, positionMS.xyz) / sD.ShadowLightParam.z), 8);

	half noise = GetBlueNoise(globalId.xy) * 2.0 * PI;

	half2x2 rotationMatrix = half2x2(cos(noise), sin(noise), -sin(noise), cos(noise));

	half2 PoissonDisk[16] = {
		half2(-0.94201624, -0.39906216),
		half2(0.94558609, -0.76890725),
		half2(-0.094184101, -0.92938870),
		half2(0.34495938, 0.29387760),
		half2(-0.91588581, 0.45771432),
		half2(-0.81544232, -0.87912464),
		half2(-0.38277543, 0.27676845),
		half2(0.97484398, 0.75648379),
		half2(0.44323325, -0.97511554),
		half2(0.53742981, -0.47373420),
		half2(-0.26496911, -0.41893023),
		half2(0.79197514, 0.19090188),
		half2(-0.24188840, 0.99706507),
		half2(-0.81409955, 0.91437590),
		half2(0.19984126, 0.78641367),
		half2(0.14383161, -0.14100790)
	};

	uint sampleCount = 16;

	half2 skylighting = 0;

	half3 V = normalize(positionMS.xyz);
	half3 R = reflect(V, normalWS);

	float2 weights = 0.0;

	uint validSamples = 0;
	[unroll] for (uint i = 0; i < sampleCount; i++)
	{
		half2 offset = mul(PoissonDisk[i].xy, rotationMatrix);
		half shift = half(i) / half(sampleCount);
		half radius = length(offset);

		positionMS.xy = startPositionMS + offset.xy * 128 + ShadowDirection.xy * 128;

		half3 offsetDirection = normalize(half3(offset.xy, 0));

		float shadowMapDepth = length(positionMS.xyz);

		[flatten] if (sD.EndSplitDistances.z > shadowMapDepth)
		{
			half cascadeIndex = 0;
			float4x3 lightProjectionMatrix = sD.ShadowMapProj[eyeIndex][0];
			float shadowMapThreshold = sD.AlphaTestRef.y;

			[flatten] if (2.5 < sD.EndSplitDistances.w && sD.EndSplitDistances.y < shadowMapDepth)
			{
				lightProjectionMatrix = sD.ShadowMapProj[eyeIndex][2];
				shadowMapThreshold = sD.AlphaTestRef.z;
				cascadeIndex = 2;
			}
			else if (sD.EndSplitDistances.x < shadowMapDepth)
			{
				lightProjectionMatrix = sD.ShadowMapProj[eyeIndex][1];
				shadowMapThreshold = sD.AlphaTestRef.z;
				cascadeIndex = 1;
			}

			float3 positionLS = mul(transpose(lightProjectionMatrix), float4(positionMS.xyz, 1)).xyz;

			half shadowMapValues = TexShadowMapSampler.SampleCmpLevelZero(ShadowSamplerPCF, float3(positionLS.xy, cascadeIndex), positionLS.z - (1e-2 * 0.1 * radius));

			half3 H = normalize(-offsetDirection + V);
			half NoH = dot(normalWS, H);
			half a = NoH * roughness;
			half k = roughness / (1.0 - NoH * NoH + a * a);
			half ggx = k * k * (1.0 / PI);

			half2 contributions = half2(dot(normalWS.xyz, offsetDirection.xyz) * 0.5 + 0.5, ggx);

			skylighting += shadowMapValues * contributions;
			weights += contributions;
		}
	}

	if (weights > 0.0)
		skylighting /= weights;
	else
		skylighting = 1.0;

	SkylightingTextureRW[globalId.xy] = lerp(saturate(skylighting), 1.0, fadeFactor);
}
#endif