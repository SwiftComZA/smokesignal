module View exposing (root)

import Browser
import CommonTypes exposing (..)
import Dict exposing (Dict)
import Dict.Extra
import Element exposing (Attribute, Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Element.Input
import Eth.Types exposing (Address)
import Eth.Utils
import Helpers.Element as EH
import Markdown
import TokenValue exposing (TokenValue)
import Types exposing (..)


root : Model -> Browser.Document Msg
root model =
    { title = "SmokeSignal"
    , body =
        [ Element.layout
            [ Element.width Element.fill ]
          <|
            body model
        ]
    }


body : Model -> Element Msg
body model =
    Element.column
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.padding 20
        , Element.spacing 30
        ]
        [ title
        , viewMessages model.messages
        , Element.el
            [ Element.width Element.fill
            , Element.alignBottom
            ]
            (viewComposeUX model.showMessageInput (makeAccountInfo model) model.composeUXModel)
        ]


title : Element Msg
title =
    Element.el
        [ Element.Font.size 40
        , Element.Font.bold
        ]
    <|
        Element.text "SmokeSignal"


viewMessages : List Message -> Element Msg
viewMessages messages =
    sortMessagesByBlock messages
        |> Dict.toList
        |> List.map
            (\( blocknum, messagesForBlock ) ->
                Element.column
                    [ Element.width Element.fill
                    , Element.spacing 10
                    ]
                    [ Element.el
                        [ Element.Font.size 14
                        , Element.Font.italic
                        ]
                        (Element.text <| String.fromInt blocknum)
                    , Element.column
                        [ Element.paddingXY 20 0 ]
                        (List.map viewMessage messagesForBlock)
                    ]
            )
        |> Element.column
            [ Element.width Element.fill
            , Element.spacing 20
            ]


sortMessagesByBlock : List Message -> Dict Int (List Message)
sortMessagesByBlock messages =
    messages
        |> Dict.Extra.groupBy
            .block


viewMessage : Message -> Element Msg
viewMessage message =
    Element.column
        [ Element.width Element.fill
        , Element.spacing 10
        ]
        [ Element.row
            [ Element.spacing 10 ]
            [ viewDaiBurned message.burnAmount
            , viewAuthor message.from
            ]
        , viewMessageContent message.message
        ]


viewDaiBurned : TokenValue -> Element Msg
viewDaiBurned amount =
    Element.row
        [ Element.Font.color EH.blue
        , Element.Font.size 20
        , Element.spacing 5
        ]
        [ Element.text <| TokenValue.toConciseString amount
        , daiSymbol [ Element.height <| Element.px 20 ]
        ]


viewAuthor : Address -> Element Msg
viewAuthor fromAddress =
    Element.el
        [ Element.Font.size 20 ]
        (Element.text <| Eth.Utils.addressToString fromAddress)


viewMessageContent : String -> Element Msg
viewMessageContent content =
    renderMarkdownParagraphs
        [ Element.spacing 2
        , Element.padding 10
        , Element.Border.rounded 10
        , Element.Background.color EH.softRed
        ]
        content


renderMarkdownParagraphs : List (Attribute Msg) -> String -> Element Msg
renderMarkdownParagraphs attributes =
    Markdown.toHtml Nothing
        >> List.map Element.html
        >> Element.paragraph
            attributes


viewComposeUX : Bool -> AccountInfo -> ComposeUXModel -> Element Msg
viewComposeUX showMessageInput accountInfo composeModel =
    Element.column
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.spacing 10
        ]
        [ if showMessageInput then
            messageInputBox composeModel.message

          else
            Element.none
        , maybeSubmitForm showMessageInput accountInfo composeModel
        ]


messageInputBox : String -> Element Msg
messageInputBox input =
    Element.Input.multiline [ Element.width Element.fill, Element.height (Element.px 100) ]
        { onChange = MessageInputChanged
        , text = input
        , placeholder = Just messageInputPlaceholder
        , label = Element.Input.labelHidden "messageInput"
        , spellcheck = True
        }


maybeSubmitForm : Bool -> AccountInfo -> ComposeUXModel -> Element Msg
maybeSubmitForm showingMessageInput accountInfo composeModel =
    Element.el [ Element.centerX ] <|
        case accountInfo.address of
            Nothing ->
                web3ConnectButton

            Just address ->
                case accountInfo.isUnlocked of
                    Nothing ->
                        EH.disabledButton
                            Desktop
                            []
                            "Checking DAI lock..."
                            Nothing

                    Just False ->
                        unlockButton

                    Just True ->
                        if showingMessageInput then
                            Element.row
                                [ Element.spacing 10 ]
                                [ submitButton composeModel accountInfo.balance
                                , Element.text "with"
                                , burnAmountInput composeModel.daiInput
                                ]

                        else
                            composeMessageButton


web3ConnectButton : Element Msg
web3ConnectButton =
    EH.redButton
        Desktop
        []
        [ "Connect to Wallet" ]
        ConnectToWeb3


unlockButton : Element Msg
unlockButton =
    EH.redButton
        Desktop
        []
        [ "Unlock Dai" ]
        UnlockDai


submitButton : ComposeUXModel -> Maybe TokenValue -> Element Msg
submitButton composeModel maybeUserBalance =
    case validateInputs composeModel of
        Nothing ->
            EH.disabledButton
                Desktop
                []
                "Burn Message"
                Nothing

        Just (Err errStr) ->
            EH.disabledButton
                Desktop
                [ Element.Font.color EH.softRed
                , Element.Font.italic
                ]
                errStr
                Nothing

        Just (Ok validatedInputs) ->
            let
                balanceTooLow =
                    maybeUserBalance
                        |> Maybe.map
                            (\balance ->
                                TokenValue.compare validatedInputs.burnAmount balance == GT
                            )
                        |> Maybe.withDefault False
            in
            if balanceTooLow then
                EH.disabledButton
                    Desktop
                    []
                    "Not enough Dai"
                    Nothing

            else
                EH.redButton
                    Desktop
                    []
                    [ "Burn message" ]
                    (Submit validatedInputs)


burnAmountInput : String -> Element Msg
burnAmountInput daiInput =
    Element.row []
        [ Element.Input.text
            [ Element.width <| Element.px 100 ]
            { onChange = DaiInputChanged
            , text = daiInput
            , placeholder = Nothing
            , label = Element.Input.labelHidden "amount to burn"
            }
        , daiSymbol []
        ]


composeMessageButton : Element Msg
composeMessageButton =
    EH.blueButton
        Desktop
        []
        [ "Compose Message" ]
        ComposeMessage


messageInputPlaceholder : Element.Input.Placeholder Msg
messageInputPlaceholder =
    Element.Input.placeholder [] <|
        Element.column
            [ Element.width Element.fill
            , Element.spacing 10
            ]
        <|
            List.map
                (Element.paragraph
                    [ Element.Font.color EH.lightGray
                    , Element.Font.italic
                    ]
                    << List.map Element.text
                )
                [ [ "SmokeSignal messages are formatted with markdown (e.g. *italic*, **bold**, [link-title](url))." ]
                , [ "Hackmd.io is useful for drafting and previewing markdown text." ]
                ]


daiSymbol : List (Attribute Msg) -> Element Msg
daiSymbol attributes =
    Element.image attributes
        { src = "img/dai-unit-char.svg"
        , description = ""
        }
