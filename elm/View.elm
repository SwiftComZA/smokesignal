module View exposing (..)

import Browser
import Common.Msg exposing (..)
import Common.Types exposing (..)
import Common.View exposing (..)
import ComposeUX.Types as ComposeUX
import ComposeUX.View as ComposeUX
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
import Helpers.Element as EH exposing (DisplayProfile(..), responsiveVal)
import Helpers.Eth as EthHelpers
import Helpers.List as ListHelpers
import Helpers.Time as TimeHelpers
import Helpers.Tuple as TupleHelpers
import Home.View
import Html.Attributes
import Json.Decode
import List.Extra
import Maybe.Extra
import MaybeDebugLog exposing (maybeDebugLog)
import Phace
import Post exposing (Post)
import PostUX.Types as PostUX
import PostUX.View as PostUX
import Routing exposing (Route)
import Theme exposing (theme)
import Time
import TokenValue exposing (TokenValue)
import Tuple3
import Types exposing (..)
import UserNotice as UN exposing (UserNotice)
import Wallet exposing (Wallet)


root :
    Model
    -> Browser.Document Msg
root model =
    { title = getTitle model
    , body =
        [ Element.layout
            ([ Element.width Element.fill
             , Element.clipX
             , Element.htmlAttribute <| Html.Attributes.style "height" "100vh"
             , Element.Events.onClick ClickHappened
             ]
                ++ List.map Element.inFront (modals model)
            )
          <|
            body model
        ]
    }


getTitle : Model -> String
getTitle model =
    let defaultMain = "SmokeSignal | Uncensorable - Immutable - Unkillable | Real Free Speech - Cemented on the Blockchain"
    in
    case model.mode of
        BlankMode -> defaultMain
        Home homeModel ->
            defaultMain
        Compose ->
            "Compose | SmokeSignal"
        ViewContext context ->
            maybeGetContextTitlePart model.publishedPosts context
                |> Maybe.map (\contextTitle -> contextTitle ++ " | SmokeSignal")
                |> Maybe.withDefault defaultMain


modals :
    Model
    -> List (Element Msg)
modals model =
    Maybe.Extra.values
        ([ if model.mode /= Compose && model.showHalfComposeUX then
            Just <|
                viewHalfComposeUX model

           else
            Nothing
         , Maybe.map
            (Element.el
                [ Element.alignTop
                , Element.alignRight
                , Element.padding (responsiveVal model.dProfile 20 10)
                , EH.visibility False
                ]
                << Element.el
                    [ EH.visibility True ]
            )
            (maybeTxTracker
                model.dProfile
                model.showExpandedTrackedTxs
                model.trackedTxs
            )
         , let
            showDraftInProgressButton =
                case model.mode of
                    Compose ->
                        False

                    _ ->
                        (model.showHalfComposeUX == False)
                            && (not <| Post.contentIsEmpty model.composeUXModel.content)
           in
           if showDraftInProgressButton then
            Just <|
                theme.secondaryActionButton
                    model.dProfile
                    [ Element.alignBottom
                    , Element.alignLeft
                    , Element.paddingXY 20 10
                    , Element.Border.glow
                        (Element.rgba 0 0 0 0.5)
                        5
                    ]
                    [ "Draft in Progress" ]
                    (MsgUp <| StartInlineCompose model.composeUXModel.context)

           else
            Nothing
         , maybeViewDraftModal model
         , if not model.cookieConsentGranted then
            Just <| viewCookieConsentModal model.dProfile

           else
            Nothing
         ]
            ++ List.map Just
                (userNoticeEls
                    model.dProfile
                    model.userNotices
                )
        )


body :
    Model
    -> Element Msg
