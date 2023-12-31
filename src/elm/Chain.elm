module Chain exposing (chainDecoder, decodeChain, getColor, getConfig, getName, getProviderUrl, txUrl)

import Element exposing (Color)
import Eth.Decode
import Eth.Net
import Eth.Types exposing (TxHash)
import Eth.Utils
import Helpers.Eth
import Json.Decode as Decode exposing (Decoder)
import Result.Extra
import Theme
import Types exposing (Chain(..), ChainConfig, Config, Flags)


getProviderUrl : Chain -> Config -> String
getProviderUrl chain =
    case chain of
        Eth ->
            .ethereum >> .providerUrl

        XDai ->
            .xDai >> .providerUrl

        ZkSync ->
            .zKSync >> .providerUrl

        ScrollTestnet ->
            .scrollTestnet >> .providerUrl

        BaseTestnet ->
            .baseTestnet >> .providerUrl
        
        ShardeumTestnet ->
            .shardeumTestnet >> .providerUrl


getConfig : Chain -> Config -> ChainConfig
getConfig chain =
    case chain of
        Eth ->
            .ethereum

        XDai ->
            .xDai

        ZkSync ->
            .zKSync

        ScrollTestnet ->
            .scrollTestnet

        BaseTestnet ->
            .baseTestnet

        ShardeumTestnet ->
            .shardeumTestnet


txUrl : Chain -> TxHash -> String
txUrl chain hash =
    case chain of
        Eth ->
            Helpers.Eth.etherscanTxUrl hash

        XDai ->
            "https://blockscout.com/poa/xdai/tx/"
                ++ Eth.Utils.txHashToString hash

        ZkSync ->
            "https://goerli.explorer.zksync.io/"
                ++ Eth.Utils.txHashToString hash

        ScrollTestnet ->
            "https://sepolia-blockscout.scroll.io/tx/"
                ++ Eth.Utils.txHashToString hash

        BaseTestnet ->
            "https://goerli.basescan.org/tx/"
                ++ Eth.Utils.txHashToString hash

        ShardeumTestnet ->
            "https://explorer-dapps.shardeum.org/transaction/"
                ++ Eth.Utils.txHashToString hash


getColor : Chain -> Color
getColor chain =
    case chain of
        XDai ->
            Theme.xDai

        Eth ->
            Theme.ethereum

        ZkSync ->
            Theme.ethereum

        ScrollTestnet ->
            Theme.ethereum

        BaseTestnet ->
            Theme.ethereum

        ShardeumTestnet ->
            Theme.ethereum


getName : Chain -> String
getName chain =
    case chain of
        Eth ->
            "Eth"

        XDai ->
            "xDai"

        ZkSync ->
            "ZKSync era"

        ScrollTestnet ->
            "Scroll"

        BaseTestnet ->
            "Base"

        ShardeumTestnet ->
            "Shardeum"


chainDecoder : Flags -> Decoder (List Types.ChainConfig)
chainDecoder flags =
    Decode.map4
        (\chain ssContract ssScriptsContract scan ->
            { chain = chain
            , ssContract = ssContract
            , ssScriptsContract = ssScriptsContract
            , startScanBlock = scan
            , providerUrl =
                case chain of
                    Types.Eth ->
                        flags.ethProviderUrl

                    Types.XDai ->
                        flags.xDaiProviderUrl

                    Types.ZkSync ->
                        flags.zkTestProviderUrl

                    Types.ScrollTestnet ->
                        flags.scrollTestnetProviderUrl

                    Types.BaseTestnet ->
                        flags.baseTestnetProviderUrl

                    Types.ShardeumTestnet ->
                        flags.shardeumTestnetProviderUrl
            }
        )
        (Decode.field "network" decodeChain
            |> Decode.andThen
                (Result.Extra.unpack
                    (always (Decode.fail "bad network"))
                    Decode.succeed
                )
        )
        (Decode.field "ssContract" Eth.Decode.address)
        (Decode.field "ssScriptsContract" Eth.Decode.address)
        (Decode.field "scan" Decode.int)
        |> Decode.list


decodeChain : Decoder (Result Types.WalletResponseErr Types.Chain)
decodeChain =
    Eth.Net.networkIdDecoder
        |> Decode.map
            (\network ->
                case network of
                    Eth.Net.Mainnet ->
                        Types.Eth
                            |> Ok

                    Eth.Net.Private 100 ->
                        Types.XDai
                            |> Ok

                    -- Hardhat server
                    Eth.Net.Private 31337 ->
                        Types.Eth
                            |> Ok

                    Eth.Net.Private 280 ->
                        Types.ZkSync
                            |> Ok

                    Eth.Net.Private 534351 ->
                        Types.ScrollTestnet
                            |> Ok

                    Eth.Net.Private 84531 ->
                        Types.BaseTestnet
                            |> Ok

                    Eth.Net.Private 8081 ->
                        Types.ShardeumTestnet
                            |> Ok

                    _ ->
                        Types.NetworkNotSupported
                            |> Err
            )
