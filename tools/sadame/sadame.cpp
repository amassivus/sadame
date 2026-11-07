// Entry point of the sadame binary. All logic lives in lib/sadame; this file
// builds the command line, starts Guile and turns the return value of the
// CLI into the process exit status.
#include <unistd.h>

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "../../lib/sadame/cli.hpp"
#include "../../lib/sadame/scheme.hpp"
#include "../../lib/sadame/shell.hpp"

extern char **environ;

int main(int argc, char **argv) {
  std::vector<std::string> arguments(argv + 1, argv + argc);

  sadame::CLI::Environment environment;
  for (char **entry = environ; entry && *entry; ++entry) {
    std::string text = *entry;
    std::size_t equals = text.find('=');
    if (equals != std::string::npos) environment.variables[text.substr(0, equals)] = text.substr(equals + 1);
  }
  environment.stdout_tty = ::isatty(STDOUT_FILENO) != 0;

  int status = 2;
  try {
    status = sadame::scheme::with_guile([&]() {
      sadame::Shell shell;
      sadame::CLI cli(arguments, std::cout, std::cerr, shell, environment);
      return cli.run();
    });
  } catch (const std::exception &error) {
    std::cerr << "sadame: could not start: " << error.what() << "\n";
    return 2;
  }
  std::cout.flush();
  return status;
}
