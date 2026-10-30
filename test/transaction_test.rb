require "minitest/autorun"
require_relative "../lib/chain_explorer/transaction"

class TransactionTest < Minitest::Test
  def tx(**over)
    ChainExplorer::Transaction.new(
      sender: "alice", recipient: "bob", amount: 50, timestamp: 1_700_000_000,
      **over
    )
  end

  def test_id_is_deterministic_sha256
    assert_equal tx.id, tx.id
    assert_match(/\A[0-9a-f]{64}\z/, tx.id)
  end

  def test_any_field_change_changes_id
    assert tx.id != tx(amount: 51).id
    assert tx.id != tx(recipient: "carol").id
    assert tx.id != tx(memo: "rent").id
  end

  def test_rejects_non_positive_amount
    assert_raises(ArgumentError) { tx(amount: 0) }
    assert_raises(ArgumentError) { tx(amount: -5) }
    assert_raises(ArgumentError) { tx(amount: 1.5) }
  end

  def test_rejects_empty_parties
    assert_raises(ArgumentError) { tx(sender: "") }
    assert_raises(ArgumentError) { tx(recipient: nil) }
  end

  def test_json_round_trip_preserves_id
    loaded = ChainExplorer::Transaction.from_h(tx(memo: "hi").to_h)
    assert_equal tx(memo: "hi").id, loaded.id
    assert_equal "hi", loaded.memo
  end

  def test_load_rejects_tampered_id
    hash = tx.to_h
    hash["amount"] = 999
    assert_raises(ArgumentError) { ChainExplorer::Transaction.from_h(hash) }
  end
end
