# frozen_string_literal: true

# sadame lsp describes resources, options and facts with text generated
# from the docs; this fails when the docs changed and the generated file
# was not written again with `rake lsp:reference`.
class LspReferenceTest < SadameTest
  def test_generated_from_the_current_docs
    skip "the generator needs CRuby" unless RUBY_ENGINE == "ruby"

    load File.expand_path("../../script/build/lsp-reference.rb", __dir__)
    assert_equal File.read("lib/sadame/lsp/reference.rb"), LspReference.generate,
                 "lib/sadame/lsp/reference.rb is out of date; run rake lsp:reference"
  end

  RESOURCE_CLASSES = [
    Sadame::PackageResource, Sadame::FileResource, Sadame::LineResource, Sadame::DirectoryResource,
    Sadame::LinkResource, Sadame::ServiceResource, Sadame::ExecResource, Sadame::UserResource,
    Sadame::GroupResource, Sadame::GitResource
  ].freeze

  def test_every_resource_and_its_options_are_described
    assert_equal RESOURCE_CLASSES.map { |klass| klass.type_name }, Sadame::Lsp::Reference::RESOURCES.keys
    Sadame::Lsp::Reference::RESOURCES.each do |name, resource|
      klass = RESOURCE_CLASSES.find { |candidate| candidate.type_name == name }
      expected = (klass.allowed_options + Sadame::Resource::COMMON_OPTIONS).map { |option| option.to_s }.sort
      assert_equal expected, resource["options"].keys.sort, "options of #{name} in docs/resources/#{name}.md"
    end
    assert_equal Sadame::Facts::NAMES.map { |fact| fact.to_s }.sort, Sadame::Lsp::Reference::FACTS.keys.sort
  end
end
