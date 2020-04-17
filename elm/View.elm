module View exposing (root)

import Browser
import Common.Msg exposing (..)
import Common.Types exposing (..)
import Common.View exposing (..)
import ComposeUX.View
import Dict exposing (Dict)
import Dict.Extra
import Element exposing (Attribute, Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Element.Input
import Element.Lazy
import ElementMarkdown
import Eth.Types exposing (Address, Hex, TxHash)
import Eth.Utils
import Helpers.Element as EH
import Helpers.Eth as EthHelpers
import Helpers.List as ListHelpers
import Helpers.Time as TimeHelpers
import Home.View
import Html.Attributes
import Json.Decode
import List.Extra
import Maybe.Extra
import Phace
import Post exposing (Post)
import Routing exposing (Route)
import Theme exposing (..)
import Time
import TokenValue exposing (TokenValue)
import Types exposing (..)
import UserNotice as UN exposing (UserNotice)
import Wallet


root : Model -> Browser.Document Msg
root model =
    { title = "SmokeSignal"
    , body =
        [ Element.layout
            [ Element.width Element.fill
            , Element.height Element.fill
            , Element.htmlAttribute <| Html.Attributes.style "height" "100vh"
            , Element.Events.onClick ClickHappened
            ]
          <|
            body model
        ]
    }


type WalletUXPhaceInfo
    = UserPhaceInfo ( UserInfo, Bool )
    | DemoPhaceInfo String


body : Model -> Element Msg
body model =
    let
        ( walletUXPhaceInfo, maybeUserInfoAndShowAddress ) =
            case Wallet.userInfo model.wallet of
                Just userInfo ->
                    let
                        userInfoAndShowAddress =
                            ( userInfo
                            , model.showAddress == Just UserPhace
                            )
                    in
                    ( UserPhaceInfo
                        userInfoAndShowAddress
                    , Just userInfoAndShowAddress
                    )

                Nothing ->
                    ( DemoPhaceInfo model.demoPhaceSrc
                    , Nothing
                    )
    in
    Element.column
        ([ Element.width Element.fill
         , Element.height Element.fill
         ]
            ++ List.map
                Element.inFront
                (userNoticeEls
                    model.dProfile
                    model.userNotices
                )
        )
        [ header
            model.dProfile
            walletUXPhaceInfo
        , case model.mode of
            Home ->
                Home.View.view model

            Compose ->
                Element.map ComposeUXMsg <|
                    ComposeUX.View.viewFull
                        model.dProfile
                        maybeUserInfoAndShowAddress
                        model.composeUXModel
                        (getMaybeTopic model)

            ViewAll ->
                viewAllPosts model

            ViewPost postId ->
                viewPostAndReplies postId model

            ViewTopic topic ->
                viewPostsForTopic topic model
        , if model.showHalfComposeUX then
            Element.el
                [ Element.width Element.fill
                , Element.alignBottom
                ]
                (Element.map ComposeUXMsg <|
                    ComposeUX.View.viewHalf
                        model.dProfile
                        maybeUserInfoAndShowAddress
                        model.composeUXModel
                        (getMaybeTopic model)
                )

          else
            Element.none
        ]


header : EH.DisplayProfile -> WalletUXPhaceInfo -> Element Msg
header dProfile walletUXPhaceInfo =
    Element.row
        [ Element.width Element.fill
        , Element.Background.color darkBlue
        ]
        [ Element.el
            [ Element.width <| Element.fillPortion 1
            , Element.padding 10
            ]
            EH.forgedByFoundry
        , Element.el
            [ Element.width <| Element.fillPortion 3
            ]
          <|
            Element.el [ Element.centerX ] logoBlock
        , Element.el
            [ Element.width <| Element.fillPortion 1
            ]
          <|
            Element.el
                [ Element.alignRight
                , Element.alignTop
                ]
            <|
                walletUX dProfile walletUXPhaceInfo
        ]


logoBlock : Element Msg
logoBlock =
    Element.row
        [ Element.spacing 15 ]
        [ Element.row
            [ Element.Font.size 50
            , Element.Font.bold
            ]
            [ Element.el [ Element.Font.color darkGray ] <| Element.text "Smoke"
            , Element.el [ Element.Font.color <| Element.rgb 1 0.5 0 ] <| Element.text "Signal"
            ]
        ]


walletUX : EH.DisplayProfile -> WalletUXPhaceInfo -> Element Msg
walletUX dProfile walletUXPhaceInfo =
    let
        commonAttributes =
            [ Element.alignRight
            , Element.alignTop
            , Element.padding 10
            , Element.Border.roundEach
                { bottomLeft = 10
                , topLeft = 0
                , topRight = 0
                , bottomRight = 0
                }
            , commonShadow
            , Element.Background.color blue
            , Element.Border.color (Element.rgba 0 0 1 0.5)
            , Element.Border.widthEach
                { top = 1
                , right = 1
                , bottom = 0
                , left = 0
                }
            ]
    in
    case walletUXPhaceInfo of
        DemoPhaceInfo demoAddress ->
            Element.column
                (commonAttributes
                    ++ [ Element.spacing 5 ]
                )
                [ Element.map MsgUp <|
                    Element.el
                        [ Element.inFront <|
                            Element.el
                                [ Element.width Element.fill
                                , Element.height Element.fill
                                , Element.Background.color <| Element.rgba 0 0 0 0.4
                                , Element.Border.rounded 10
                                , Element.pointer
                                , Element.Events.onClick <|
                                    ConnectToWeb3
                                ]
                            <|
                                Element.el
                                    [ Element.alignBottom
                                    , Element.width Element.fill
                                    , Element.Background.color <| Element.rgba 0 0 0 0.4
                                    , Element.Font.color EH.white
                                    , Element.Font.bold
                                    , Element.Font.size 14
                                    ]
                                <|
                                    Element.text "Connect Wallet"
                        ]
                    <|
                        phaceElement
                            MorphingPhace
                            (Eth.Utils.unsafeToAddress demoAddress)
                            False
                ]

        -- Element.el commonAttributes <|
        UserPhaceInfo ( accountInfo, showAddress ) ->
            Element.el commonAttributes <|
                Element.map MsgUp <|
                    Common.View.phaceElement
                        UserPhace
                        accountInfo.address
                        showAddress


userNoticeEls : EH.DisplayProfile -> List UserNotice -> List (Element Msg)
userNoticeEls dProfile notices =
    if notices == [] then
        []

    else
        [ Element.column
            [ Element.moveLeft (20 |> EH.changeForMobile 5 dProfile)
            , Element.moveUp (20 |> EH.changeForMobile 5 dProfile)
            , Element.spacing (10 |> EH.changeForMobile 5 dProfile)
            , Element.alignRight
            , Element.alignBottom
            , Element.width <| Element.px (300 |> EH.changeForMobile 150 dProfile)
            , Element.Font.size (15 |> EH.changeForMobile 10 dProfile)
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.BottomRight)
                |> List.map (userNotice dProfile)
            )
        , Element.column
            [ Element.moveRight (20 |> EH.changeForMobile 5 dProfile)
            , Element.moveDown 100
            , Element.spacing (10 |> EH.changeForMobile 5 dProfile)
            , Element.alignLeft
            , Element.alignTop
            , Element.width <| Element.px (300 |> EH.changeForMobile 150 dProfile)
            , Element.Font.size (15 |> EH.changeForMobile 10 dProfile)
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.TopLeft)
                |> List.map (userNotice dProfile)
            )
        ]


