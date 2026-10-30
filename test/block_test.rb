require "minitest/autorun"
require_relative "../lib/chain_explorer/block"

class BlockTest < Minitest::Test
  def tx(amount)
    ChainExplorer::Transaction.new(sender: "alice", recipient: "bob", amount: amount, timestamp: 1)
  end

  def block(**over)
    ChainExplorer::Block.new(index: 1, timestamp: 2, transactions: [tx(10)],
                             previous_hash: "0" * 64, **over)
  end

  def test_hash_is_deterministic_sha256
    assert_equal block.hash, block.hash
    assert_match(/\A[0-9a-f]{64}\z/, block.hash)
  end

  def test_mining_meets_difficulty
    mined = block.mine!(2)
    assert mined.meets_difficulty?(2)
    assert mined.hash.start_with?("00")
  end

  def test_content_change_changes_hash
    assert block.hash != block(transactions: [tx(11)]).hash
    assert block.hash != block(previous_hash: "1" * 64).hash
  end

  def test_json_round_trip_preserves_hash
    mined = block.mine!(1)
    loaded = ChainExplorer::Block.from_h(mined.to_h)
    assert_equal mined.hash, loaded.hash
    assert_equal mined.nonce, loaded.nonce
  end

  def test_load_rejects_tampered_hash
    hash = block.to_h
    hash["nonce"] = 99
    assert_raises(ArgumentError) { ChainExplorer::Block.from_h(hash) }
  end

  def test_rejects_non_transaction_members
    assert_raises(ArgumentError) { block(transactions: ["not-a-tx"]) }
  end
end
