require "digest"
require "json"
require_relative "transaction"

module ChainExplorer
  # A block bundles transactions and links to its predecessor by hash.
  # The block hash covers index, timestamp, transactions, previous hash
  # and nonce, so mining (finding a nonce whose hash meets the
  # difficulty) seals the block's contents.
  class Block
    attr_reader :index, :timestamp, :transactions, :previous_hash, :nonce

    def initialize(index:, timestamp:, transactions:, previous_hash:, nonce: 0)
      raise ArgumentError, "index must be a non-negative Integer" unless index.is_a?(Integer) && index >= 0
      raise ArgumentError, "previous_hash must be a String" unless previous_hash.is_a?(String)
      raise ArgumentError, "transactions must be Transactions" unless transactions.all? { |t| t.is_a?(Transaction) }

      @index = index
      @timestamp = timestamp
      @transactions = transactions.freeze
      @previous_hash = previous_hash
      @nonce = nonce
    end

    def hash
      @hash ||= Digest::SHA256.hexdigest(canonical)
    end

    def mine!(difficulty)
      raise ArgumentError, "difficulty must be a non-negative Integer" unless difficulty.is_a?(Integer) && difficulty >= 0

      @nonce = 0
      @hash = nil
      until meets_difficulty?(difficulty)
        @nonce += 1
        @hash = nil
      end
      self
    end

    def meets_difficulty?(difficulty)
      hash.start_with?("0" * difficulty)
    end

    def to_h
      {"index" => index, "timestamp" => timestamp,
       "transactions" => transactions.map(&:to_h),
       "previous_hash" => previous_hash, "nonce" => nonce, "hash" => hash}
    end

    def self.from_h(hash)
      block = new(index: hash["index"] || hash[:index],
                  timestamp: hash["timestamp"] || hash[:timestamp],
                  transactions: (hash["transactions"] || hash[:transactions]).map { |t| Transaction.from_h(t) },
                  previous_hash: hash["previous_hash"] || hash[:previous_hash],
                  nonce: hash["nonce"] || hash[:nonce])
      raise ArgumentError, "block hash mismatch on load" unless block.hash == (hash["hash"] || hash[:hash])

      block
    end

    private

    def canonical
      JSON.generate([index, timestamp, transactions.map(&:id), previous_hash, nonce])
    end
  end
end
