#include "Material.h"

Material::Material(Microsoft::WRL::ComPtr<ID3D12PipelineState> inPipelineState,
	DirectX::XMFLOAT3 inTint, float inRough, unsigned int isEmmissive,
	DirectX::XMFLOAT2 UVScale,
	DirectX::XMFLOAT2 UVOffset) :

	pipelineState(inPipelineState), 
	tint(inTint),
	scale(UVScale),
	offset(UVOffset),
	roughness(inRough),
	emmissive(isEmmissive),
	albedoIndex(-1),
	normalMapIndex(-1),
	roughnessIndex(-1),
	metalnessIndex(-1)
{
}

Material::Material(DirectX::XMFLOAT3 inTint, float inRough, unsigned int isEmmissive) :
	tint(inTint), roughness(inRough), emmissive(isEmmissive),
albedoIndex(-1),
normalMapIndex(-1),
roughnessIndex(-1),
metalnessIndex(-1),
scale(DirectX::XMFLOAT2(0,0)),
offset(DirectX::XMFLOAT2(0,0))
{}

float Material::GetRoughness() { return roughness; }

DirectX::XMFLOAT3 Material::GetTint() { return tint; }
DirectX::XMFLOAT2 Material::GetScale() { return scale; }
DirectX::XMFLOAT2 Material::GetOffset() { return offset; }
unsigned int Material::GetAlbedoIndex() { return albedoIndex; }
unsigned int Material::GetNormalMapIndex() { return normalMapIndex; }
unsigned int Material::GetRoughnessIndex() { return roughnessIndex; }
unsigned int Material::GetMetalnessIndex() { return metalnessIndex; }
unsigned int Material::GetEmmissive() { return emmissive; }

Microsoft::WRL::ComPtr<ID3D12PipelineState> Material::GetPipelineState() { return pipelineState; }
void Material::SetPipelineState(Microsoft::WRL::ComPtr<ID3D12PipelineState> p) { pipelineState = p; }

void Material::SetTint(DirectX::XMFLOAT3 t) { tint = t; }
void Material::SetScale(DirectX::XMFLOAT2 s) { scale = s; }
void Material::SetOffset(DirectX::XMFLOAT2 o) { offset = o; }

void Material::SetAlbedoIndex(unsigned int i) { albedoIndex = i; }
void Material::SetNormalMapIndex(unsigned int i) { normalMapIndex = i; }
void Material::SetRoughnessIndex(unsigned int i) { roughnessIndex = i; }
void Material::SetMetalnessIndex(unsigned int i) { metalnessIndex = i; }