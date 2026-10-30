require "json"
require_relative "block"
require_relative "mempool"

module ChainExplorer
  # An in-memory chain: a genesis block plus mined blocks on top.
  # Validation re-checks every link from scratch (recomputed hashes,
  # hash links, proof-of-work, transaction validity, no duplicate
  # transaction ids) and returns a list of human-readable problems,
  # so the explorer can explain exactly what is wrong with a chain.
  class Chain
    GENESIS_PREVIOUS_HASH = "0" * 64

    attr_reader :blocks, :difficulty

    def initialize(difficulty: 2)
      raise ArgumentError, "difficulty must be a non-negative Integer" unless difficulty.is_a?(Integer) && difficulty >= 0

      @difficulty = difficulty
      @blocks = [genesis_block]
    end

    def height
      blocks.length - 1
    end

    def add_block(transactions, timestamp:)
      block = Block.new(index: blocks.length, timestamp: timestamp,
                        transactions: transactions, previous_hash: blocks.last.hash)
      block.mine!(difficulty)
      blocks << block
      block
    end

    # Mines every pending transaction into one block and drains the pool.
    def mine_pending(mempool, timestamp:)
      raise ArgumentError, "mempool is empty" if mempool.empty?

      transactions = mempool.to_a
      block = add_block(transactions, timestamp: timestamp)
      transactions.each { |tx| mempool.remove(tx.id) }
      block
    end

    def valid?
      problems.empty?
    end

    def problems
      found = []
      blocks.each_with_index do |block, i|
        found << "block #{i}: hash mismatch (stored hash does not match contents)" if block.hash != recomputed_hash(block)
        found << "block #{i}: does not meet difficulty #{difficulty}" unless block.meets_difficulty?(difficulty)
        if i.zero?
          found << "genesis: previous hash must be all zeros" unless block.previous_hash == GENESIS_PREVIOUS_HASH
          found << "genesis: index must be 0" unless block.index.zero?
        else
          found << "block #{i}: previous hash does not match block #{i - 1} hash" unless block.previous_hash == blocks[i - 1].hash
          found << "block #{i}: index must be #{i}" unless block.index == i
          found << "block #{i}: timestamp goes backwards" if block.timestamp < blocks[i - 1].timestamp
        end
        block.transactions.each do |tx|
          found << "block #{i}: invalid transaction #{tx.id[0, 12]}" unless tx.valid?
        end
      end
      seen = {}
      blocks.flat_map(&:transactions).each do |tx|
        found << "duplicate transaction id #{tx.id[0, 12]}" if seen[tx.id]
        seen[tx.id] = true
      end
      found
    end

    def find_block(index: nil, hash: nil)
      return blocks[index] if !index.nil? && index >= 0 && index < blocks.length
      return blocks.find { |b| b.hash == hash } unless hash.nil?

      nil
    end

    def find_transaction(id)
      blocks.each do |block|
        found = block.transactions.find { |tx| tx.id == id }
        return [block, found] if found
      end
      nil
    end

    def transactions_for(address)
      blocks.flat_map(&:transactions).select { |tx| tx.sender == address || tx.recipient == address }
    end

    def balance(address)
      transactions_for(address).sum { |tx| tx.recipient == address ? tx.amount : -tx.amount }
    end

    def summary
      {"height" => height, "blocks" => blocks.length,
       "transactions" => blocks.sum { |b| b.transactions.length },
       "difficulty" => difficulty, "valid" => valid?,
       "latest_hash" => blocks.last.hash}
    end

    def to_h
      {"difficulty" => difficulty, "blocks" => blocks.map(&:to_h)}
    end

    def save(path)
      File.write(path, JSON.pretty_generate(to_h))
    end

    def self.load(path)
      data = JSON.parse(File.read(path))
      chain = allocate
      chain.instance_variable_set(:@difficulty, data["difficulty"])
      chain.instance_variable_set(:@blocks, data["blocks"].map { |b| Block.from_h(b) })
      chain
    end

    private

    def genesis_block
      Block.new(index: 0, timestamp: 0, transactions: [],
                previous_hash: GENESIS_PREVIOUS_HASH).mine!(difficulty)
    end

    def recomputed_hash(block)
      Block.new(index: block.index, timestamp: block.timestamp,
                transactions: block.transactions, previous_hash: block.previous_hash,
                nonce: block.nonce).hash
    end
  end
end
