module Config exposing (..)

import BigInt exposing (BigInt)
import Eth.Types exposing (Address)
import Eth.Utils
import Time
import TokenValue exposing (TokenValue)


httpProviderUrl : Bool -> String
httpProviderUrl testMode =
    if testMode then
        kovanHttpProviderUrl

    else
        mainnetHttpProviderUrl


mainnetHttpProviderUrl : String
mainnetHttpProviderUrl =
    "https://mainnet.infura.io/v3/e3eef0e2435349bf9164e6f465bd7cf9"


kovanHttpProviderUrl : String
kovanHttpProviderUrl =
    "https://kovan.infura.io/v3/e3eef0e2435349bf9164e6f465bd7cf9"


daiContractAddress : Bool -> Address
daiContractAddress testMode =
    if testMode then
        Eth.Utils.unsafeToAddress "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"

    else
        Eth.Utils.unsafeToAddress "0x6B175474E89094C44Da98b954EedeAC495271d0F"


smokesigContractAddress : Bool -> Address
smokesigContractAddress testMode =
    if testMode then
        Debug.todo "test mode smokesig contract"

    else
        Eth.Utils.unsafeToAddress "0x5DC963d2c78D8FAa90c4400eB0dE1e4aE763DBaE"


startScanBlock : Int
startScanBlock =
    9632692
