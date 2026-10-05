require "test_helper"

class RunsHelperTest < ActionView::TestCase
  test "model labels" do
    assert_equal "Opus 5.5", model_label("claude-opus-5-5")
    assert_equal "Opus 5.5 1M", model_label("claude-opus-5-5[1m]")
    assert_equal "Haiku 4.5", model_label("claude-haiku-4-5-20251001")
    assert_equal "Sonnet", model_label("sonnet")
  end
end
