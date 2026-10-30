require "digest"
require "json"

module ChainExplorer
  # A single value transfer on the chain. The id is the SHA-256 of the
  # canonical field encoding, so identical transfers are the same
  # transaction and any field change produces a different id.
  class Transaction
    attr_reader :sender, :recipient, :amount, :timestamp, :memo

    def initialize(sender:, recipient:, amount:, timestamp:, memo: nil)
      raise ArgumentError, "sender must be a non-empty String" unless sender.is_a?(String) && !sender.empty?
      raise ArgumentError, "recipient must be a non-empty String" unless recipient.is_a?(String) && !recipient.empty?
      raise ArgumentError, "amount must be a positive Integer" unless amount.is_a?(Integer) && amount.positive?
      raise ArgumentError, "timestamp must be an Integer" unless timestamp.is_a?(Integer)

      @sender = sender
      @recipient = recipient
      @amount = amount
      @timestamp = timestamp
      @memo = memo
    end

    def id
      @id ||= Digest::SHA256.hexdigest(canonical)
    end

    def valid?
      amount.is_a?(Integer) && amount.positive? &&
        sender.is_a?(String) && !sender.empty? &&
        recipient.is_a?(String) && !recipient.empty?
    end

    def to_h
      {"sender" => sender, "recipient" => recipient, "amount" => amount,
       "timestamp" => timestamp, "memo" => memo, "id" => id}
    end

    def self.from_h(hash)
      tx = new(sender: hash["sender"] || hash[:sender],
                recipient: hash["recipient"] || hash[:recipient],
                amount: hash["amount"] || hash[:amount],
                timestamp: hash["timestamp"] || hash[:timestamp],
                memo: hash["memo"] || hash[:memo])
      raise ArgumentError, "transaction id mismatch on load" unless tx.id == (hash["id"] || hash[:id])

      tx
    end

    private

    def canonical
      JSON.generate([sender, recipient, amount, timestamp, memo])
    end
  end
end
