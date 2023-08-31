Instructions for contracts, UI and hosting.

    - Contracts (Select solidity version "0.6.12")

        - Shardeum
            Deploy the flat.txt file in the smart-contracts/Shardeum/contracts folder through Remix. At this stage the available oracle on shardeum does not provide a price for the SHM native token but the ETH price is returend as an example. There is no mainnet for Shardeum yet (Already deployed to testnet).

        - Base
            Deploy the flat.txt file in the smart-contracts/Base/contracts folder through Remix. Base uses the Chainlink oracle. For mainnet change the oracle address to 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70 for ETH/USD.

        - ZKSync
            ZKSync is the only contract that has to be compiled locally. Run 
            "yarn hardhat compile" 
            and 
            "yarn hardhat deploy-zksync --script deploy-smokesignal.ts" 
            to deploy and verify. For a mainnet deployment edit "hardhat.config.ts" to use the "zkSyncMainnet" struct on line 25.
            ZKSync uses the Pyth oracle. Change the id on line 77 of smart-contracts/zksync/contracts/SmokeSignal.sol to 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace for ETH/USD and contract address to 0xf087c864AEccFb6A2Bf1Af6A0382B0d0f6c5D834 on line 259 for mainnet.

        - Scroll
            Like ZKSync Scroll uses the Pyth oracle. Kan deploy the code flat.txt via Remix. Scroll has no mainnet yet (Already deployed to testnet). 

        - Gnosis
            Already deployed.
    
    - User Interface

        - Updates that need to be made when a contract is deployed to mainnet.

            - Update the contract addresses, network ID and starting block in config.json.
            - Update the Network ID in src/elm/Chain.elm.
            - Update the providers by populating the env variables as listed in "envVarsAndOracles.txt".
              Try to use the same providers for mainnet (i.e. use alchemy for mainnet if it was used for the testnet. Some providers omit some expected fields in their responses).

    - Fleek (app.fleek.co for deployment)
        
        - Create an account and new project linked to the repo https://github.com/SwiftComZA/smokesignal (Service is free for 1 user).
        - Framework = Other.
        - Ensure the docker image with name "fleek/gridsome:node-12" is selected in the build settings. A docker image with a newer version of Node will not work.
        - Build command: npm install && npm run build
        - Publish directory = public.
        - Base directory = Not set.
        - This should deploy automatically when pushes to master is detected.
        - Populate all the environment variables with ENV=production.
        