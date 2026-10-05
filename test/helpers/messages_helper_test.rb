require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  test "relative file links resolve against the session directory and keep their line" do
    link = Nokogiri::HTML5.fragment(markdown("[f](app/x.rb#L12)", cwd: "/repo")).at("a")

    assert_equal "file-link", link["class"]
    assert_equal "/repo/app/x.rb", link["data-file-path"]
    assert_equal "12", link["data-file-line"]
  end

  test "colon line suffixes are understood" do
    link = Nokogiri::HTML5.fragment(markdown("[f](lib/y.go:40:7)", cwd: "/repo")).at("a")

    assert_equal "/repo/lib/y.go", link["data-file-path"]
    assert_equal "40", link["data-file-line"]
  end

  test "a bare filename with a line suffix is a file, not a URL scheme" do
    link = Nokogiri::HTML5.fragment(markdown("[r](README.md:5)", cwd: "/repo")).at("a")

    assert_equal "/repo/README.md", link["data-file-path"]
    assert_equal "5", link["data-file-line"]
  end

  test "plus signs in paths survive decoding" do
    link = Nokogiri::HTML5.fragment(markdown("[c](src/c++/main.cc)", cwd: "/repo")).at("a")

    assert_equal "/repo/src/c++/main.cc", link["data-file-path"]
  end

  test "web links and in-page anchors are left alone" do
    html = markdown("[a](https://example.com) [b](#fix) [c](mailto:x@y.z)", cwd: "/repo")

    assert_not_includes html, "file-link"
    assert_includes html, %(href="https://example.com")
  end

  test "relative links stay untouched without a session directory" do
    assert_not_includes markdown("[f](app/x.rb)"), "file-link"
  end
end
