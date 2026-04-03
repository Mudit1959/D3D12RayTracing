#pragma once
#include <d3d11.h>
#include<wrl/client.h>
#include "Vertex.h"
#include "Graphics.h"
#include <DirectXMath.h>

class Material
{

public:
	Material(Microsoft::WRL::ComPtr<ID3D12PipelineState> pipelineState,
		DirectX::XMFLOAT3 tint, float inRough, unsigned int isEmmissive = 0,
		DirectX::XMFLOAT2 UVScale = DirectX::XMFLOAT2(1,1),
		DirectX::XMFLOAT2 UVOffset = DirectX::XMFLOAT2(0,0)); // pointer to first index of tint

	Material(DirectX::XMFLOAT3 inTint, float inRough = 1.0f, unsigned int isEmmissive = 0);
	
	DirectX::XMFLOAT3 GetTint();
	DirectX::XMFLOAT2 GetScale();
	DirectX::XMFLOAT2 GetOffset();
	void SetTint(DirectX::XMFLOAT3 t);
	void SetScale(DirectX::XMFLOAT2 s);
	void SetOffset(DirectX::XMFLOAT2 o);

	void SetAlbedoIndex(unsigned int i);
	void SetNormalMapIndex(unsigned int i);
	void SetRoughnessIndex(unsigned int i);
	void SetMetalnessIndex(unsigned int i);


	unsigned int GetAlbedoIndex();
	unsigned int GetNormalMapIndex();
	unsigned int GetRoughnessIndex();
	unsigned int GetMetalnessIndex();

	float GetRoughness();
	unsigned int GetEmmissive();

	void SetPipelineState(Microsoft::WRL::ComPtr<ID3D12PipelineState> pipelineState);
	Microsoft::WRL::ComPtr<ID3D12PipelineState> GetPipelineState();

private:
	// Shaders, and characteristics
	DirectX::XMFLOAT3 tint;
	DirectX::XMFLOAT2 scale;
	DirectX::XMFLOAT2 offset;
	float roughness;
	unsigned int emmissive;
	//bool IsMetal;

	// Pipeline state object includes the shaders binded
	Microsoft::WRL::ComPtr<ID3D12PipelineState> pipelineState;

	// Assuming only four textures are in use at any given time
	unsigned int albedoIndex;
	unsigned int normalMapIndex;
	unsigned int roughnessIndex;
	unsigned int metalnessIndex;

};
