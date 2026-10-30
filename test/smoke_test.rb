require "minitest/autorun"
require_relative "../lib/chain_explorer"

class SmokeTest < Minitest::Test
  def test_version_is_set
    assert_match(/\A\d+\.\d+\.\d+\z/, ChainExplorer::VERSION)
  end
end
