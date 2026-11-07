#pragma once

#include <string>

#include "value.hpp"

namespace sadame {

// Writes values as Scheme source, to show vars in `sadame hosts` and to send
// them between processes: strings, numbers, booleans, symbols, lists and
// association lists.
//
//   SchemeLiteral::dump(vars)   // '((workers . 4) (tls . #t))
namespace SchemeLiteral {

std::string dump(const Value &value);

}  // namespace SchemeLiteral
}  // namespace sadame