body model =
    let
        walletUXPhaceInfo =
            makeWalletUXPhaceInfo
                (Wallet.userInfo model.wallet)
                model.showAddressId
                model.demoPhaceSrc
    in
    Element.column
        [ Element.width Element.fill
        , Element.Background.color theme.appBackground
        , Element.height Element.fill
        ]
        [ case model.mode of
            BlankMode ->
                Element.none

            Home homeModel ->
                Element.map HomeMsg <|
                    Element.Lazy.lazy
                        (Home.View.view
                            model.dProfile
                            model.donateChecked
                            model.blockTimes
                            model.now
                            model.showAddressId
                            walletUXPhaceInfo
                        )
                        model.publishedPosts

            Compose ->
                Element.map ComposeUXMsg <|
                    ComposeUX.viewFull
                        model.dProfile
                        model.donateChecked
                        model.wallet
                        walletUXPhaceInfo
                        model.showAddressId
                        model.composeUXModel

            ViewContext context ->
                case context of
                    Post.Reply postId ->
                        case getPublishedPostFromId model.publishedPosts postId of
                            Just post ->
                                Element.column
                                    [ Element.width (Element.fill |> Element.maximum (maxContentColWidth + 100))
                                    , Element.centerX
                                    , Element.spacing 20
                                    , Element.paddingEach
                                        { top = 20
                                        , bottom = 0
                                        , right = 0
                                        , left = 0
                                        }
                                    ]
                                    [ viewPostHeader model.dProfile post
                                    , Element.Lazy.lazy5
                                        (viewPostAndReplies model.dProfile model.donateChecked model.wallet)
                                        model.publishedPosts
                                        model.blockTimes
                                        model.replies
                                        post
                                        model.postUX
                                    ]

                            Nothing ->
                                appStatusMessage
                                    theme.appStatusTextColor
                                    "Loading post..."

                    Post.TopLevel topic ->
                        Element.column
                            [ Element.width (Element.fill |> Element.maximum (maxContentColWidth + 100))
                            , Element.centerX
                            , Element.spacing 20
                            , Element.paddingEach
                                { top = 20
                                , bottom = 0
                                , right = 0
                                , left = 0
                                }
                            ]
                            [ viewTopicHeader model.dProfile (Wallet.userInfo model.wallet) topic
                            , Element.Lazy.lazy5
                                (viewPostsForTopic model.dProfile model.donateChecked model.wallet)
                                model.publishedPosts
                                model.blockTimes
                                model.replies
                                model.postUX
                                topic
                            ]
        ]


header : EH.DisplayProfile -> Mode -> WalletUXPhaceInfo -> List TrackedTx -> Bool -> Element Msg
header dProfile mode walletUXPhaceInfo trackedTxs showExpandedTrackedTxs =
    Element.row
        [ Element.width Element.fill
        , Element.Background.color theme.headerBackground
        , Element.padding <| responsiveVal dProfile 20 10
        , Element.spacing <| responsiveVal dProfile 10 5
        , Element.Border.glow
            (EH.black |> EH.withAlpha 0.5)
            5
        ]
        [ case dProfile of
            Mobile ->
                Element.el [ Element.alignTop, Element.alignLeft ] <| logoBlock dProfile

            Desktop ->
                logoBlock dProfile
        , Element.column
            [ Element.centerY
            , Element.alignRight
            , Element.spacing 5
            ]
            [ getInvolvedButton dProfile
            ]
        ]


getInvolvedButton : DisplayProfile -> Element Msg
getInvolvedButton dProfile =
    Element.newTabLink
        [ Element.padding 10
        , Element.Border.rounded 5
        , Element.Background.color <| Element.rgb 1 0 0
        , Element.Font.color EH.white
        , Element.Font.medium
        , Element.Font.size <| responsiveVal dProfile 20 12
        ]
        { url = "https://foundrydao.com"
        , label =
            Element.text "Support Radical Freedom"
        }


