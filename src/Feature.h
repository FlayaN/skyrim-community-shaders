#pragma once

struct Feature
{
	bool loaded = false;
	std::string version;
	std::string failedLoadedMessage;

	virtual std::string GetName() = 0;
	virtual std::string GetShortName() = 0;
	virtual std::string_view GetShaderDefineName() { return ""; }

	virtual bool HasShaderDefine(RE::BSShader::Type) { return false; }
	/**
	 * Whether the feature supports VR.
	 * 
	 * \return true if VR supported; else false
	 */
	virtual bool SupportsVR() { return false; }

	virtual void SetupResources() {}
	virtual void Reset() {}

	virtual void DrawSettings() = 0;
	virtual void Draw(const RE::BSShader*, const uint32_t) {}
	virtual void DrawDeferred() {}
	virtual void DrawPreProcess() {}
	virtual void Prepass() {}

	virtual void DataLoaded() {}
	virtual void PostPostLoad() {}

	void Load(json& o_json);
	void Save(json& o_json);

	virtual void SaveSettings(json&) {}
	virtual void LoadSettings(json&) {}

	virtual void RestoreDefaultSettings() = 0;

	virtual bool ValidateCache(CSimpleIniA& a_ini);
	virtual void WriteDiskCacheInfo(CSimpleIniA& a_ini);
	virtual void ClearShaderCache() {}

	static const std::vector<Feature*>& GetFeatureList();
};