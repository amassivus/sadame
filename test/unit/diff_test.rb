# frozen_string_literal: true

class DiffTest < SadameTest
  def unified(old_text, new_text)
    Sadame::Diff.unified(old_text, new_text, old_label: "a", new_label: "b")
  end

  def test_changes_compares_only_desired_attributes
    changes = Sadame::Diff.changes({ state: "present", mode: "0644" }, { state: "present", mode: "0600", owner: "root" })
    assert_equal 1, changes.size
    assert_equal :mode, changes.first.attribute
    assert_equal "0600", changes.first.from
    assert_equal "0644", changes.first.to
  end

  def test_equal_texts_have_no_diff
    assert_equal "", unified("a\nb\n", "a\nb\n")
    assert_equal "", unified("", "")
  end

  def test_single_line_change
    expected = "--- a\n+++ b\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n"
    assert_equal expected, unified("one\ntwo\nthree\n", "one\nTWO\nthree\n")
  end

  def test_new_file
    assert_equal "--- a\n+++ b\n@@ -0,0 +1,2 @@\n+one\n+two\n", unified("", "one\ntwo\n")
  end

  def test_removed_content
    assert_equal "--- a\n+++ b\n@@ -1 +0,0 @@\n-gone\n", unified("gone\n", "")
  end

  def test_missing_newline_at_end_of_file
    expected = "--- a\n+++ b\n@@ -1 +1 @@\n-x\n\\ No newline at end of file\n+x\n"
    assert_equal expected, unified("x", "x\n")
  end

  def test_context_is_limited_to_three_lines
    old_text = (1..10).map { |n| "#{n}\n" }.join
    new_text = old_text.sub("9\n", "nine\n")
    expected = "--- a\n+++ b\n@@ -6,5 +6,5 @@\n 6\n 7\n 8\n-9\n+nine\n 10\n"
    assert_equal expected, unified(old_text, new_text)
  end

  def test_distant_changes_make_separate_hunks
    old_text = (1..20).map { |n| "#{n}\n" }.join
    new_text = old_text.sub("2\n", "two\n").sub("19\n", "nineteen\n")
    diff = unified(old_text, new_text)
    assert_includes diff, "@@ -1,5 +1,5 @@\n"
    assert_includes diff, "@@ -16,5 +16,5 @@\n"
  end

  def test_close_changes_share_a_hunk
    old_text = (1..12).map { |n| "#{n}\n" }.join
    new_text = old_text.sub("3\n", "three\n").sub("9\n", "nine\n")
    diff = unified(old_text, new_text)
    assert_equal 1, diff.split("\n").count { |line| line.start_with?("@@") }
  end

  def test_insertions_and_deletions_in_the_middle
    expected = "--- a\n+++ b\n@@ -1,4 +1,4 @@\n a\n-b\n c\n+x\n d\n"
    assert_equal expected, unified("a\nb\nc\nd\n", "a\nc\nx\nd\n")
  end
end