logoBlock : EH.DisplayProfile -> Element Msg
logoBlock dProfile =
    Element.column
        [ Element.spacing <| responsiveVal dProfile 15 8 ]
        [ Element.row
            (case dProfile of
                Desktop ->
                    [ Element.spacing 15
                    , Element.centerX
                    ]

                Mobile ->
                    [ Element.spacing 8
                    ]
            )
            [ coloredAppTitle
                [ Element.Font.size <| responsiveVal dProfile 50 30
                , Element.Font.bold
                , Element.pointer
                , Element.Events.onClick <| MsgUp <| GotoRoute <| Routing.Home
                ]
            ]
        , Element.el
            [ Element.Font.size <| responsiveVal dProfile 20 14
            , Element.centerX
            , Element.Font.color Theme.softRed
            ]
            (Element.text "Free Speech at the Protocol Level")
        ]


maybeTxTracker : DisplayProfile -> Bool -> List TrackedTx -> Maybe (Element Msg)
maybeTxTracker dProfile showExpanded trackedTxs =
    if List.isEmpty trackedTxs then
        Nothing

    else
        let
            tallyFunc : TrackedTx -> ( Int, Int, Int ) -> ( Int, Int, Int )
            tallyFunc trackedTx totals =
                case trackedTx.status of
                    Mining ->
                        Tuple3.mapFirst ((+) 1) totals

                    Mined _ ->
                        Tuple3.mapSecond ((+) 1) totals

                    Failed _ ->
                        Tuple3.mapThird ((+) 1) totals

            tallies =
                trackedTxs
                    |> List.foldl tallyFunc ( 0, 0, 0 )

            renderedTallyEls =
                tallies
                    |> TupleHelpers.mapTuple3
                        (\n ->
                            if n == 0 then
                                Nothing

                            else
                                Just n
                        )
                    |> TupleHelpers.mapEachTuple3
                        (Maybe.map
                            (\n ->
                                Element.el
                                    [ Element.Font.color <| trackedTxStatusToColor Mining ]
                                <|
                                    Element.text <|
                                        String.fromInt n
                                            ++ " TXs mining"
                            )
                        )
                        (Maybe.map
                            (\n ->
                                Element.el
                                    [ Element.Font.color <| trackedTxStatusToColor <| Mined Nothing ]
                                <|
                                    Element.text <|
                                        String.fromInt n
                                            ++ " TXs mined"
                            )
                        )
                        (Maybe.map
                            (\n ->
                                Element.el
                                    [ Element.Font.color <| trackedTxStatusToColor (Failed MinedButExecutionFailed) ]
                                <|
                                    Element.text <|
                                        String.fromInt n
                                            ++ " TXs failed"
                            )
                        )
                    |> TupleHelpers.tuple3ToList
        in
        if List.all Maybe.Extra.isNothing renderedTallyEls then
            Nothing

        else
            Just <|
                Element.el
                    [ Element.below <|
                        if showExpanded then
                            Element.el
                                [ Element.alignRight
                                , Element.alignTop
                                ]
                            <|
                                trackedTxsColumn trackedTxs

                        else
                            Element.none
                    ]
                <|
                    Element.column
                        [ Element.Border.rounded 5
                        , Element.Background.color <| Element.rgb 0.2 0.2 0.2
                        , Element.padding (responsiveVal dProfile 10 5)
                        , Element.spacing (responsiveVal dProfile 10 5)
                        , Element.Font.size (responsiveVal dProfile 20 12)
                        , Element.pointer
                        , EH.onClickNoPropagation <|
                            if showExpanded then
                                ShowExpandedTrackedTxs False

                            else
                                ShowExpandedTrackedTxs True
                        ]
                        (renderedTallyEls
                            |> List.map (Maybe.withDefault Element.none)
                        )


trackedTxsColumn :
    List TrackedTx
    -> Element Msg
