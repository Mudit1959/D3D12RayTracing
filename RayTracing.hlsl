#define PI 3.141592654f

//Random value
float random(float2 s)
{
    return frac(sin(dot(s, float2(12.9898, 78.233))) * 43758.5453123);
}

/// Returns a random vector 2
float2 random2(float2 uv)
{
    return float2(random(uv), random(uv.yx));

}

// Returns a random vector within a hemisphere
float3 RandomCosineWeightedHemisphere(float u0, float u1, float3 unitNormal)
{
    float a = u0 * 2 - 1;
    float b = sqrt(1 - a * a);
    float phi = 2.0f * PI * u1;
    float x = unitNormal.x + b * cos(phi);
    float y = unitNormal.y + b * sin(phi);
    float z = unitNormal.z + a;
    return float3(x, y, z);
}

// === Structs ===

// Layout of data in the vertex buffer
struct Vertex
{
    float3 localPosition;
    float2 uv;
    float3 normal;
    float3 tangent;
};

// Payload for rays (data that is "sent along" with each ray during raytrace)
// Note: This should be as small as possible, and must match our C++ size definition
struct RayPayload
{
    float3 Color;
    uint RayIndex; // NOT Ray'S' -> Used to randomize bounce
    uint RecursionDepth; // Need to keep track of the collision we're on
};

// Note: We'll be using the built-in BuiltInTriangleIntersectionAttributes struct
// for triangle attributes, so no need to define our own.  It contains a single float2.

// === Constant buffers ===

cbuffer DrawData : register(b0)
{
    uint SceneDataCBIndex;
    uint EntityDataDescriptorIndex;
    uint SceneTLASDescriptorIndex;
    uint OutputUAVDescriptorIndex;
};

struct RaytracingSceneData
{
    float4x4 InverseViewProjection;
    
    float3 CameraPosition;
    uint RaysPerPixel; // How many rays should be launched for each pixel?
    
    uint SetRecursionDepth; // How many collisions should a ray go through
    float padding[3];
    
};

struct EntityData // Needs to follow 16 byte packing rules
{
    float4 ColorRoughness;
    
    uint IndexBufferViewIndex;
    uint VertexBufferViewIndex;
    float padding[2];
    
};


/* === Resources ===
// Output UAV 
RWTexture2D<float4> OutputColor : register(u0);

// The actual scene we want to trace through (a TLAS)
RaytracingAccelerationStructure SceneTLAS : register(t0);

// Geometry buffers
StructuredBuffer<uint> IndexBuffer : register(t1);
StructuredBuffer<Vertex> VertexBuffer : register(t2);
*/

// === Helpers ===

// Barycentric interpolation of data from the triangle's vertices
Vertex InterpolateVertices(uint triangleIndex, float2 barycentrics)
{
    StructuredBuffer<EntityData> b = ResourceDescriptorHeap[EntityDataDescriptorIndex];
    EntityData data = b[InstanceIndex()];
    
    StructuredBuffer<uint> IndexBuffer = ResourceDescriptorHeap[data.IndexBufferViewIndex];
    StructuredBuffer<Vertex> VertexBuffer = ResourceDescriptorHeap[data.VertexBufferViewIndex];
    
	// Grab the 3 indices for this triangle
    uint firstIndex = triangleIndex * 3;
    uint indices[3];
    indices[0] = IndexBuffer[firstIndex + 0];
    indices[1] = IndexBuffer[firstIndex + 1];
    indices[2] = IndexBuffer[firstIndex + 2];

	// Grab the 3 corresponding vertices
    Vertex verts[3];
    verts[0] = VertexBuffer[indices[0]];
    verts[1] = VertexBuffer[indices[1]];
    verts[2] = VertexBuffer[indices[2]];
	
	// Calculate the barycentric data for vertex interpolation
    float3 barycentricData = float3(
		1.0f - barycentrics.x - barycentrics.y,
		barycentrics.x,
		barycentrics.y);
	
	// Loop through the barycentric data and interpolate
    Vertex finalVert = (Vertex) 0;
    for (uint i = 0; i < 3; i++)
    {
        finalVert.localPosition += verts[i].localPosition * barycentricData[i];
        finalVert.uv += verts[i].uv * barycentricData[i];
        finalVert.normal += verts[i].normal * barycentricData[i];
        finalVert.tangent += verts[i].tangent * barycentricData[i];
    }
    return finalVert;
}


