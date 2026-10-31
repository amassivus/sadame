# frozen_string_literal: true

# Load order for CRuby. mrbgem.rake reads the require_relative lines below to
# compile the same files, in the same order, into the mruby binary. Library
# code must never call require: the mruby build has no stdlib.
require_relative "sadame/version"
require_relative "sadame/errors"
require_relative "sadame/shell"
require_relative "sadame/platform"
