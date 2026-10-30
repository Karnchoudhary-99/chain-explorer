# Mini Blockchain Explorer

A small blockchain explorer in Ruby: browse blocks, look up transactions
and addresses, and verify the chain — all over a tiny in-memory chain
you can build and inspect from the command line.

## Roadmap

- [x] Project scaffold (module layout, smoke test, CI, README)
- [x] Block + transaction model
- [x] Chain validation (hash links, proof-of-work difficulty)
- [ ] Explorer CLI (blocks, transactions, addresses)
- [ ] Self-review checklist, then public

## Quick start

```sh
ruby -Itest test/smoke_test.rb          # or: for f in test/*_test.rb; do ruby -Itest "$f"; done
ruby -Ilib examples/build_sample.rb     # build a 2-block sample chain, print it, save sample-chain.json
```

## Model

- `ChainExplorer::Transaction` — sender, recipient, positive integer
  amount, timestamp, optional memo. Its `id` is the SHA-256 of the
  canonical field encoding, so any field change changes the id.
- `ChainExplorer::Block` — index, timestamp, transactions, previous
  hash, nonce. `mine!(difficulty)` searches for a nonce whose SHA-256
  hash starts with `difficulty` zeroes; the hash covers every field,
  so editing a mined block invalidates it.
- `ChainExplorer::Chain` — genesis block (previous hash all zeroes)
  plus mined blocks. `valid?` re-checks every link from scratch and
  `problems` explains each failure: hash mismatches, broken links,
  missed difficulty, invalid transactions, duplicate transaction ids.
  `balance(address)` nets received minus sent; `find_block`,
  `find_transaction` and `transactions_for` power lookups; `save` /
  `Chain.load` persist the chain as JSON (loads reject tampered
  transaction and block hashes).

## License

MIT — see [LICENSE](LICENSE).
