/*
	Based on work from https://github.com/fholger/vrperfkit
*/

#pragma once
#define NOMINMAX
#include "nvapi.h"
#include <d3d11.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

enum class TextureMode
{
	SINGLE,
	COMBINED,
	ARRAY,
};

struct FixedFoveatedConfig
{
	bool enabled = false;
	float innerRadius = 0.6f;
	float midRadius = 0.8f;
	float outerRadius = 1.0f;
	bool favorHorizontal = true;
	std::string overrideSingleEyeOrder;
};

struct VRSConfig
{
	FixedFoveatedConfig ffr;
};

extern VRSConfig g_config;

class VariableRateShading
{
public:
	VariableRateShading(ComPtr<ID3D11Device> device);
	~VariableRateShading() { Shutdown(); }

	void UpdateTargetInformation(int a_targetWidth, int a_targetHeight, TextureMode a_mode, float leftProjX, float leftProjY, float rightProjX, float rightProjY);
	void EndFrame();

	void PostOMSetRenderTargets(UINT numViews, ID3D11RenderTargetView* const* renderTargetViews, ID3D11DepthStencilView* depthStencilView);

private:
	bool nvapiLoaded = false;
	bool active = false;

	int targetWidth = 1000000;
	int targetHeight = 1000000;
	TextureMode targetMode = TextureMode::SINGLE;
	float proj[2][2] = { 0, 0, 0, 0 };

	ComPtr<ID3D11Device> device;
	ComPtr<ID3D11DeviceContext> context;
	int singleWidth[2] = { 0, 0 };
	int singleHeight[2] = { 0, 0 };
	ComPtr<ID3D11Texture2D> singleEyeVRSTex[2];
	ComPtr<ID3D11NvShadingRateResourceView> singleEyeVRSView[2];
	std::string singleEyeOrder;
	int currentSingleEyeRT = 0;
	int combinedWidth = 0;
	int combinedHeight = 0;
	ComPtr<ID3D11Texture2D> combinedVRSTex;
	ComPtr<ID3D11NvShadingRateResourceView> combinedVRSView;
	int arrayWidth = 0;
	int arrayHeight = 0;
	ComPtr<ID3D11Texture2D> arrayVRSTex;
	ComPtr<ID3D11NvShadingRateResourceView> arrayVRSView;

	void Shutdown();

	void EnableVRS();
	void DisableVRS();

	void ApplyCombinedVRS(int width, int height);
	void ApplyArrayVRS(int width, int height);
	void ApplySingleEyeVRS(int eye, int width, int height);

	void SetupSingleEyeVRS(int eye, int width, int height, float projX, float projY);
	void SetupCombinedVRS(int width, int height, float leftProjX, float leftProjY, float rightProjX, float rightProjY);
	void SetupArrayVRS(int width, int height, float leftProjX, float leftProjY, float rightProjX, float rightProjY);
};