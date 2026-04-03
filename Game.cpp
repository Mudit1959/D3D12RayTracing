#include "Game.h"
#include "Graphics.h"
#include "BufferStructs.h"
#include "Vertex.h"
#include "Input.h"
#include "PathHelpers.h"
#include "Window.h"
#include "Mesh.h"
#include "Entity.h"
#include "Camera.h"
#include "RayTracing.h"

#include <DirectXMath.h>

// Needed for a helper function to load pre-compiled shader files
#pragma comment(lib, "d3dcompiler.lib")
#include <d3dcompiler.h>

// For the DirectX Math library
using namespace DirectX;

std::vector<std::shared_ptr<Entity>> entities;
std::shared_ptr<Material> wood, onyx, diamond, metal46, metal49, white, red, grey, purple, green;
std::shared_ptr<Camera> camera;
unsigned int lightCount = 0;

float RandomRange(float min, float max) 
{
	return (float)rand() / RAND_MAX * (max - min) + min;
}

// --------------------------------------------------------
// The constructor is called after the window and graphics API
// are initialized but before the game loop begins
// --------------------------------------------------------
Game::Game()
{
	srand((unsigned int)time(0));

	RayTracing::Initialize(Window::Width(), Window::Height(), FixPath(L"RayTracing.cso"));

	//CreateRootSigAndPipelineState();
	CreateGeometry();
	//CreateLights();

	camera = std::make_shared<Camera>(1.4, 3.0f, -16.0f, Window::AspectRatio(), true);
}


// --------------------------------------------------------
// Clean up memory or objects created by this class
// 
// Note: Using smart pointers means there probably won't
//       be much to manually clean up here!
// --------------------------------------------------------
Game::~Game()
{
	// Wait for GPU before shut down
	Graphics::WaitForGPU();
}

// --------------------------------------------------------
// Creates the geometry we're going to draw
// --------------------------------------------------------
void Game::CreateGeometry()
{

	CreateMaterials();
	std::shared_ptr<Mesh> cube = std::make_shared<Mesh>("Cube", FixPath("../../Assets/Meshes/cube.obj").c_str());
	std::shared_ptr<Mesh> cylinder = std::make_shared<Mesh>("Cylinder", FixPath("../../Assets/Meshes/cylinder.obj").c_str());
	std::shared_ptr<Mesh> helix = std::make_shared<Mesh>("Helix", FixPath("../../Assets/Meshes/helix.obj").c_str());
	std::shared_ptr<Mesh> plane = std::make_shared<Mesh>("Plane", FixPath("../../Assets/Meshes/quad.obj").c_str());
	std::shared_ptr<Mesh> quad = std::make_shared<Mesh>("Quad", FixPath("../../Assets/Meshes/quad_double_sided.obj").c_str());
	std::shared_ptr<Mesh> sphere = std::make_shared<Mesh>("Sphere", FixPath("../../Assets/Meshes/sphere.obj").c_str());
	std::shared_ptr<Mesh> torus = std::make_shared<Mesh>("Torus", FixPath("../../Assets/Meshes/torus.obj").c_str());

	entities.push_back(std::make_shared<Entity>(cube, grey)); // Land
	entities.push_back(std::make_shared<Entity>(torus, white));
	
	for (int i = 0; i < 1; i++) 
	{
		entities.push_back(std::make_shared<Entity>(sphere, red));
		entities.push_back(std::make_shared<Entity>(sphere, purple));
		entities.push_back(std::make_shared<Entity>(sphere, green));
		entities.push_back(std::make_shared<Entity>(sphere, white));
		entities.push_back(std::make_shared<Entity>(sphere, red));
	}
	
	

	
	entities[0]->GetTransform()->SetScale(50, 1, 50);
	entities[0]->GetTransform()->SetPosition(0, 0, 0);

	entities[1]->GetTransform()->SetPosition(0, 4, 0);
	
	for (int i = 0; i < 5; i++) 
	{
		float uniformScale = RandomRange(0.5, 1);
		entities[2 + i]->GetTransform()->SetScale(uniformScale, uniformScale, uniformScale);
		entities[2 + i]->GetTransform()->SetPosition(RandomRange(-5, 5), 2 - (1-uniformScale), RandomRange(-5, 5));
	}
	

	// -- CREATE THE DATA BUFFERS FOR EACH ENTITY'S UNIQUE DATA --
	RayTracing::CreateEntityDataBuffer(entities);

	// Ray-Tracing TLAS Creation
	RayTracing::CreateTopLevelAccelerationStructureForScene(entities);

	Graphics::CloseAndExecuteCommandList();
	Graphics::WaitForGPU();
	Graphics::ResetAllocatorAndCommandList(Graphics::SwapChainIndex());

}

void Game::CreateMaterials() 
{
	red = std::make_shared<Material>(DirectX::XMFLOAT3(196/255.0f, 0/255.0f, 0/255.0f), 0.0f, 0); // Reflective red
	grey = std::make_shared<Material>(DirectX::XMFLOAT3(187 / 255.0f, 180 / 255.0f, 180 / 255.0f), 1.0f, 0); // Diffuse Grey
	purple = std::make_shared<Material>(DirectX::XMFLOAT3(162 / 255.0f, 94 / 255.0f, 235 / 255.0f), 1.0f, 1); // Diffuse Purple
	green = std::make_shared<Material>(DirectX::XMFLOAT3(117 / 255.0f, 201 / 255.0f, 120 / 255.0f), 1.0f, 0); // Diffuse Green
	white = std::make_shared<Material>(DirectX::XMFLOAT3(247 / 255.0f, 245 / 255.0f, 245 / 255.0f), 0.0f, 0); // Reflective White
}


