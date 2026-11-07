#pragma once

#include <memory>

#include "package_managers/base.hpp"
#include "platform.hpp"

namespace sadame {
namespace PackageManagers {

// The supported package manager names, in the order they are listed in
// messages.
const std::vector<std::string> &all();

// The package manager for platform, or a ResourceError when there is none.
std::unique_ptr<Base> for_platform(const Platform &platform, Shell &shell);

}  // namespace PackageManagers
}  // namespace sadame
