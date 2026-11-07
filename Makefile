# Builds sadame, a single binary: C++ with GNU Guile embedded. The Scheme
# parts of lib/sadame/*.scm are compiled into it, so it runs without the
# source tree.
#
#   make              build/sadame
#   make test         build and run the unit tests
#   make clean
#
# Guile's headers and library come from pkg-config (guile-3.0). When the
# development package is not installed, point GUILE_CFLAGS and GUILE_LIBS
# at them, for example:
#
#   make GUILE_CFLAGS=-I/opt/guile/include/guile/3.0 GUILE_LIBS="-L/opt/guile/lib -lguile-3.0 -lgc"

CXX ?= g++
BUILD := build

GUILE_CFLAGS ?= $(shell pkg-config --cflags guile-3.0 2>/dev/null)
GUILE_LIBS ?= $(shell pkg-config --libs guile-3.0 2>/dev/null)

# -isystem keeps Guile's own headers from reporting warnings of their own.
CXXFLAGS ?= -O2 -g
override CXXFLAGS += -std=c++17 -Wall -Wextra -I$(BUILD) $(patsubst -I%,-isystem %,$(GUILE_CFLAGS))
LDLIBS += $(GUILE_LIBS)

LIB_SOURCES := $(shell find lib -name '*.cpp' | sort)
SCHEME_SOURCES := $(sort $(wildcard lib/sadame/*.scm))
LIB_OBJECTS := $(patsubst %.cpp,$(BUILD)/%.o,$(LIB_SOURCES))
EMBEDDED := $(BUILD)/embedded_scheme.cpp
EMBEDDED_OBJECT := $(BUILD)/embedded_scheme.o

TEST_SOURCES := $(shell find test -name '*_test.cpp' 2>/dev/null | sort) test/support/test_main.cpp
TEST_OBJECTS := $(patsubst %.cpp,$(BUILD)/%.o,$(TEST_SOURCES))

.PHONY: all test clean

all: $(BUILD)/sadame

$(BUILD)/sadame: $(BUILD)/tools/sadame/sadame.o $(LIB_OBJECTS) $(EMBEDDED_OBJECT)
	$(CXX) $^ -o $@ $(LDLIBS)

$(BUILD)/test_runner: $(TEST_OBJECTS) $(LIB_OBJECTS) $(EMBEDDED_OBJECT)
	$(CXX) $^ -o $@ $(LDLIBS)

test: $(BUILD)/test_runner
	$(BUILD)/test_runner

# The Scheme sources as C++ string literals, so lib/sadame/*.scm is the only
# copy. embedded_scheme.hpp tells the rest of the code what is in there.
$(BUILD)/embedded_scheme.hpp:
	@mkdir -p $(BUILD)
	@printf '%s\n' '#pragma once' '#include <cstddef>' \
	  'struct EmbeddedSource { const char *name; const char *text; };' \
	  'extern const EmbeddedSource kEmbeddedSources[];' \
	  'extern const std::size_t kEmbeddedSourceCount;' > $@

$(EMBEDDED): $(SCHEME_SOURCES) $(BUILD)/embedded_scheme.hpp
	@mkdir -p $(BUILD)
	@{ printf '%s\n' '#include "embedded_scheme.hpp"'; \
	   for file in $(SCHEME_SOURCES); do \
	     name=$$(basename $$file .scm); \
	     printf 'static const char kSource_%s[] = R"SCHEME_SOURCE(\n' "$$name"; \
	     cat $$file; \
	     printf ')SCHEME_SOURCE";\n'; \
	   done; \
	   printf 'const EmbeddedSource kEmbeddedSources[] = {\n'; \
	   for file in $(SCHEME_SOURCES); do \
	     name=$$(basename $$file .scm); \
	     printf '  {"%s", kSource_%s},\n' "$$name" "$$name"; \
	   done; \
	   printf '};\n'; \
	   printf 'const std::size_t kEmbeddedSourceCount = sizeof kEmbeddedSources / sizeof kEmbeddedSources[0];\n'; \
	 } > $@

$(EMBEDDED_OBJECT): $(EMBEDDED)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD)/%.o: %.cpp $(BUILD)/embedded_scheme.hpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

clean:
	rm -rf $(BUILD)

-include $(shell find $(BUILD) -name '*.d' 2>/dev/null)
