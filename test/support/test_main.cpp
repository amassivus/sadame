// Runs every TEST() case. Run from the repository root, where the fixtures
// are:  build/test_runner [substring of "suite.name"]...
#include <iostream>

#include "../../lib/sadame/scheme.hpp"
#include "test_framework.hpp"

int main(int argc, char **argv) {
  std::vector<std::string> filters(argv + 1, argv + argc);

  return sadame::scheme::with_guile([&]() {
    int run = 0;
    std::vector<std::string> failures;
    for (const test::Case &test_case : test::registry()) {
      std::string full_name = test_case.suite + "." + test_case.name;
      if (!filters.empty()) {
        bool wanted = false;
        for (const std::string &filter : filters) wanted = wanted || full_name.find(filter) != std::string::npos;
        if (!wanted) continue;
      }

      ++run;
      try {
        test_case.body();
        std::cout << "." << std::flush;
      } catch (const std::exception &error) {
        std::cout << "F" << std::flush;
        failures.push_back(full_name + ": " + error.what());
      }
    }

    std::cout << "\n\n";
    for (const std::string &failure : failures) std::cout << "FAILED " << failure << "\n\n";
    std::cout << run << " tests, " << failures.size() << " failures\n";
    return failures.empty() ? 0 : 1;
  });
}
