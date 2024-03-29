![image](migratooor.ico)
[![GitHub release](https://img.shields.io/github/release/svanas/migratooor)](https://github.com/svanas/migratooor/releases/latest)
[![GitHub license](https://img.shields.io/github/license/svanas/migratooor)](https://github.com/svanas/migratooor/blob/main/LICENSE)
[![macOS](https://img.shields.io/badge/os-macOS-green)](https://github.com/svanas/migratooor/releases/latest/download/macOS.zip)
[![Windows](https://img.shields.io/badge/os-Windows-green)](https://github.com/svanas/migratooor/releases/latest/download/Windows.zip)

# Migratooor

Migratooor transfers all your tokens from one wallet to another.

| criteria                                              | support                                                   |
|-------------------------------------------------------|-----------------------------------------------------------|
| supports multiple EVM chains                          | ✅                                                        |
| supports secret recovery phrase                       | ✅                                                        |
| supports dry-runs                                     | ✅ (on the [Goerli](https://goerli.etherscan.io) testnet) |
| supports ERC-20 tokens                                | ✅                                                        |
| supports ERC-721 tokens                               | ✅                                                        |
| supports ERC-1155 tokens                              | ✅                                                        |
| supports EIP-1559 transactions                        | ✅                                                        |
| supports [Ethereum Name Service](https://ens.domains) | ✅                                                        |

## Why would I want to do that?

if...

1. your private key is compromised, or
2. your wallet is linked to your identity, or
3. you want to revoke every token approval

...then you will want to move all your tokens to a new, fresh wallet.

## Where can I download this app?

You can download migratooor for [Windows](https://github.com/svanas/migratooor/releases/latest/download/Windows.zip) or [macOS](https://github.com/svanas/migratooor/releases/latest/download/macOS.zip).

## How does it work?

First your wallet is scanned to find your tokens. A table will be shown displaying your balance of each token. You can then (un)check each token to move. Migratooor will transfer each token, and all you need to do is confirm one transaction (and one transaction only).

## Does this reduce the number of transactions needed?

It does not. Unless you use a smart contract wallet, there is no way to reduce the number of transactions. This app simply makes the process less tedious.

## What networks does this app support?

At the time of this writing, migratooor supports the following [EVM-compatible](https://chainlist.org) networks:
* [Ethereum](https://ethereum.org)
* [BNB Chain](https://www.bnbchain.org)
* [Polygon](https://polygon.technology)
* [Optimism](https://optimism.io)
* [Arbitrum](https://arbitrum.io)
* [Fantom](https://fantom.foundation)
* [Gnosis Chain](https://www.xdaichain.com)
* [PulseChain](https://pulsechain.com)

## What tokens does this app scan for?

On the Ethereum network, migratooor scans for...
* more than 5000 [ERC-20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20) tokens, and
* every NFT known to [OpenSea](https://opensea.io), and
* more than 30,000 [Uniswap v2](https://v2.info.uniswap.org) LP tokens.

## Is this app secure?

Maybe. No independent audit has been or will be commissioned. You are encouraged to read the code and decide for yourself whether it is secure.

## How can I test this app?

1. Switch your MetaMask to the [Goerli](https://goerli.etherscan.io) test network
2. Navigate to https://goerlifaucet.com or https://bigoerlifaucet.com
3. Paste your wallet address and press the `Send Me ETH` button
4. Wait for your transaction to get mined. Your wallet will get credited with 0.02 ETH
5. Navigate to https://app.balancer.fi/#/goerli/faucet
6. Pick whatever token you will want to mint and press the `Drip` button
7. Wait for your transaction to get mined.
8. Repeat step 6 and 7 for the other tokens you will want to mint
9. Launch migratooor, paste your wallet address from MetaMask, select the Goerli network

## How can I compile this app?

1. Download and install [Delphi Community Edition](https://www.embarcadero.com/products/delphi/starter)
2. Clone [Delphereum](https://github.com/svanas/delphereum) and the [dependencies](https://github.com/svanas/delphereum#dependencies)
3. The compiler will stop at [migratooor.api.key](https://github.com/svanas/migratooor/blob/main/migratooor.api.key)
4. Enter your [Infura](https://infura.io) API key and your [OpenSea](https://opensea.io) API key
5. Should you decide to fork this repo, then do not commit your API keys. Your API keys are not to be shared.

## Disclaimer

Migratooor is provided free of charge. There is no warranty. The authors do not assume any responsibility for bugs, vulnerabilities, or any other technical defects. Use at your own risk.