// Calculates an origin and direction from the camera for specific pixel indices
RayDesc CalcRayFromCamera(float2 rayIndices, float3 camPos, float4x4 invVP)
{
	// Offset to the middle of the pixel
    float2 pixel = rayIndices + 0.5f;
    float2 screenPos = pixel / DispatchRaysDimensions().xy * 2.0f - 1.0f;
    screenPos.y = -screenPos.y;

	// Unproject the coords
    float4 worldPos = mul(invVP, float4(screenPos, 0, 1));
    worldPos.xyz /= worldPos.w;

	// Set up the ray
    RayDesc ray;
    ray.Origin = camPos.xyz;
    ray.Direction = normalize(worldPos.xyz - ray.Origin);
    ray.TMin = 0.01f;
    ray.TMax = 1000.0f;
    return ray;
}


// === Shaders ===

// Ray generation shader - Launched once for each ray we want to generate
// (which is generally once per pixel of our output texture)
[shader("raygeneration")]
void RayGen()
{
    // Constant buffer needs to be accessed for scene level data - Inverse Projection matrix and Camera Position
    ConstantBuffer<RaytracingSceneData> rd = ResourceDescriptorHeap[SceneDataCBIndex];
    
    // Get the ray indices
    uint2 rayIndices = DispatchRaysIndex().xy;
    
    // -- PATH TRACER --
    // Works on the principle of launching several rays, that each continue on for a few collisions, before returning back an answer. 
    // Average the data returned by the rays to get a color. 
    
    // For averaging, first need to store the sum of the colors returned
    float3 totalColor = float3(0, 0, 0);
    
    // For each pixel launch several rays
    for (int i = 0; i < rd.RaysPerPixel; i++)
    {
        float2 adjustedIndices = (float2) rayIndices;
        float2 ray01 = (float) i / rd.RaysPerPixel;
        adjustedIndices += random2(rayIndices.xy * ray01);
        
        // Calculate the ray from the camera through a particular
        // pixel of the output buffer using this shader's indices
            RayDesc ray = CalcRayFromCamera(
	        adjustedIndices,
	        rd.CameraPosition,
	        rd.InverseViewProjection);

        // Set up the payload for the ray
        // This initializes the struct to all zeros
        RayPayload payload = (RayPayload) 0;
        payload.Color = float3(1, 1, 1); // Need to multiply later, so 1 not 0
        payload.RayIndex = i;
        payload.RecursionDepth = 0;
        
        RaytracingAccelerationStructure SceneTLAS = ResourceDescriptorHeap[SceneTLASDescriptorIndex];

        // Perform the ray trace for this ray
            TraceRay(
	        SceneTLAS,
	        RAY_FLAG_NONE,
	        0xFF,
	        0,0,0,
	        ray,
	        payload);
        
        totalColor += payload.Color;
    }
    
	

	// Set the final color of the buffer
    // RW - Read Write 
    RWTexture2D<float4> OutputColor = ResourceDescriptorHeap[OutputUAVDescriptorIndex];
    OutputColor[rayIndices] = float4(pow(totalColor/rd.RaysPerPixel, 1.0/2.2f), 1); // Gamma correction
}


// Miss shader - What happens if the ray doesn't hit anything?
[shader("miss")]
void Miss(inout RayPayload payload)
{
	// Nothing was hit, so return any color for now.
	// Ideally this is where we would do skybox stuff!
    //payload.Color = float3(0.4f, 0.6f, 0.75f);
    
    // --- Taken from Chris Cascioli - LINEAR Hemispheric gradient ---
    
    // Define the top and bottom colors of the hemisphere
    float3 topColor = float3(0.3f, 0.5f, 0.95f);
    float3 bottomColor = float3(1, 1, 1);
    
    // Dot product to achieve a gradient
    // Dot product is a projection of one vector onto another - cos of the angle between the vectors
    // If it's looking to the horizon - angle is 0 - cos is 1
    // Perpendicular/Straight up - angle is 90 - cos is 0
    float interp = dot(normalize(WorldRayDirection()), float3(0, 1, 0)) * 0.5f + 0.5f;
    
    // Lerp can be used for float3 as well!
    // First the bottom 
    float3 skyColor = lerp(bottomColor, topColor, interp);
    
    payload.Color *= skyColor;

}

