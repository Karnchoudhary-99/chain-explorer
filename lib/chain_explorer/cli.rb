require "json"
require_relative "chain"

module ChainExplorer
  # Command-line explorer for a chain saved as JSON (see Chain#save).
  #
  #   chain-explorer --chain sample-chain.json summary
  #   chain-explorer --chain sample-chain.json blocks
  #   chain-explorer --chain sample-chain.json block 1
  #   chain-explorer --chain sample-chain.json tx <id-or-prefix>
  #   chain-explorer --chain sample-chain.json address alice
  #   chain-explorer --chain sample-chain.json validate
  #
  # Every command also accepts --json for machine-readable output.
  # run returns a process exit code and never calls exit itself, so
  # the whole CLI is testable in-process with StringIO output.
  class CLI
    USAGE = <<~USAGE
      Usage: chain-explorer --chain FILE [--json] COMMAND [ARGS]

      Commands:
        summary            chain height, transaction count, validity
        validate           report whether the chain is valid, with reasons
        blocks [--from N] [--limit N]
                         list blocks (index, hash, tx count)
        block INDEX|HASH   show one block (hash may be a unique prefix)
        tx ID              show one transaction (id may be a unique prefix)
        address ADDRESS [--limit N]
                         balance plus transactions for an address
        top [N]            richest addresses by balance (default 10)
        help               show this help
    USAGE

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    def run(argv)
      chain_path, json, rest = parse_globals(argv)
      return help if rest.first == "help"

      if chain_path.nil?
        @err.puts "error: --chain FILE is required"
        @err.puts USAGE
        return 2
      end
      if rest.empty?
        @err.puts "error: a command is required"
        @err.puts USAGE
        return 2
      end

      chain = load_chain(chain_path)
      return 1 if chain.nil?

      command, *args = rest
      case command
      when "summary" then emit(json, summary_data(chain), summary_text(chain))
      when "validate" then validate(chain, json)
      when "blocks" then blocks_command(chain, args, json)
      when "block" then block_command(chain, args, json)
      when "tx" then tx_command(chain, args, json)
      when "address" then address_command(chain, args, json)
      when "top" then top_command(chain, args, json)
      else
        @err.puts "error: unknown command #{command.inspect}"
        @err.puts USAGE
        2
      end
    end

    private

    def help
      @out.puts USAGE
      0
    end

    # Splits --chain/--json/--help out of argv, preserving command order.
    def parse_globals(argv)
      chain_path = nil
      json = false
      rest = []
      i = 0
      while i < argv.length
        case argv[i]
        when "--chain"
          chain_path = argv[i + 1]
          i += 2
        when /\A--chain=(.+)\z/
          chain_path = Regexp.last_match(1)
          i += 1
        when "--json"
          json = true
          i += 1
        when "--help", "-h"
          rest << "help"
          i += 1
        else
          rest << argv[i]
          i += 1
        end
      end
      [chain_path, json, rest]
    end

    def load_chain(path)
      Chain.load(path)
    rescue Errno::ENOENT
      @err.puts "error: chain file not found: #{path}"
      nil
    rescue JSON::ParserError, ArgumentError => e
      @err.puts "error: cannot load chain from #{path}: #{e.message}"
      nil
    end

    def emit(json, data, text)
      if json
        @out.puts JSON.pretty_generate(data)
      else
        @out.puts text
      end
      0
    end

    def short(hash)
      "#{hash[0, 16]}…"
    end

    def summary_data(chain)
      chain.summary
    end

    def summary_text(chain)
      s = chain.summary
      [
        "Height: #{s['height']}",
        "Blocks: #{s['blocks']}",
        "Transactions: #{s['transactions']}",
        "Difficulty: #{s['difficulty']}",
        "Valid: #{s['valid']}",
        "Latest hash: #{s['latest_hash']}"
      ].join("\n")
    end

    def validate(chain, json)
      problems = chain.problems
      if json
        @out.puts JSON.pretty_generate({"valid" => problems.empty?, "problems" => problems})
        problems.empty? ? 0 : 1
      elsif problems.empty?
        @out.puts "Chain is valid (#{chain.blocks.length} blocks, #{chain.summary['transactions']} transactions)"
        0
      else
        @out.puts "Chain is INVALID:"
        problems.each { |p| @out.puts "  - #{p}" }
        1
      end
    end

    def blocks_data(blocks)
      blocks.map(&:to_h)
    end

    def blocks_text(blocks)
      blocks.map do |b|
        "Block #{b.index}  #{short(b.hash)}  prev #{short(b.previous_hash)}  " \
          "txs: #{b.transactions.length}  ts: #{b.timestamp}  nonce: #{b.nonce}"
      end.join("\n")
    end

    # Parses --from N / --limit N (also --from=N / --limit=N) from a
    # command's trailing args; unknown flags are usage errors.
    def parse_range(args)
      from = 0
      limit = nil
      i = 0
      while i < args.length
        case args[i]
        when "--from"
          from = args[i + 1].to_i
          i += 2
        when /\A--from=(\d+)\z/
          from = Regexp.last_match(1).to_i
          i += 1
        when "--limit"
          limit = args[i + 1].to_i
          i += 2
        when /\A--limit=(\d+)\z/
          limit = Regexp.last_match(1).to_i
          i += 1
        else
          return nil
        end
      end
      [from, limit]
    end

    def blocks_command(chain, args, json)
      range = parse_range(args)
      if range.nil?
        @err.puts "error: unknown option for blocks (expected --from N / --limit N)"
        return 2
      end
      from, limit = range
      blocks = chain.blocks.drop(from)
      blocks = blocks.first(limit) unless limit.nil?
      emit(json, blocks_data(blocks), blocks_text(blocks))
    end

    def top_data(chain, limit)
      addresses = chain.blocks.flat_map(&:transactions)
                         .flat_map { |t| [t.sender, t.recipient] }.uniq
      ranked = addresses.map do |a|
        {"address" => a, "balance" => chain.balance(a),
         "transactions" => chain.transactions_for(a).length}
      end.sort_by { |r| [-r["balance"], r["address"]] }
      ranked.first(limit)
    end

    def top_text(chain, limit)
      top_data(chain, limit).each_with_index.map do |r, i|
        "#{i + 1}. #{r['address']}  balance #{r['balance']}  txs: #{r['transactions']}"
      end.join("\n")
    end

    def top_command(chain, args, json)
      limit = 10
      args.each do |a|
        if a.match?(/\A--limit=(\d+)\z/)
          limit = Regexp.last_match(1).to_i
        elsif a == "--limit"
          @err.puts "error: --limit requires a value (use --limit=N for top)"
          return 2
        elsif a.match?(/\A\d+\z/)
          limit = a.to_i
        else
          @err.puts "error: unknown argument for top: #{a.inspect}"
          return 2
        end
      end
      emit(json, top_data(chain, limit), top_text(chain, limit))
    end

    def block_data(block)
      block.to_h
    end

    def block_text(block)
      lines = [
        "Block #{block.index}",
        "Hash: #{block.hash}",
        "Previous hash: #{block.previous_hash}",
        "Timestamp: #{block.timestamp}",
        "Nonce: #{block.nonce}",
        "Transactions: #{block.transactions.length}"
      ]
      block.transactions.each do |t|
        lines << "  #{t.sender} -> #{t.recipient}  #{t.amount}  (#{t.id[0, 12]}…)"
      end
      lines.join("\n")
    end

    # Resolves an exact index, an exact hash, or a unique hash prefix
    # (at least 8 characters, so a short prefix cannot silently match).
    def find_block(chain, query)
      if query.match?(/\A\d+\z/)
        index = query.to_i
        return chain.blocks[index] if index < chain.blocks.length
        return nil
      end
      return chain.blocks.find { |b| b.hash == query } if query.length == 64

      return :too_short if query.length < 8

      matches = chain.blocks.select { |b| b.hash.start_with?(query) }
      return matches.first if matches.length == 1
      return :ambiguous if matches.length > 1

      nil
    end

    def block_command(chain, args, json)
      if args.empty?
        @err.puts "error: block requires an index or hash"
        return 2
      end
      block = find_block(chain, args.first)
      case block
      when :too_short
        @err.puts "error: hash prefix must be at least 8 characters"
        2
      when :ambiguous
        @err.puts "error: hash prefix #{args.first.inspect} matches more than one block"
        1
      when nil
        @err.puts "error: no block #{args.first.inspect}"
        1
      else
        emit(json, block_data(block), block_text(block))
      end
    end

    def tx_data(block, tx)
      tx.to_h.merge("block_index" => block.index)
    end

    def tx_text(block, tx)
      memo = tx.memo ? "  memo: #{tx.memo}" : ""
      [
        "Transaction #{tx.id}",
        "Block: #{block.index}",
        "#{tx.sender} -> #{tx.recipient}  #{tx.amount}",
        "Timestamp: #{tx.timestamp}#{memo}"
      ].join("\n")
    end

    def find_tx(chain, query)
      all = chain.blocks.flat_map { |b| b.transactions.map { |t| [b, t] } }
      exact = all.find { |_, t| t.id == query }
      return exact if exact
      return :too_short if query.length < 8

      matches = all.select { |_, t| t.id.start_with?(query) }
      return matches.first if matches.length == 1
      return :ambiguous if matches.length > 1

      nil
    end

    def tx_command(chain, args, json)
      if args.empty?
        @err.puts "error: tx requires a transaction id"
        return 2
      end
      found = find_tx(chain, args.first)
      case found
      when :too_short
        @err.puts "error: transaction id prefix must be at least 8 characters"
        2
      when :ambiguous
        @err.puts "error: transaction id prefix #{args.first.inspect} matches more than one transaction"
        1
      when nil
        @err.puts "error: no transaction #{args.first.inspect}"
        1
      else
        block, tx = found
        emit(json, tx_data(block, tx), tx_text(block, tx))
      end
    end

    def address_data(chain, address, limit = nil)
      txs = chain.transactions_for(address)
      shown = limit.nil? ? txs : txs.last(limit)
      {
        "address" => address,
        "balance" => chain.balance(address),
        "transactions" => shown.map do |t|
          block, = chain.find_transaction(t.id)
          t.to_h.merge("block_index" => block.index,
                       "direction" => t.recipient == address ? "received" : "sent")
        end
      }
    end

    def address_text(chain, address, limit = nil)
      data = address_data(chain, address, limit)
      lines = [
        "Address: #{address}",
        "Balance: #{data['balance']}",
        "Transactions: #{data['transactions'].length}"
      ]
      data["transactions"].each do |t|
        lines << "  block #{t['block_index']}  #{t['direction']} #{t['amount']}  " \
                 "#{t['sender']} -> #{t['recipient']}  (#{t['id'][0, 12]}…)"
      end
      lines.join("\n")
    end

    def address_command(chain, args, json)
      if args.empty?
        @err.puts "error: address requires an address"
        return 2
      end
      address = args.first
      if args[1..].any? { |a| a == "--from" || a.start_with?("--from=") }
        @err.puts "error: unknown option for address (expected --limit N)"
        return 2
      end
      range = parse_range(args[1..])
      if range.nil?
        @err.puts "error: unknown option for address (expected --limit N)"
        return 2
      end
      _from, limit = range
      emit(json, address_data(chain, address, limit), address_text(chain, address, limit))
    end
  end
end
