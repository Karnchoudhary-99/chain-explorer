# Mini Blockchain Explorer

A small blockchain explorer in Ruby: browse blocks, look up transactions
and addresses, and verify the chain — all over a tiny in-memory chain
you can build and inspect from the command line.

## Roadmap

- [x] Project scaffold (module layout, smoke test, CI, README)
- [ ] Block + transaction model
- [ ] Chain validation (hash links, proof-of-work difficulty)
- [ ] Explorer CLI (blocks, transactions, addresses)
- [ ] Self-review checklist, then public

## Quick start

```sh
ruby -Itest test/smoke_test.rb
```

## License

MIT — see [LICENSE](LICENSE).
