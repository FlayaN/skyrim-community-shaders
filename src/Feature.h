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

	virtual void SetupResources() = 0;
	virtual void Reset() = 0;

	virtual void DrawSettings() = 0;
	virtual void Draw(const RE::BSShader* shader, const uint32_t descriptor) = 0;
	virtual void DrawDeferred() {}
	virtual void DrawPreProcess() {}

	virtual void DataLoaded() {}
	virtual void PostPostLoad() {}

	virtual void Load(json& o_json);
	virtual void Save(json& o_json) = 0;

	virtual void RestoreDefaultSettings() = 0;

	virtual bool ValidateCache(CSimpleIniA& a_ini);
	virtual void WriteDiskCacheInfo(CSimpleIniA& a_ini);
	virtual void ClearShaderCache() {}

	static const std::vector<Feature*>& GetFeatureList();
};

#define FEATURE_SETTINGS_H                    \
	virtual void Load(json& o_json) override; \
	virtual void Save(json& o_json) override; \
	virtual void RestoreDefaultSettings();    \
	Settings settings;

#define FEATURE_SETTINGS(FeatureType, ...)                                                               \
	inline void to_json(nlohmann::json& nlohmann_json_j, const FeatureType::Settings& nlohmann_json_t)   \
	{                                                                                                    \
		NLOHMANN_JSON_EXPAND(NLOHMANN_JSON_PASTE(NLOHMANN_JSON_TO, __VA_ARGS__))                         \
	}                                                                                                    \
	inline void from_json(const nlohmann::json& nlohmann_json_j, FeatureType::Settings& nlohmann_json_t) \
	{                                                                                                    \
		const FeatureType::Settings nlohmann_json_default_obj{};                                         \
		NLOHMANN_JSON_EXPAND(NLOHMANN_JSON_PASTE(NLOHMANN_JSON_FROM_WITH_DEFAULT, __VA_ARGS__))          \
	}                                                                                                    \
	void FeatureType::Save(json& nlohmann_json_j)                                                        \
	{                                                                                                    \
		nlohmann_json_j[GetName()] = settings;                                                           \
	}                                                                                                    \
	void FeatureType::Load(json& o_json)                                                                 \
	{                                                                                                    \
		if (o_json[GetName()].is_object())                                                               \
			settings = o_json[GetName()];                                                                \
		Feature::Load(o_json);                                                                           \
	}                                                                                                    \
	void FeatureType::RestoreDefaultSettings()                                                           \
	{                                                                                                    \
		settings = {};                                                                                   \
	}
