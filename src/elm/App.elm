module App exposing (main)

import Browser.Events
import Browser.Hashbang
import Browser.Navigation
import Contracts.SmokeSignal
import Eth.Net
import Eth.Sentry.Event
import Eth.Sentry.Tx
import Eth.Sentry.Wallet
import Eth.Types
import Eth.Utils
import Helpers.Element
import Maybe.Extra
import Misc exposing (tryRouteToView)
import Ports
import Routing
import Time
import Types exposing (Flags, Model, Msg)
import Update exposing (update)
import Url exposing (Url)
import UserNotice as UN
import View exposing (view)
import Wallet


main : Program Flags Model Msg
main =
    Browser.Hashbang.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = Types.LinkClicked
        , onUrlChange = Routing.urlToRoute >> Types.RouteChanged
        }


init : Flags -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            Routing.urlToRoute url

        redirectCmd =
            Routing.blockParser url
                |> Maybe.andThen
                    (\block ->
                        if block < flags.startScanBlock then
                            redirectDomain url

                        else
                            Nothing
                    )
    in
    redirectCmd
        |> Maybe.Extra.unwrap
            (startApp flags key route)
            (\redirect ->
                ( Misc.emptyModel key
                , redirect
                )
            )


redirectDomain : Url -> Maybe (Cmd msg)
redirectDomain url =
    (case url.host of
        "smokesignal.eth.link" ->
            Just "alpha.smokesignal.eth.link"

        "smokesignal.eth" ->
            Just "alpha.smokesignal.eth"

        _ ->
            Nothing
    )
        |> Maybe.map
            (\newHost ->
                { url | host = newHost }
                    |> Url.toString
                    |> Browser.Navigation.load
            )


startApp : Flags -> Browser.Navigation.Key -> Types.Route -> ( Model, Cmd Msg )
startApp flags key route =
    let
        config =
            { smokeSignalContractAddress = Eth.Utils.unsafeToAddress flags.smokeSignalContractAddress
            , httpProviderUrl = flags.httpProviderUrl
            , startScanBlock = flags.startScanBlock
            }

        ( view, routingUserNotices ) =
            case tryRouteToView route of
                Ok v ->
                    ( v, [] )

                Err err ->
                    ( Types.ViewHome
                    , [ UN.routeNotFound <| Just err ]
                    )

        wallet =
            case flags.walletStatus of
                "GRANTED" ->
                    Types.Connecting

                "NOT_GRANTED" ->
                    Types.NetworkReady

                "NO_ETHEREUM" ->
                    Types.NoneDetected

                _ ->
                    Types.NoneDetected

        txSentry =
            Eth.Sentry.Tx.init
                ( Ports.txOut, Ports.txIn )
                Types.TxSentryMsg
                config.httpProviderUrl

        ( initEventSentry, initEventSentryCmd ) =
            Eth.Sentry.Event.init Types.EventSentryMsg config.httpProviderUrl

        ( eventSentry, secondEventSentryCmd, _ ) =
            Contracts.SmokeSignal.messageBurnEventFilter
                config.smokeSignalContractAddress
                (Eth.Types.BlockNum config.startScanBlock)
                Eth.Types.LatestBlock
                Nothing
                Nothing
                |> Eth.Sentry.Event.watch
                    (Contracts.SmokeSignal.decodePost
                        >> Types.PostLogReceived
                    )
                    initEventSentry

        now =
            Time.millisToPosix flags.nowInMillis

        model =
            Misc.emptyModel key
    in
    ( { model
        | view = view
        , wallet = wallet
        , now = now
        , dProfile = Helpers.Element.screenWidthToDisplayProfile flags.width
        , txSentry = txSentry
        , eventSentry = eventSentry
        , userNotices = routingUserNotices
        , cookieConsentGranted = flags.cookieConsent
        , newUserModal = flags.newUser
        , config = config
      }
    , Cmd.batch
        [ initEventSentryCmd
        , secondEventSentryCmd
        , Contracts.SmokeSignal.getEthPriceCmd
            config
            Types.EthPriceFetched
        , if wallet == Types.Connecting then
            Ports.connectToWeb3 ()

          else
            Cmd.none
        ]
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 200 Types.Tick
        , Time.every 2000 (always Types.ChangeDemoPhaceSrc)
        , Time.every 2500 (always Types.EveryFewSeconds)
        , Time.every 5000 (always Types.CheckTrackedTxsStatus)
        , Ports.walletResponse
            (Wallet.decodeConnectResponse >> Types.WalletResponse)
        , Eth.Sentry.Tx.listen model.txSentry
        , Browser.Events.onResize Types.Resize
        ]