trackedTxsColumn trackedTxs =
    Element.column
        [ Element.Background.color <| Theme.lightBlue
        , Element.Border.rounded 3
        , Element.Border.glow
            (Element.rgba 0 0 0 0.2)
            4
        , Element.padding 10
        , Element.spacing 5
        , EH.onClickNoPropagation <| MsgUp NoOp
        , Element.height (Element.shrink |> Element.maximum 400)
        , Element.scrollbarY
        , Element.alignRight
        ]
        (List.map viewTrackedTxRow trackedTxs)


viewTrackedTxRow :
    TrackedTx
    -> Element Msg
viewTrackedTxRow trackedTx =
    let
        etherscanLink label =
            Element.newTabLink
                [ Element.Font.italic
                , Element.Font.color theme.linkTextColor
                ]
                { url = EthHelpers.etherscanTxUrl trackedTx.txHash
                , label = Element.text label
                }

        titleEl =
            case ( trackedTx.txInfo, trackedTx.status ) of
                ( UnlockTx, _ ) ->
                    Element.text "Unlock DAI"

                ( TipTx postId amount, _ ) ->
                    Element.row
                        []
                        [ Element.text "Tip "
                        , Element.el
                            [ Element.Font.color theme.linkTextColor
                            , Element.pointer
                            , Element.Events.onClick <|
                                MsgUp <|
                                    GotoRoute <|
                                        Routing.ViewContext <|
                                            Post.Reply postId
                            ]
                            (Element.text "Post")
                        ]

                ( BurnTx postId amount, _ ) ->
                    Element.row
                        []
                        [ Element.text "Burn for "
                        , Element.el
                            [ Element.Font.color theme.linkTextColor
                            , Element.pointer
                            , Element.Events.onClick <|
                                MsgUp <|
                                    GotoRoute <|
                                        Routing.ViewContext <|
                                            Post.Reply postId
                            ]
                            (Element.text "Post")
                        ]

                ( PostTx _, Mined _ ) ->
                    Element.text "Post"

                ( PostTx draft, _ ) ->
                    Element.row
                        [ Element.spacing 8
                        ]
                        [ Element.text "Post"
                        , Element.el
                            [ Element.Font.color theme.linkTextColor
                            , Element.pointer
                            , Element.Events.onClick <| ViewDraft <| Just draft
                            ]
                            (Element.text "(View Draft)")
                        ]

        statusEl =
            case trackedTx.status of
                Mining ->
                    etherscanLink "Mining"

                Failed failReason ->
                    case failReason of
                        MinedButExecutionFailed ->
                            etherscanLink "Failed"

                Mined maybePostId ->
                    case trackedTx.txInfo of
                        PostTx draft ->
                            case maybePostId of
                                Just postId ->
                                    Element.el
                                        [ Element.Font.color theme.linkTextColor
                                        , Element.pointer
                                        , Element.Events.onClick <| MsgUp <| GotoRoute <| Routing.ViewContext <| Post.Reply postId
                                        ]
                                        (Element.text "Published")

                                Nothing ->
                                    etherscanLink "Mined"

                        _ ->
                            etherscanLink "Mined"
    in
    Element.row
        [ Element.width <| Element.px 250
        , Element.Background.color
            (trackedTxStatusToColor trackedTx.status
                |> EH.withAlpha 0.3
            )
        , Element.Border.rounded 2
        , Element.Border.width 1
        , Element.Border.color <| Element.rgba 0 0 0 0.3
        , Element.padding 4
        , Element.spacing 4
        , Element.Font.size 20
        ]
        [ titleEl
        , Element.el [ Element.alignRight ] <| statusEl
        ]


trackedTxStatusToColor :
    TxStatus
    -> Element.Color
trackedTxStatusToColor txStatus =
    case txStatus of
        Mining ->
            Theme.darkYellow

        Mined _ ->
            Theme.green

        Failed _ ->
            Theme.softRed


userNoticeEls :
    EH.DisplayProfile
    -> List UserNotice
    -> List (Element Msg)
