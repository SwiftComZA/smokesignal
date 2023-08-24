module Chain exposing (chainDecoder, decodeChain, getColor, getConfig, getName, getProviderUrl, txUrl)

import Dict exposing (Dict)
import Element exposing (Color)
import Eth.Decode
import Eth.Net
import Eth.Types exposing (TxHash)
import Eth.Utils
import Helpers.Eth
import Json.Decode as Decode exposing (Decoder)
import Result.Extra
import Theme
import Types exposing (Chain(..), ChainConfig, Flags)



-- getProviderUrl : Chain -> Config -> String
-- getProviderUrl chain =
--     case chain of
--         Eth ->
--             .ethereum >> .providerUrl
--         XDai ->
--             .xDai >> .providerUrl
--         ZkSync ->
--             .zKSync >> .providerUrl
--         ScrollTestnet ->
--             .scrollTestnet >> .providerUrl


getProviderUrl : String -> Dict String ChainConfig -> Maybe String
getProviderUrl chainName config =
    config
        |> Dict.get chainName
        |> Maybe.map .providerUrl


getConfig : String -> Dict String ChainConfig -> Maybe ChainConfig
getConfig chainName config =
    config
        |> Dict.get chainName


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


getName : Chain -> String
getName chain =
    case chain of
        Eth ->
            "Eth"

        XDai ->
            "xDai"

        ZkSync ->
            "ZKSync era Testnet"

        ScrollTestnet ->
            "Scroll Testnet"


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
                    "Ethereum" ->
                        flags.ethProviderUrl

                    "xDai" ->
                        flags.xDaiProviderUrl

                    "ZkSyncTestnet" ->
                        flags.zkTestProviderUrl

                    "scrollTestnet" ->
                        flags.scrollTestnetProviderUrl

                    _ ->
                        "No Provider"
            }
        )
        (Decode.field "network" Decode.string
         -- |> Decode.andThen
         --     (Result.Extra.unpack
         --         (always (Decode.fail "bad network"))
         --         Decode.succeed
         --     )
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

                    _ ->
                        Types.NetworkNotSupported
                            |> Err
            )
