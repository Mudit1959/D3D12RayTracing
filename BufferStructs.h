#pragma once
#include <DirectXMath.h>
#include "Light.h"

// Vertex shader & Pixel Shader constants

// In a given frame, for the vertex shader
// There are some pieces of data that remain the same across all objects -> position of camera (view), the camera's perspective (proj) - no point writing the same piece of data for each when it can be shared by all!
// There are some that differ from object to object - the positions of each object differ (world, worldInv)

struct VSConstantsAll 
{
	DirectX::XMFLOAT4X4 view;
	DirectX::XMFLOAT4X4 proj;
};

struct VSConstantsEach 
{
	DirectX::XMFLOAT4X4 world;
	DirectX::XMFLOAT4X4 worldInv;

};

// In a given frame for the pixel shader
// Same across all - cameraWorldPos, lightCount, lights -  no point writing the same piece of data for each when it can be shared by all!
// Different - albedo, normal, roughness, metalness, UVScale, UVOffset

struct PSConstantsAll 
{
	DirectX::XMFLOAT3 cameraWorldPos;
	int lightCount;

	Light lights[MAX_LIGHTS];
};

struct PSConstantsEach
{
	unsigned int albedoIndex;
	unsigned int normalIndex;
	unsigned int roughnessIndex;
	unsigned int metalnessIndex;

	DirectX::XMFLOAT2 UVScale;
	DirectX::XMFLOAT2 UVOffset;

};

// To be able to access each struct of data within the pixel shader, index locations need to be passed!
// No need to worry about HLSL packing here -> This is a list of indices stored in the root signature
struct DrawingIndices
{
	unsigned int vsVertexBufferIndex;
	// In constant buffer!	
	unsigned int vsConstAllIndex;
	unsigned int vsConstEachIndex;
	unsigned int psConstAllIndex;
	unsigned int psConstEachIndex;
};

// Ray Tracing Bindless Data 
struct RayTracingDrawData 
{
	unsigned int SceneDataCBIndex;
	unsigned int EntityDataDescriptorIndex;
	unsigned int SceneTLASDescriptorIndex;
	unsigned int OutputUAVDescriptorIndex;
};

// Ray Tracing Data for the entire scene -> The inverse view projection matrix and the camera world position
struct RaytracingSceneData 
{
	DirectX::XMFLOAT4X4 InverseViewProjection;
	DirectX::XMFLOAT3 CameraPosition;
	float padding;
};

// Ray Tracing Data for bindless entities -> Need access to the index buffer VIEW, vertex buffer VIEW, and for now, the color of the entity
struct EntityData 
{
	DirectX::XMFLOAT4 Color;

	unsigned int IndexBufferViewIndex;
	unsigned int VertexBufferViewIndex;
	float padding[2];

};