userNoticeEls dProfile notices =
    if notices == [] then
        []

    else
        [ Element.column
            [ Element.moveLeft (EH.responsiveVal dProfile 20 5)
            , Element.moveUp (EH.responsiveVal dProfile 20 5)
            , Element.spacing (EH.responsiveVal dProfile 10 5)
            , Element.alignRight
            , Element.alignBottom
            , Element.width <| Element.px (EH.responsiveVal dProfile 300 150)
            , Element.Font.size (EH.responsiveVal dProfile 15 10)
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.BottomRight)
                |> List.map (userNotice dProfile)
            )
        , Element.column
            [ Element.moveRight (EH.responsiveVal dProfile 20 5)
            , Element.moveDown 100
            , Element.spacing (EH.responsiveVal dProfile 10 5)
            , Element.alignLeft
            , Element.alignTop
            , Element.width <| Element.px (EH.responsiveVal dProfile 300 150)
            , Element.Font.size (EH.responsiveVal dProfile 15 10)
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.TopLeft)
                |> List.map (userNotice dProfile)
            )
        ]


userNotice :
    EH.DisplayProfile
    -> ( Int, UserNotice )
    -> Element Msg
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
            EH.closeButton
                [ Element.alignRight
                , Element.alignTop
                , Element.moveUp 2
                ]
                EH.black
                (DismissNotice id)
    in
    Element.el
        [ Element.Background.color color
        , Element.Border.rounded (EH.responsiveVal dProfile 10 5)
        , Element.padding (EH.responsiveVal dProfile 8 3)
        , Element.width Element.fill
        , Element.Border.width 1
        , Element.Border.color <| Element.rgba 0 0 0 0.15
        , EH.subtleShadow
        , EH.onClickNoPropagation <| MsgUp NoOp
        ]
        (notice.mainParagraphs
            |> List.map (List.map (Element.map never))
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


viewPostHeader : DisplayProfile -> Post.Published -> Element Msg
viewPostHeader dProfile publishedPost =
    Element.row
        (subheaderAttributes dProfile
            ++ [ Element.spacing 40
               , Element.Font.center
               , Element.centerX
               ]
        )
        [ Element.el [ Element.Font.bold ] <| Element.text "Viewing Post"
        , Element.column
            [ Element.Font.size 16 ]
            [ case dProfile of
                Desktop ->
                    Element.text <|
                        "id: "
                            ++ (publishedPost.id.messageHash |> Eth.Utils.hexToString)

                Mobile ->
                    Element.none
            , Element.newTabLink
                [ Element.Font.color theme.linkTextColorAgainstBackground ]
                { url = EthHelpers.etherscanTxUrl publishedPost.txHash
                , label = Element.text "View on etherscan"
                }
            ]
        ]


viewPostAndReplies : DisplayProfile -> Bool -> Wallet -> PublishedPostsDict -> Dict Int Time.Posix -> List Reply -> Post.Published -> Maybe ( PostUXId, PostUX.Model ) -> Element Msg
viewPostAndReplies dProfile donateChecked wallet allPosts blockTimes replies publishedPost postUX =
    let
        replyingPosts =
            let
                postIds =
                    replies
                        |> List.filterMap
                            (\reply ->
                                if reply.to == publishedPost.id then
                                    Just reply.from

                                else
                                    Nothing
                            )
            in
            postIds
                |> List.map (getPublishedPostFromId allPosts)
                |> Maybe.Extra.values
                |> Dict.Extra.groupBy (.id >> .block)
    in
    Element.column
        [ Element.centerX
        , Element.width (Element.fill |> Element.maximum maxContentColWidth)
        , Element.height Element.fill
        , Element.spacing 40
        , Element.padding 20
        ]
        [ Element.map
            (PostUXMsg <| PublishedPost publishedPost.id)
          <|
            PostUX.view
                dProfile
                donateChecked
                True
                (Post.PublishedPost publishedPost)
                wallet
                (case postUX of
                    Just ( PublishedPost id, postUXModel ) ->
                        if id == publishedPost.id then
                            Just postUXModel

                        else
                            Nothing

                    _ ->
                        Nothing
                )
        , if Dict.isEmpty replyingPosts then
            Element.none

          else
            Element.column
                [ Element.width Element.fill
                , Element.spacing 20
                ]
                [ Element.el
                    [ Element.Font.size (responsiveVal dProfile 50 30)
                    , Element.Font.bold
                    , Element.Font.color theme.defaultTextColor
                    ]
                  <|
                    Element.text "Replies"
                , viewPostsGroupedByBlock
                    dProfile
                    donateChecked
                    wallet
                    False
                    blockTimes
                    replies
                    replyingPosts
                    postUX
                ]
        ]


viewPostsForTopic : DisplayProfile -> Bool -> Wallet -> PublishedPostsDict -> Dict Int Time.Posix -> List Reply -> Maybe ( PostUXId, PostUX.Model ) -> String -> Element Msg
viewPostsForTopic dProfile donateChecked wallet allPosts blockTimes replies uxModel topic =
    let
        filteredPosts =
            allPosts
                |> filterPosts
                    (\publishedPost ->
                        publishedPost.core.metadata.context == Post.TopLevel topic
                    )
    in
    Element.column
        [ Element.width (Element.fill |> Element.maximum maxContentColWidth)
        , Element.centerX
        , Element.height Element.fill
        , Element.padding 20
        , Element.spacing 40
        ]
        [ if Dict.isEmpty filteredPosts then
            appStatusMessage theme.appStatusTextColor <| "Haven't yet found any posts for this topic..."

          else
            Element.Lazy.lazy5
                (viewPostsGroupedByBlock dProfile donateChecked wallet)
                False
                blockTimes
                replies
                filteredPosts
                uxModel
        ]


viewTopicHeader : DisplayProfile -> Maybe UserInfo -> String -> Element Msg
viewTopicHeader dProfile maybeUserInfo topic =
    Element.column
        (subheaderAttributes dProfile
            ++ [ Element.spacing 10 ]
        )
        [ Element.row
            []
            [ Element.el [ Element.Font.bold ] <| Element.text "Viewing Topic "
            , Element.el
                [ Element.Font.bold
                , Element.Font.italic
                ]
              <|
                Element.text topic
            ]
        , case maybeUserInfo of
            Just userInfo ->
                theme.secondaryActionButton
                    dProfile
                    []
                    [ "Post in Topic" ]
                    (MsgUp <|
                        GotoRoute <|
                            Routing.Compose <|
                                Post.TopLevel topic
                    )

            Nothing ->
                theme.emphasizedActionButton
                    dProfile
                    [ Element.paddingXY 30 10 ]
                    [ "Activate Wallet to Post" ]
                    (MsgUp <| ConnectToWeb3)
        ]


viewPostsGroupedByBlock : DisplayProfile -> Bool -> Wallet -> Bool -> Dict Int Time.Posix -> List Reply -> PublishedPostsDict -> Maybe ( PostUXId, PostUX.Model ) -> Element Msg
viewPostsGroupedByBlock dProfile donateChecked wallet showContext blockTimes replies publishedPosts postUX =
    Element.column
        [ Element.width Element.fill
        , Element.spacing 20
        ]
        (publishedPosts
            |> Dict.toList
            |> List.reverse
            |> List.map (viewBlocknumAndPosts dProfile donateChecked wallet showContext blockTimes replies postUX)
        )


viewBlocknumAndPosts : DisplayProfile -> Bool -> Wallet -> Bool -> Dict Int Time.Posix -> List Reply -> Maybe ( PostUXId, PostUX.Model ) -> ( Int, List Post.Published ) -> Element Msg
viewBlocknumAndPosts dProfile donateChecked wallet showContext blockTimes replies postUX ( blocknum, publishedPosts ) =
    Element.column
        [ Element.width Element.fill
        , Element.spacing 10
        ]
        [ Element.column
            [ Element.width Element.fill
            , Element.spacing 5
            , Element.Font.italic
            , Element.Font.size 14
            , Element.Font.color theme.defaultTextColor
            ]
            [ Element.row
                [ Element.width Element.fill
                , Element.spacing 5
                ]
                [ Element.text <| "block " ++ String.fromInt blocknum
                , Element.el
                    [ Element.width Element.fill
                    , Element.height <| Element.px 1
                    , Element.Border.color theme.defaultTextColor
                    , Element.Border.widthEach
                        { top = 1
                        , bottom = 0
                        , right = 0
                        , left = 0
                        }
                    , Element.Border.dashed
                    ]
                    Element.none
                ]
            , blockTimes
                |> Dict.get blocknum
                |> Maybe.map posixToString
                |> Maybe.withDefault "[fetching block timestamp]"
                |> Element.text
            ]
        , viewPosts dProfile donateChecked wallet showContext replies publishedPosts postUX
        ]


viewPosts : DisplayProfile -> Bool -> Wallet -> Bool -> List Reply -> List Post.Published -> Maybe ( PostUXId, PostUX.Model ) -> Element Msg
viewPosts dProfile donateChecked wallet showContext replies publishedPosts postUX =
    Element.column
        [ Element.paddingXY 20 0
        , Element.spacing 20
        , Element.width Element.fill
        ]
    <|
        List.map
            (\publishedPost ->
                let
                    talliedReplies =
                        replies
                            |> List.Extra.count
                                (.to >> (==) publishedPost.id)
                in
                Element.column
                    [ Element.width Element.fill
                    , Element.alignTop
                    ]
                    [ Element.map
                        (PostUXMsg <| PublishedPost publishedPost.id)
                      <|
                        PostUX.view
                            dProfile
                            donateChecked
                            showContext
                            (Post.PublishedPost publishedPost)
                            wallet
                            (case postUX of
                                Just ( PublishedPost id, postUXModel ) ->
                                    if publishedPost.id == id then
                                        Just postUXModel

                                    else
                                        Nothing

                                _ ->
                                    Nothing
                            )
                    , viewNumRepliesIfNonzero
                        publishedPost.id
                        talliedReplies
                    ]
            )
            publishedPosts


viewNumRepliesIfNonzero : Post.Id -> Int -> Element Msg
viewNumRepliesIfNonzero postId numReplies =
    if numReplies == 0 then
        Element.none

    else
        Element.el
            [ Element.Font.color theme.linkTextColorAgainstBackground
            , Element.pointer
            , Element.Events.onClick <|
                MsgUp <|
                    Common.Msg.GotoRoute <|
                        Routing.ViewContext <|
                            Post.Reply postId
            , Element.Font.italic
            , Element.paddingXY 20 10
            ]
            (Element.text <|
                String.fromInt numReplies
                    ++ (if numReplies == 1 then
                            " reply"

                        else
                            " replies"
                       )
            )


viewHalfComposeUX : Model -> Element Msg
viewHalfComposeUX model =
    Element.column
        [ Element.height Element.fill
        , Element.width Element.fill
        , EH.visibility False
        ]
        [ Element.el
            [ Element.height Element.fill
            ]
            Element.none
        , Element.el
            [ EH.visibility True
            , Element.width Element.fill
            , Element.height Element.fill
            ]
            (Element.map ComposeUXMsg <|
                ComposeUX.view
                    model.dProfile
                    model.donateChecked
                    model.wallet
                    (makeWalletUXPhaceInfo
                        (Wallet.userInfo model.wallet)
                        model.showAddressId
                        model.demoPhaceSrc
                    )
                    model.showAddressId
                    model.composeUXModel
            )
        ]


maybeViewDraftModal : Model -> Maybe (Element Msg)
maybeViewDraftModal model =
    model.draftModal
        |> Maybe.map
            (\draft ->
                Element.el
                    [ Element.centerX
                    , Element.centerY
                    , Element.Border.rounded 10
                    , EH.onClickNoPropagation <| MsgUp NoOp
                    , Element.padding (responsiveVal model.dProfile 20 10)
                    , Element.Background.color theme.draftModalBackground
                    , Element.Border.glow
                        (Element.rgba 0 0 0 0.3)
                        10
                    , Element.inFront <|
                        Element.row
                            [ Element.alignRight
                            , Element.alignTop
                            , Element.spacing 20
                            ]
                            [ Element.el
                                [ Element.alignTop
                                , responsiveVal model.dProfile
                                    (Element.paddingXY 40 20)
                                    (Element.padding 20)
                                ]
                              <|
                                theme.secondaryActionButton
                                    model.dProfile
                                    [ Element.Border.glow
                                        (Element.rgba 0 0 0 0.4)
                                        5
                                    ]
                                    [ "Restore Draft" ]
                                    (RestoreDraft draft)
                            , Element.el
                                [ Element.alignTop
                                , Element.paddingXY 10 0
                                ]
                              <|
                                EH.closeButton
                                    [ Element.Border.rounded 4
                                    , Element.Background.color Theme.darkBlue
                                    , Element.padding 3
                                    ]
                                    EH.white
                                    (ViewDraft Nothing)
                            ]
                    ]
                <|
                    Element.column
                        [ Element.htmlAttribute <| Html.Attributes.style "height" "80vh"
                        , Element.htmlAttribute <| Html.Attributes.style "width" "80vw"
                        , Element.Events.onClick (ViewDraft Nothing)
                        , Element.scrollbarY
                        , Element.paddingEach
                            { right = responsiveVal model.dProfile 20 10
                            , left = 0
                            , bottom = 0
                            , top = 0
                            }
                        ]
                    <|
                        [ Element.map
                            (PostUXMsg DraftPreview)
                          <|
                            PostUX.view
                                model.dProfile
                                model.donateChecked
                                True
                                (Post.PostDraft draft)
                                model.wallet
                                (case model.postUX of
                                    Just ( DraftPreview, postUXModel ) ->
                                        Just postUXModel

                                    _ ->
                                        Nothing
                                )
                        ]
            )


viewCookieConsentModal : DisplayProfile -> Element Msg
viewCookieConsentModal dProfile =
    Element.row
        [ Element.alignBottom
        , responsiveVal dProfile Element.centerX (Element.width Element.fill)
        , Element.Border.roundEach
            { topLeft = 5
            , topRight = 5
            , bottomLeft = 0
            , bottomRight = 0
            }
        , Element.padding 15
        , Element.spacing 15
        , Element.Background.color <| Theme.darkBlue
        , Element.Font.color EH.white
        , Element.Border.glow
            (Element.rgba 0 0 0 0.2)
            10
        ]
        [ Element.paragraph
            [ Element.width <| responsiveVal dProfile (Element.px 800) Element.fill
            , Element.Font.size <| responsiveVal dProfile 20 12
            ]
            [ Element.text "Foundry products use cookies and analytics to track behavior patterns, to help zero in on effective marketing strategies. To avoid being tracked in this way, we recommend using the "
            , Element.newTabLink
                [ Element.Font.color Theme.blue ]
                { url = "https://brave.com/"
                , label = Element.text "Brave browser"
                }
            , Element.text " or installing the "
            , Element.newTabLink
                [ Element.Font.color Theme.blue ]
                { url = "https://tools.google.com/dlpage/gaoptout"
                , label = Element.text "Google Analytics Opt-Out browser addon"
                }
            , Element.text "."
            ]
        , Theme.blueButton dProfile [ Element.alignTop ] [ "Understood" ] CookieConsentGranted
        ]
