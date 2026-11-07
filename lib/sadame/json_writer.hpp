#pragma once

#include <string>

#include "value.hpp"

namespace sadame {

// Writes the --json output. Using our own small generator keeps key order
// and indentation under our control.
namespace JsonWriter {

std::string generate(const Value &value);
std::string write_string(const std::string &text);

}  // namespace JsonWriter

// Parses JSON text into a Value: objects become maps, null becomes nil.
// Throws Error with a message that says where the text is wrong.
namespace JsonParser {

Value parse(const std::string &text);

}  // namespace JsonParser

}  // namespace sadame
