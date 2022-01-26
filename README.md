# Migratooor

Migratooor transfers all your tokens from one wallet to another.

## Why would I want to do that?

if your wallet...
1. is compromised, or
2. is linked to your identity

...then you will want to move all your tokens to a new, fresh wallet.

## How does it work?

First your wallet is scanned to find your tokens. A table will be shown displaying your balance of each token. You can then (un)check each token to move. Migratooor will transfer each token, and all you need to do is confirm one transaction (and one transaction only).

## Does this reduce the number of transactions needed?

It does not. Unless you use a smart contract wallet, there is no way to reduce the number of transactions. This app simply makes the process less tedious.

## What networks does this app support?

At the time of this writing, migratooor supports the following [EVM-compatible](https://chainlist.org) networks:
* [Ethereum](https://ethereum.org)
* [Binance Smart Chain](https://www.binance.org/en/smartChain)
* [Polygon](https://polygon.technology)
* [Optimism](https://optimism.io)
* [Arbitrum](https://arbitrum.io)
* [Gnosis](https://www.xdaichain.com)

## How can I test this app?

1. Switch your MetaMask to the [Rinkeby](https://rinkeby.etherscan.io) test network
2. Navigate to https://rinkebyfaucet.com
3. Copy your wallet address from MetaMask, press the `Send Me ETH` button
4. Wait for your transaction to get mined. Your wallet will get credited with 0.1 ETH
5. Navigate to https://app.compound.finance 
6. Click an `DAI`, then withdraw, and there will be a faucet button
7. Wait for your transaction to get mined. Your wallet will get credited with 100 DAI
8. Repeat step 6 and 7 for `USDC` and `USDT`
9. Launch migratooor, paste your wallet address from MetaMask, select the Rinkeby network

## Is this app secure?

Maybe. No independent audit has been or will be commissioned. You are encouraged to read the code and decide for yourself whether it is secure.

## Disclaimer

Migratooor is provided free of charge. There is no warranty. The authors do not assume any responsibility for bugs, vulnerabilities, or any other technical defects. Use at your own risk.
