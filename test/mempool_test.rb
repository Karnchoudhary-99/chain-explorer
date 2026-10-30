require "minitest/autorun"
require_relative "../lib/chain_explorer/mempool"

class MempoolTest < Minitest::Test
  def tx(amount, ts)
    ChainExplorer::Transaction.new(sender: "alice", recipient: "bob", amount: amount, timestamp: ts)
  end

  def test_add_and_drain_in_timestamp_order
    pool = ChainExplorer::Mempool.new
    pool.add(tx(10, 30))
    pool.add(tx(20, 10))
    assert_equal [20, 10], pool.to_a.map(&:amount)
    assert_equal 2, pool.size
    refute pool.empty?
  end

  def test_rejects_duplicates_and_non_transactions
    pool = ChainExplorer::Mempool.new
    pool.add(tx(10, 1))
    assert_raises(ArgumentError) { pool.add(tx(10, 1)) }
    assert_raises(ArgumentError) { pool.add("not-a-tx") }
  end

  def test_remove_and_clear
    pool = ChainExplorer::Mempool.new
    t = tx(10, 1)
    pool.add(t)
    pool.remove(t.id)
    refute pool.include?(t.id)
    pool.add(t)
    pool.clear
    assert pool.empty?
  end
end
