#include "ShaderInclude.hlsli"

cbuffer BindlessData : register(b0)
{
    uint vsVertexBufferIndex;
    uint vsConstAllIndex;
    uint vsConstEachIndex;
    uint psConstAllIndex;
    uint psConstEachIndex;
}

//Texture2D AllTextures[ ] : register(t0, space0); - Old Bindless

struct PSConstantsEach
{
    unsigned int albedoIndex;
    unsigned int normalIndex;
    unsigned int roughnessIndex;
    unsigned int metalnessIndex;

    float2 UVScale;
    float2 UVOffset;
};

struct PSConstantsAll
{

    float3 cameraWorldPos;
    int numLights;

    Light lights[MAX_LIGHTS];
};

SamplerState BasicSampler : register(s0);

// --------------------------------------------------------
// The entry point (main method) for our pixel shader
// 
// - Input is the data coming down the pipeline (defined by the struct)
// - Output is a single color (float4)
// - Has a special semantic (SV_TARGET), which means 
//    "put the output of this into the current render target"
// - Named "main" because that's the default the shader compiler looks for
// --------------------------------------------------------
float4 main(VertexToPixel input) : SV_TARGET
{
    ConstantBuffer<PSConstantsAll> psAll = ResourceDescriptorHeap[psConstAllIndex];
    ConstantBuffer<PSConstantsEach> psEach = ResourceDescriptorHeap[psConstEachIndex];
    
    Texture2D Albedo = ResourceDescriptorHeap[psEach.albedoIndex];
    Texture2D NormalMap = ResourceDescriptorHeap[psEach.normalIndex];
    Texture2D RoughnessMap = ResourceDescriptorHeap[psEach.roughnessIndex];
    Texture2D MetalnessMap = ResourceDescriptorHeap[psEach.metalnessIndex];
    
    // -- RENORMALIZING AND SCALING NORMALS AND UV --
    input.uv = input.uv * psEach.UVScale + psEach.UVOffset;
    input.normal = normalize(input.normal);
    
    float3 total = float3(0.0f, 0.0f, 0.0f);
    
    // -- GAMMA CORRECT SURFACE(ALBEDO) COLOR --
    float3 surfaceColor = Albedo.Sample(BasicSampler, input.uv).rgb;
    surfaceColor = pow(surfaceColor, 2.2); // Remove gamma correction from texture
    
    // -- SAMPLING ROUGHNESS AND METALNESS(f0) --
    float roughness = RoughnessMap.Sample(BasicSampler, input.uv).r;
    float metalness = MetalnessMap.Sample(BasicSampler, input.uv).r;
    float3 f0 = lerp(0.04, surfaceColor.rgb, metalness);
    //return float4(metalness, 0.0f, 0.0f, 1.0f);
    
    
    // -- SAMPLE NORMAL MAP, CHANGE NORMALS TO ACCOUNT FOR SURFACE UNEVENENESS -- 
    float3 finalNormal;
    finalNormal = normalize(NormalMap.Sample(BasicSampler, input.uv).xyz * 2.0f - 1.0f); // First unpack the normal map's normal
    //return float4(finalNormal, 1.0f);
    
    float3 T, B, N;
    N = input.normal;
    T = normalize(input.tangent - dot(input.tangent, N) * N);
    B = cross(T, N);
    
    float3x3 TBN = float3x3(T, B, N);
    finalNormal = mul(finalNormal, TBN);
    input.normal = finalNormal; // Reassigned incoming data to hold new normal
    
    // -- OTHER VARIABLES
    float3 toCamera, halfVector, toLight, add;
    toCamera = normalize(psAll.cameraWorldPos - input.worldPos);
    
    for (int i = 0; i < psAll.numLights; i++)
    {
        Light light = psAll.lights[i];
        switch (light.Type)
        {
            
            case LIGHT_TYPE_DIRECTIONAL: //0
                toLight = normalize(-light.Direction);
                halfVector = (toLight + toCamera) / 2;
                
                add = DiffuseEnergyConserve(DiffuseLambertPBR(input.normal, toLight, surfaceColor),
                                                Fresnel(toCamera, halfVector, f0),
                                                metalness);
                add += CookTorranceBRDF(toLight, toCamera, halfVector, input.normal, roughness, f0);
            
                add *= light.Color * light.Intensity;
                
                total += add;
                break;
            
            case LIGHT_TYPE_POINT: //1
                // Point lights emit in all directions, so we will depend on the range and position of the light
                toLight = normalize(light.Position - input.worldPos);
                halfVector = normalize(toLight + toCamera) / 2;
                
                add = DiffuseEnergyConserve(DiffuseLambertPBR(input.normal, toLight, surfaceColor),
                                                Fresnel(toCamera, halfVector, f0),
                                                metalness);
                add += CookTorranceBRDF(toLight, toCamera, halfVector, input.normal, roughness, f0);
            
                add *= Attenuate(light, input.worldPos);
                add *= light.Color * light.Intensity;
            
                total += add;
            
                break;
            
            case LIGHT_TYPE_SPOT: //2
                // Spot lights emit light in a conical manner, so we will depend on range, position, and angles!
                toLight = normalize(light.Position - input.worldPos);
                halfVector = normalize(toLight + toCamera) / 2;
            
                add = DiffuseEnergyConserve(DiffuseLambertPBR(input.normal, toLight, surfaceColor),
                                               Fresnel(toCamera, halfVector, f0),
                                                metalness);
                add += CookTorranceBRDF(toLight, toCamera, halfVector, input.normal, roughness, f0);
            
                
            
                float surfaceCos = saturate(dot(-toLight, light.Direction));
                float cosOuter = cos(light.SpotOuterAngle);
                float cosInner = cos(light.SpotInnerAngle);
                float fallOff = cosOuter - cosInner;
            
                float spotTerm = saturate((cosOuter - surfaceCos) / fallOff);
                add *= spotTerm;
                
                add *= Attenuate(light, input.worldPos);
                add *= light.Color * light.Intensity;
                
                total += add;
                
                break;
            
        }
    }
    
    total = pow(total, 1.0f / 2.2f); // Gamma correct final color
    return float4(total, 1.0f);
    
}