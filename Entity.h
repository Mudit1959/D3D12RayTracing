#pragma once
#include "Mesh.h"
#include "Material.h"
#include "Transform.h"
#include <memory>
class Entity
{
public:
	Entity(std::shared_ptr<Mesh> mesh, std::shared_ptr<Material> material);
	Entity(std::shared_ptr<Mesh> inMesh);
	std::shared_ptr<Mesh> GetMesh();
	std::shared_ptr<Material> GetMaterial();
	void SetMaterial(std::shared_ptr<Material> m);
	Transform* GetTransform();

private:
	std::shared_ptr<Mesh> mesh;
	std::shared_ptr<Material> material;
	Transform transform;
};

