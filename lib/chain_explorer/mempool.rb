require_relative "transaction"

module ChainExplorer
  # Pending transactions waiting to be mined into a block. Additions
  # are rejected when the transaction is invalid or already pending
  # (same id), so a block built from the pool never carries a
  # duplicate or malformed transaction.
  class Mempool
    def initialize
      @pending = {}
    end

    def add(transaction)
      raise ArgumentError, "expected a Transaction" unless transaction.is_a?(Transaction)
      raise ArgumentError, "invalid transaction" unless transaction.valid?
      raise ArgumentError, "transaction #{transaction.id[0, 12]} already pending" if @pending.key?(transaction.id)

      @pending[transaction.id] = transaction
      transaction
    end

    def remove(id)
      @pending.delete(id)
    end

    def include?(id)
      @pending.key?(id)
    end

    def empty?
      @pending.empty?
    end

    def size
      @pending.size
    end

    # Oldest first, so blocks built from the pool are deterministic.
    def to_a
      @pending.values.sort_by(&:timestamp)
    end

    def clear
      @pending.clear
    end
  end
end