userNotice : EH.DisplayProfile -> ( Int, UserNotice ) -> Element Msg
userNotice dProfile ( id, notice ) =
    let
        color =
            case notice.noticeType of
                UN.Update ->
                    Element.rgb255 100 200 255

                UN.Caution ->
                    Element.rgb255 255 188 0

                UN.Error ->
                    Element.rgb255 255 70 70

                UN.ShouldBeImpossible ->
                    Element.rgb255 200 200 200

        textColor =
            case notice.noticeType of
                UN.Error ->
                    Element.rgb 1 1 1

                _ ->
                    Element.rgb 0 0 0

        closeElement =
            Element.el
                [ Element.alignRight
                , Element.alignTop
                , Element.moveUp 5
                , Element.moveRight 5
                ]
                (EH.closeButton True (DismissNotice id))
    in
    Element.el
        [ Element.Background.color color
        , Element.Border.rounded (10 |> EH.changeForMobile 5 dProfile)
        , Element.padding (8 |> EH.changeForMobile 3 dProfile)
        , Element.width Element.fill
        , Element.Border.width 1
        , Element.Border.color <| Element.rgba 0 0 0 0.15
        , EH.subtleShadow
        , EH.onClickNoPropagation NoOp
        ]
        (notice.mainParagraphs
            |> List.map (List.map mapNever)
            |> List.indexedMap
                (\pNum paragraphLines ->
                    Element.paragraph
                        [ Element.width Element.fill
                        , Element.Font.color textColor
                        , Element.spacing 1
                        ]
                        (if pNum == 0 then
                            closeElement :: paragraphLines

                         else
                            paragraphLines
                        )
                )
            |> Element.column
                [ Element.spacing 4
                , Element.width Element.fill
                ]
        )


mapNever : Element Never -> Element Msg
mapNever =
    Element.map (always NoOp)


viewAllPosts : Model -> Element Msg
viewAllPosts model =
    Element.text "todo"


viewPostAndReplies : Post.Id -> Model -> Element Msg
viewPostAndReplies postId model =
    Element.text "todo"


viewPostsForTopic : String -> Model -> Element Msg
viewPostsForTopic topic model =
    Element.text "todo"
