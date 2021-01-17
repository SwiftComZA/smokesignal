module Wallet exposing (network, unlockStatus, userInfo, withFetchedBalance, withUnlockStatus)

import Eth.Net
import Misc exposing (withBalance)
import TokenValue exposing (TokenValue)
import Types exposing (UnlockStatus(..), UserInfo, Wallet(..))


userInfo : Wallet -> Maybe UserInfo
userInfo walletState =
    case walletState of
        Active uInfo ->
            Just uInfo

        _ ->
            Nothing


network : Wallet -> Maybe Eth.Net.NetworkId
network walletState =
    case walletState of
        NoneDetected ->
            Nothing

        OnlyNetwork network_ ->
            Just network_

        Active uInfo ->
            Just uInfo.network


withFetchedBalance : TokenValue -> Wallet -> Wallet
withFetchedBalance balance wallet =
    case wallet of
        Active uInfo ->
            Active <|
                (uInfo |> withBalance balance)

        _ ->
            wallet


withUnlockStatus : UnlockStatus -> Wallet -> Wallet
withUnlockStatus status wallet =
    case wallet of
        Active uInfo ->
            Active <|
                (uInfo |> Misc.withUnlockStatus status)

        _ ->
            wallet


unlockStatus : Wallet -> UnlockStatus
unlockStatus wallet =
    case wallet of
        Active uInfo ->
            uInfo.unlockStatus

        _ ->
            NotConnected
