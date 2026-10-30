require "minitest/autorun"
require "tmpdir"
require_relative "../lib/chain_explorer/chain"

class ChainTest < Minitest::Test
  def tx(sender, recipient, amount, ts = 1)
    ChainExplorer::Transaction.new(sender: sender, recipient: recipient, amount: amount, timestamp: ts)
  end

  def chain(difficulty: 1)
    ChainExplorer::Chain.new(difficulty: difficulty)
  end

  def test_genesis_only_chain_is_valid
    assert chain.valid?
    assert_equal 0, chain.height
  end

  def test_add_block_links_and_mines
    c = chain
    block = c.add_block([tx("alice", "bob", 30)], timestamp: 10)
    assert_equal 1, block.index
    assert_equal c.blocks[0].hash, block.previous_hash
    assert block.meets_difficulty?(1)
    assert c.valid?
    assert_equal 1, c.height
  end

  def test_tampered_block_is_detected
    c = chain
    c.add_block([tx("alice", "bob", 30)], timestamp: 10)
    # Swap a block object for one with the same stored hash fields but
    # different contents: rebuild via from_h with a tampered amount and
    # a forged hash field is rejected on load, so instead tamper by
    # replacing the block with a mined block whose previous hash is wrong.
    bad = ChainExplorer::Block.new(index: 1, timestamp: 10, transactions: [tx("alice", "bob", 31)],
                                   previous_hash: "f" * 64).mine!(1)
    c.blocks[1] = bad
    refute c.valid?
    assert c.problems.any? { |p| p.include?("previous hash") }
  end

  def test_duplicate_transaction_is_detected
    c = chain
    same = tx("alice", "bob", 30)
    c.add_block([same], timestamp: 10)
    c.add_block([same], timestamp: 20)
    refute c.valid?
    assert c.problems.any? { |p| p.include?("duplicate") }
  end

  def test_find_block_transaction_and_balance
    c = chain
    c.add_block([tx("alice", "bob", 30), tx("bob", "carol", 10)], timestamp: 10)
    assert_equal 1, c.find_block(index: 1).index
    assert_equal c.blocks[1].hash, c.find_block(hash: c.blocks[1].hash).hash
    assert_nil c.find_block(index: 99)
    block, found = c.find_transaction(c.blocks[1].transactions[0].id)
    assert_equal 1, block.index
    assert_equal 30, found.amount
    assert_nil c.find_transaction("0" * 64)
    assert_equal(-30, c.balance("alice"))
    assert_equal 20, c.balance("bob")
    assert_equal 10, c.balance("carol")
    assert_equal 2, c.transactions_for("bob").length
  end

  def test_backwards_timestamp_is_detected
    c = chain
    c.add_block([tx("alice", "bob", 30)], timestamp: 100)
    bad = ChainExplorer::Block.new(index: 2, timestamp: 50, transactions: [],
                                   previous_hash: c.blocks[1].hash).mine!(1)
    c.blocks << bad
    refute c.valid?
    assert c.problems.any? { |p| p.include?("timestamp") }
  end

  def test_summary_reports_height_transactions_and_validity
    c = chain
    c.add_block([tx("alice", "bob", 30)], timestamp: 10)
    summary = c.summary
    assert_equal 1, summary["height"]
    assert_equal 2, summary["blocks"]
    assert_equal 1, summary["transactions"]
    assert_equal true, summary["valid"]
    assert_equal c.blocks.last.hash, summary["latest_hash"]
  end

  def test_mine_pending_drains_pool_into_block
    c = chain
    pool = ChainExplorer::Mempool.new
    pool.add(tx("alice", "bob", 30, 5))
    pool.add(tx("bob", "carol", 10, 6))
    block = c.mine_pending(pool, timestamp: 10)
    assert_equal 1, block.index
    assert_equal [30, 10], block.transactions.map(&:amount)
    assert pool.empty?
    assert c.valid?
    assert_raises(ArgumentError) { c.mine_pending(pool, timestamp: 20) }
  end

  def test_save_and_load_round_trip
    c = chain
    c.add_block([tx("alice", "bob", 30)], timestamp: 10)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "chain.json")
      c.save(path)
      loaded = ChainExplorer::Chain.load(path)
      assert loaded.valid?
      assert_equal c.blocks.map(&:hash), loaded.blocks.map(&:hash)
    end
  end

  def test_save_and_load_preserves_balances
    c = chain
    c.add_block([tx("alice", "bob", 30)], timestamp: 10)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "chain.json")
      c.save(path)
      loaded = ChainExplorer::Chain.load(path)
      assert_equal(-30, loaded.balance("alice"))
      assert_equal 30, loaded.balance("bob")
    end
  end
end