// Closest hit shader - Runs the first time a ray hits anything
[shader("closesthit")]
void ClosestHit(inout RayPayload payload, BuiltInTriangleIntersectionAttributes hitAttributes)
{
	/* Get the interpolated vertex data
    Vertex interpolatedVert = InterpolateVertices(
		PrimitiveIndex(),
		hitAttributes.barycentrics);

	// Use the resulting data to set the final color
	// Note: Here is where we would do actual shading!
    payload.Color = interpolatedVert.normal;*/
    
    // Fetch the recursion depth from constant buffer
    
    
    // If a ray has just been bouncing between two objects, that part is in shadow
    if (payload.RecursionDepth == 10)
    {
        payload.Color = float3(0, 0, 0);
        return;
    }
    
    // What has the ray hit?
    StructuredBuffer<EntityData> b = ResourceDescriptorHeap[EntityDataDescriptorIndex];
    EntityData data = b[InstanceIndex()];
    
    // How is the color of the ray affected now?
    payload.Color *= data.ColorRoughness.rgb;
    
    // Get the exact hit point
    // Done by finding the triangle hit, and interpolating between vertices to get a point within the triangle
    Vertex hit = InterpolateVertices(
		PrimitiveIndex(),
		hitAttributes.barycentrics);
    // The normal is required for generating the next ray!
    // Needs to be converted to world space
    // Just need a 3x3 matrix since we're working with a 3 dimensional vector
    float3 normalWS = normalize(mul(hit.normal, (float3x3) ObjectToWorld4x3()));
    
    // -- GENERATE A RANDOM DIRECTION --
    // To prevent generating the same results when calling random
    // Need to create a unique ID for this ray
    // Done using the recursion depth, the uv value of the pixel on screen(0-1), and knowing which ray number is being traced
    
    float2 pixelUV = (float2) DispatchRaysIndex().xy / DispatchRaysDimensions().xy;
    // Add 1 to recursion depth, because we always begin at 0 -> can't have pixelUV be 0,0!
    // RayTCurrent() -> the scalar value multiplied by the ray direction to get the hit point?
    float2 rng = random2(pixelUV * (payload.RecursionDepth + 1) + payload.RayIndex + RayTCurrent());
    
    
    // -- CALCULATE RAY DIRECTION --
    // Linearly interpolate between a perfect specular reflection and a diffused reflection
    float3 specularRefl = reflect(WorldRayDirection(), normalWS);
    float3 diffusedRefl = RandomCosineWeightedHemisphere(random(rng), random(rng.yx), normalWS); // Random bounce from surface
    float3 resultDir = normalize(lerp(specularRefl, diffusedRefl, data.ColorRoughness.a)); // DON'T FORGET TO NORMALIZE 
    
    // -- MAKE A NEW RAY --
    RayDesc ray;
    ray.Direction = resultDir;
    ray.Origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
    ray.TMin = 0.0001f; // Offset just by a little to prevent the ray from starting within the object!
    ray.TMax = 1000.0f; //Arbitrarily large number
    
    payload.RecursionDepth++; // Need to increase recursionDepth
    
    RaytracingAccelerationStructure SceneTLAS = ResourceDescriptorHeap[SceneTLASDescriptorIndex];
    TraceRay(
        SceneTLAS, // What is the top level acceleration structure to be used
        RAY_FLAG_NONE, // Any flags?
        0xFF,
        0, 0, 0, // Masks & Offsets
        ray, // Nature of the ray being launched
        payload // What set of data will be edited?
    );
    
    //payload.Color = data.Color.rgb;
}

// Closest hit shader - Runs the first time a ray hits anything
[shader("closesthit")]
void ClosestHitEmmissive(inout RayPayload payload, BuiltInTriangleIntersectionAttributes hitAttributes)
{
    // If hitting a bright object -> just multiply the resulting color with a very bright attenuation of the light's color
    // Brighter means multiplying all the components of a color by a factor of > 1
    
    StructuredBuffer<EntityData> buffer = ResourceDescriptorHeap[EntityDataDescriptorIndex];
    EntityData data = buffer[InstanceIndex()];
    
    payload.Color *= data.ColorRoughness.rgb * 2;

}