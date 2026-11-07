#pragma once

#include <string>

namespace sadame {

// Shell-style wildcard matching for --limit: "*" matches any run of
// characters (including none), "?" exactly one. Everything else matches
// itself.
namespace Glob {

bool match(const std::string &pattern, const std::string &text);

}  // namespace Glob
}  // namespace sadame
