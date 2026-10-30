require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "stringio"
require_relative "../lib/chain_explorer/cli"

class CliTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "chain.json")
    chain = ChainExplorer::Chain.new(difficulty: 1)
    @alice_bob = ChainExplorer::Transaction.new(sender: "alice", recipient: "bob",
                                                amount: 50, timestamp: 1_700_000_001)
    @bob_carol = ChainExplorer::Transaction.new(sender: "bob", recipient: "carol",
                                                amount: 20, timestamp: 1_700_000_002)
    chain.add_block([@alice_bob, @bob_carol], timestamp: 1_700_000_010)
    @chain = chain
    chain.save(@path)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    code = ChainExplorer::CLI.new(out: out, err: err).run(argv)
    [code, out.string, err.string]
  end

  def test_help_needs_no_chain
    code, out, _err = run_cli("--help")
    assert_equal 0, code
    assert_includes out, "Usage:"
    assert_includes out, "address"
  end

  def test_missing_chain_flag_is_usage_error
    code, _out, err = run_cli("summary")
    assert_equal 2, code
    assert_includes err, "--chain FILE is required"
  end

  def test_missing_chain_file_is_error
    code, _out, err = run_cli("--chain", File.join(@dir, "nope.json"), "summary")
    assert_equal 1, code
    assert_includes err, "not found"
  end

  def test_summary_text
    code, out, _err = run_cli("--chain", @path, "summary")
    assert_equal 0, code
    assert_includes out, "Height: 1"
    assert_includes out, "Transactions: 2"
    assert_includes out, "Valid: true"
  end

  def test_validate_text_valid
    code, out, _err = run_cli("--chain", @path, "validate")
    assert_equal 0, code
    assert_includes out, "Chain is valid"
  end

  def test_blocks_lists_every_block
    code, out, _err = run_cli("--chain", @path, "blocks")
    assert_equal 0, code
    assert_includes out, "Block 0"
    assert_includes out, "Block 1"
    assert_includes out, "txs: 2"
  end

  def test_block_by_index
    code, out, _err = run_cli("--chain", @path, "block", "1")
    assert_equal 0, code
    assert_includes out, "Block 1"
    assert_includes out, "alice -> bob  50"
  end

  def test_block_by_hash_prefix
    hash = @chain.blocks[1].hash
    code, out, _err = run_cli("--chain", @path, "block", hash[0, 12])
    assert_equal 0, code
    assert_includes out, "Block 1"
    assert_includes out, hash
  end

  def test_block_unknown_index_is_error
    code, _out, err = run_cli("--chain", @path, "block", "99")
    assert_equal 1, code
    assert_includes err, "no block"
  end

  def test_block_short_prefix_is_usage_error
    code, _out, err = run_cli("--chain", @path, "block", "abc")
    assert_equal 2, code
    assert_includes err, "at least 8 characters"
  end

  def test_tx_by_full_id
    code, out, _err = run_cli("--chain", @path, "tx", @alice_bob.id)
    assert_equal 0, code
    assert_includes out, "alice -> bob  50"
    assert_includes out, "Block: 1"
  end

  def test_tx_by_prefix
    code, out, _err = run_cli("--chain", @path, "tx", @bob_carol.id[0, 10])
    assert_equal 0, code
    assert_includes out, "bob -> carol  20"
  end

  def test_tx_unknown_is_error
    code, _out, err = run_cli("--chain", @path, "tx", "0" * 64)
    assert_equal 1, code
    assert_includes err, "no transaction"
  end

  def test_address_balance_and_history
    code, out, _err = run_cli("--chain", @path, "address", "bob")
    assert_equal 0, code
    assert_includes out, "Balance: 30"
    assert_includes out, "received 50"
    assert_includes out, "sent 20"
  end

  def test_address_with_no_transactions
    code, out, _err = run_cli("--chain", @path, "address", "nobody")
    assert_equal 0, code
    assert_includes out, "Balance: 0"
    assert_includes out, "Transactions: 0"
  end

  def test_unknown_command_is_usage_error
    code, _out, err = run_cli("--chain", @path, "explode")
    assert_equal 2, code
    assert_includes err, "unknown command"
  end

  def test_json_summary_and_address
    _code, out, _err = run_cli("--chain", @path, "--json", "summary")
    assert_equal 1, JSON.parse(out)["height"]
    _code, out, _err = run_cli("--json", "--chain", @path, "address", "bob")
    parsed = JSON.parse(out)
    assert_equal 30, parsed["balance"]
    assert_equal 2, parsed["transactions"].length
  end

  def test_json_block_and_tx
    _code, out, _err = run_cli("--chain", @path, "--json", "block", "1")
    assert_equal 1, JSON.parse(out)["index"]
    _code, out, _err = run_cli("--chain", @path, "--json", "tx", @alice_bob.id)
    parsed = JSON.parse(out)
    assert_equal 50, parsed["amount"]
    assert_equal 1, parsed["block_index"]
  end
end