void Game::CreateLights() 
{
	Light redDir = {};
	redDir.Direction = DirectX::XMFLOAT3(0.0f, -1.0f, 0.0f);
	redDir.Color = DirectX::XMFLOAT3(1.0f, 0.0f, 0.0f);
	redDir.Intensity = .3f;
	redDir.Type = LIGHT_TYPE_DIRECTIONAL;

	Light whiteDir = {};
	whiteDir.Color = DirectX::XMFLOAT3(1.0f, 1.0f, 1.0f);
	whiteDir.Direction = DirectX::XMFLOAT3(0.0f, 0.0f, 1.0f);
	whiteDir.Intensity = .1f;
	whiteDir.Type = LIGHT_TYPE_DIRECTIONAL;

	lights.push_back(redDir);
	//lights.push_back(whiteDir);
	lightCount += 1;

	
	for (int i = 0; i < 8; i++) 
	{
		Light point = {};
		point.Color = DirectX::XMFLOAT3(RandomRange(0.0f, 1.0f), RandomRange(0.0f, 1.0f), RandomRange(0.0f, 1.0f));
		point.Position = DirectX::XMFLOAT3(RandomRange(-3.5f, 3.5f), RandomRange(-2.0f, 2.0f), RandomRange(-1.0f, 1.0f));
		point.Intensity = RandomRange(0.0f, 2.0f);
		point.Range = RandomRange(0.5f, 3.0f);
		point.Type = LIGHT_TYPE_POINT;

		lights.push_back(point);
		lightCount++;
	}
	

	lights.resize(MAX_LIGHTS);
}

// --------------------------------------------------------
// Handle resizing to match the new window size
//  - Eventually, we'll want to update our 3D camera
// --------------------------------------------------------
void Game::OnResize()
{
	//Resize the viewport and scissor rectangle -> Matters with ImGui
	{
		// Set up the viewport so we render into the correct
		// portion of the render target
		viewport = {};
		viewport.TopLeftX = 0;
		viewport.TopLeftY = 0;
		viewport.Width = (float)Window::Width();
		viewport.Height = (float)Window::Height();
		viewport.MinDepth = 0.0f;
		viewport.MaxDepth = 1.0f;
		// Define a scissor rectangle that defines a portion of
		// the render target for clipping. This is different from
		// a viewport in that it is applied after the pixel shader.
		// We need at least one of these, but we're rendering to
		// the entire window, so it'll be the same size.
		scissorRect = {};
		scissorRect.left = 0;
		scissorRect.top = 0;
		scissorRect.right = Window::Width();
		scissorRect.bottom = Window::Height();
	}
	

	if (Graphics::Device) { RayTracing::ResizeOutputUAV(Window::Width(), Window::Height()); }

	if (camera != NULL) { camera->UpdateProjMatrix(Window::AspectRatio()); }
}


// --------------------------------------------------------
// Update your game here - user input, move objects, AI, etc.
// --------------------------------------------------------
void Game::Update(float deltaTime, float totalTime)
{
	// Example input checking: Quit if the escape key is pressed
	if (Input::KeyDown(VK_ESCAPE))
		Window::Quit();

	camera->Update(deltaTime);
	
	//"auto& to meaningfully modify items in a sequence", such as a vector -> https://stackoverflow.com/questions/29859796/c-auto-vs-auto
	entities[1]->GetTransform()->Rotate(0.5f * deltaTime,0.5f*deltaTime,0.5f*deltaTime);
	for (int i = 0; i < 5; i++)
	{
		if (i % 2 == 0)
		{
			entities[i + 2]->GetTransform()->MoveAbsolute(sin(totalTime) * 0.025 * 3, 0, 0);
		}
		else
		{
			entities[i + 2]->GetTransform()->MoveAbsolute(0, 0, sin(totalTime + 1) * 0.025f * 3);
		}
	}
	
	
}


// --------------------------------------------------------
// Clear the screen, redraw everything, present to the user
// --------------------------------------------------------
void Game::Draw(float deltaTime, float totalTime)
{
	// Grab the current back buffer for this frame
	Microsoft::WRL::ComPtr <ID3D12Resource > currentBackBuffer =
		Graphics::BackBuffers[Graphics::SwapChainIndex()];

	// Resource barrier to be used for transitions during rendering
	{
		D3D12_RESOURCE_BARRIER rb = {};
		rb.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
		rb.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
		rb.Transition.pResource = currentBackBuffer.Get();
		rb.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
	}

	// Rendering here!
	{

		// Raytracing - Recreate the TLAS and then trace it
		{
			RayTracing::CreateTopLevelAccelerationStructureForScene(entities);
			RayTracing::Raytrace(camera, currentBackBuffer, 30, 10);
		}

		// Present
		{
			// Must occur BEFORE present
			Graphics::CloseAndExecuteCommandList();
			Graphics::WaitForGPU();
			// Present the current back buffer and move to the next one
			bool vsync = Graphics::VsyncState();
			Graphics::SwapChain->Present(
				vsync ? 1 : 0,
				vsync ? 0 : DXGI_PRESENT_ALLOW_TEARING);
			Graphics::AdvanceSwapChainIndex(); // Always two buffers are needed - one to calculate rendering on, one to present to the user
			// Waits for the GPU to be done -> Handled by multi-frame sync in AdvanceSwapChainIndex()!
			// Resets the command list & allocator
			//
			
			Graphics::ResetAllocatorAndCommandList(Graphics::SwapChainIndex());
		}
	}
}


	




