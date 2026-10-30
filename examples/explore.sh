#!/bin/sh
# Builds the sample chain, then tours every explorer CLI command on it.
# Run from the repo root: sh examples/explore.sh
set -e
cd "$(dirname "$0")/.."

ruby -Ilib examples/build_sample.rb
echo "--- summary ---"
ruby -Ilib bin/chain-explorer --chain sample-chain.json summary
echo "--- validate ---"
ruby -Ilib bin/chain-explorer --chain sample-chain.json validate
echo "--- blocks ---"
ruby -Ilib bin/chain-explorer --chain sample-chain.json blocks
echo "--- block 1 ---"
ruby -Ilib bin/chain-explorer --chain sample-chain.json block 1
echo "--- address alice ---"
ruby -Ilib bin/chain-explorer --chain sample-chain.json address alice
echo "--- tx (first tx of block 1, by prefix) ---"
TXID=$(ruby -Ilib -rjson -e 'puts JSON.parse(File.read("sample-chain.json"))["blocks"][1]["transactions"][0]["id"][0, 12]')
ruby -Ilib bin/chain-explorer --chain sample-chain.json tx "$TXID"
rm -f sample-chain.json
