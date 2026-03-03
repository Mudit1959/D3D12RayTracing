#include "ShaderInclude.hlsli"

cbuffer BindlessData : register(b0)
{
    uint vsVertexBufferIndex;
    uint vsConstAllIndex;
    uint vsConstEachIndex;
    uint psConstAllIndex;
    uint psConstEachIndex;
}

/* Struct representing a single vertex worth of data -- NOT IN BINDLESS
// - This should match the vertex definition in our C++ code
// - By "match", I mean the size, order and number of members
// - The name of the struct itself is unimportant, but should be descriptive
// - Each variable must have a semantic, which defines its usage
struct VertexShaderInput
{ 
	// Data type
	//  |
	//  |   Name          Semantic
	//  |    |                |
	//  v    v                v
	float3 localPosition	: POSITION;     // XYZ position
    float2 UV				: TEXCOORD;	// UV Texture Coordinate (0-1)
	float3 Normal			: NORMAL;       // Normal
    float3 Tangent			: TANGENT;		// Tangent
};
*/

struct VSConstantsAll
{
    float4x4 view;
    float4x4 proj;
};

struct VSConstantsEach
{
    float4x4 world;
    float4x4 worldInv;
};

struct Vertex
{
    float3 Position; // The local position of the vertex
    float2 UV; // The UV Texture Coordinates of the vertex (0-1)
    float3 Normal;
    float3 Tangent;
};

// --------------------------------------------------------
// The entry point (main method) for our vertex shader
// 
// - Input is exactly one vertex worth of data (defined by a struct)
// - Output is a single struct of data to pass down the pipeline
// - Named "main" because that's the default the shader compiler looks for
// --------------------------------------------------------
VertexToPixel main(uint vertexID : SV_VertexID )
{
    ConstantBuffer<VSConstantsAll> vsAllData = ResourceDescriptorHeap[vsConstAllIndex];
    ConstantBuffer<VSConstantsEach> vsEachData = ResourceDescriptorHeap[vsConstEachIndex];
    StructuredBuffer<Vertex> vbBuffer = ResourceDescriptorHeap[vsVertexBufferIndex];
    
    Vertex v = vbBuffer[vertexID];
	
	// Set up output struct
    VertexToPixel output;

	// Here we're essentially passing the input position directly through to the next
	// stage (rasterizer), though it needs to be a 4-component vector now.  
	// - To be considered within the bounds of the screen, the X and Y components 
	//   must be between -1 and 1.  
	// - The Z component must be between 0 and 1.  
	// - Each of these components is then automatically divided by the W component, 
	//   which we're leaving at 1.0 for now (this is more useful when dealing with 
	//   a perspective projection matrix, which we'll get to in the future).
    float4x4 wvp = mul(vsAllData.proj, mul(vsAllData.view, vsEachData.world));
    output.screenPosition = mul(wvp, float4(v.Position, 1.0f));
    output.normal = mul((float3x3) vsEachData.worldInv, v.Normal);
    output.tangent = mul((float3x3) vsEachData.world, v.Normal);
    output.worldPos = mul(vsEachData.world, float4(v.Position, 1.0f)).xyz;
    output.uv = v.UV;
	

	// Pass the color through 
	// - The values will be interpolated per-pixel by the rasterizer
	// - We don't need to alter it here, but we do need to send it to the pixel shader
	//output.color = colourTint;

	// Whatever we return will make its way through the pipeline to the
	// next programmable stage we're using (the pixel shader for now)
    return output;
}