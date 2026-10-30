# Builds a small sample chain and prints it block by block, then
# verifies it and shows a balance lookup. Run with:
#   ruby -Ilib examples/build_sample.rb
require_relative "../lib/chain_explorer"

chain = ChainExplorer::Chain.new(difficulty: 2)
tx = lambda do |sender, recipient, amount, ts|
  ChainExplorer::Transaction.new(sender: sender, recipient: recipient, amount: amount, timestamp: ts)
end

chain.add_block([tx.call("alice", "bob", 50, 1_700_000_001),
                 tx.call("bob", "carol", 20, 1_700_000_002)], timestamp: 1_700_000_010)
chain.add_block([tx.call("carol", "alice", 5, 1_700_000_011)], timestamp: 1_700_000_020)

chain.blocks.each do |block|
  puts "Block #{block.index}  #{block.hash[0, 16]}…  prev #{block.previous_hash[0, 16]}…  nonce #{block.nonce}"
  block.transactions.each do |t|
    puts "  #{t.sender} -> #{t.recipient}  #{t.amount}  (#{t.id[0, 12]}…)"
  end
end
puts "Chain valid? #{chain.valid?}"
puts "Balances: alice #{chain.balance('alice')}, bob #{chain.balance('bob')}, carol #{chain.balance('carol')}"
chain.save("sample-chain.json")
puts "Saved to sample-chain.json (#{File.size('sample-chain.json')} bytes)"
