port module Tux exposing (main)

import Color
import Dom
import Element exposing (Attribute, Element, attribute, center, centerY, column, decorativeImage, el, empty, height, layout, padding, px, row, spacing, text, width)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import Html.Events exposing (keyCode, on)
import Http
import Json.Decode as Decode exposing (Decoder, bool, decodeString, decodeValue, field, int, list, map2, map3, nullable, string)
import Json.Encode exposing (Value, object)
import Task


id : String -> Attribute msg
id =
    Html.Attributes.id
        >> attribute


main : Program String Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = updateWithStorage
        , subscriptions = subscriptions
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    pushSubscription SubscriptionCb



-- PORTS


port setStorage : Model -> Cmd msg


port pushSubscribe : List Int -> Cmd msg


port pushUnsubscribe : () -> Cmd msg


port pushSubscription : (Value -> msg) -> Sub msg



-- MODEL


type Field
    = Pw
    | Push


type alias Saved =
    { subscription : Maybe Subscription
    , serverKey : List Int
    , pushPassword : String
    }


type alias Model =
    { message : String
    , subscription : Maybe Subscription
    , serverKey : List Int
    , pushPassword : String
    , passwordField : Maybe String
    , pushField : Maybe String
    }


type alias Subscription =
    { endpoint : String
    , keys : Keys
    }


type alias Keys =
    { auth : String
    , p256dh : String
    }



-- INIT


init : String -> ( Model, Cmd Msg )
init json =
    let
        { serverKey, subscription, pushPassword } =
            json
                |> decodeString savedDataDecoder
                |> Result.withDefault initSavedData
    in
    ( { message = "..."
      , subscription = subscription
      , serverKey = serverKey
      , pushPassword = pushPassword
      , passwordField = Nothing
      , pushField = Nothing
      }
    , case subscription of
        Nothing ->
            Cmd.none

        Just sub ->
            validateSubscription serverKey sub
    )


initSavedData : Saved
initSavedData =
    { serverKey = []
    , subscription = Nothing
    , pushPassword = ""
    }



-- MESSAGES


type Msg
    = SubscriptionCb Value
    | ValidateSubscriptionCb (Result Http.Error Bool)
    | Update Field String
    | Edit Field
    | FocusCb (Result Dom.Error ())
    | Cancel Field
    | SetPw
    | Subscribe
    | SubscribeCb (Result Http.Error String)
    | SendPush
    | SendPushCb (Result Http.Error String)
    | ServerKeyCb (Result Http.Error (List Int))
    | Unsubscribe



-- UPDATE


updateWithStorage : Msg -> Model -> ( Model, Cmd Msg )
updateWithStorage msg model =
    let
        ( newModel, cmds ) =
            update msg model
    in
    ( newModel
    , Cmd.batch [ setStorage newModel, cmds ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ValidateSubscriptionCb res ->
            case res of
                Ok valid ->
                    if valid then
                        ( model, Cmd.none )
                    else
                        ( { model | serverKey = [] }, pushUnsubscribe () )

                Err err ->
                    ( { model | message = "Subscription Validation Error" }
                    , log "Subscription Validation Error:" err
                    )

        SubscriptionCb value ->
            let
                subscription =
                    value
                        |> decodeValue (nullable subscriptionDecoder)
                        |> Result.withDefault Nothing

                cmd =
                    case subscription of
                        Just sub ->
                            saveSub sub

                        Nothing ->
                            Cmd.none
            in
            ( { model | subscription = subscription }, cmd )

        ServerKeyCb res ->
            case res of
                Ok key ->
                    ( { model | serverKey = key }, pushSubscribe key )

                Err err ->
                    ( { model | message = "Server Key Error" }, log "Server Key Error:" err )

        Cancel Push ->
            ( { model | pushField = Nothing }, Cmd.none )

        Cancel Pw ->
            ( { model | passwordField = Nothing }, Cmd.none )

        Edit Push ->
            ( { model | pushField = Just "" }, focusOn "input1" )

        Edit Pw ->
            ( { model | passwordField = Just "" }, focusOn "input2" )

        Update Push val ->
            ( { model | pushField = Just val }, Cmd.none )

        Update Pw val ->
            ( { model | passwordField = Just val }, Cmd.none )

        SendPush ->
            model.pushField
                |> Maybe.map
                    (\txt ->
                        ( { model | pushField = Nothing }, push txt model.pushPassword )
                    )
                |> Maybe.withDefault
                    ( model, Cmd.none )

        SetPw ->
            ( { model
                | passwordField = Nothing
                , pushPassword = model.passwordField |> Maybe.withDefault ""
              }
            , Cmd.none
            )

        Subscribe ->
            ( model, subscribe )

        Unsubscribe ->
            ( { model | message = "Unsubscribed!" }, pushUnsubscribe () )

        SubscribeCb res ->
            case res of
                Ok status ->
                    ( { model | message = status }, Cmd.none )

                Err err ->
                    ( { model | message = "Error!" }, log "ERROR" err )

        SendPushCb res ->
            case res of
                Ok status ->
                    ( { model | message = status }, Cmd.none )

                Err err ->
                    if is401 err then
                        ( { model | message = "Incorrect password!" }, Cmd.none )
                    else
                        ( { model | message = "Push error!" }, log "Push error:" err )

        FocusCb result ->
            case result of
                Ok _ ->
                    ( model, Cmd.none )

                Err err ->
                    ( model, log "Focus error:" err )



-- VIEW


buttonLabel : String -> Element msg
buttonLabel =
    text
        >> el
            [ width <| px 200
            , height <| px 30
            , Border.dashed
            , Border.color Color.black
            , Border.width 2
            , Font.center
            , padding 5
            ]


smallButtonLabel : String -> Element msg
smallButtonLabel =
    text
        >> el
            [ width <| px 100
            , height <| px 30
            , Border.dashed
            , Border.color Color.black
            , Border.width 2
            , Font.center
            , padding 5
            ]


view : Model -> Html Msg
view { message, pushField, passwordField, subscription } =
    layout [] <|
        el [] <|
            column
                [ center, centerY, spacing 7 ]
                [ decorativeImage [ width <| px 300 ] { src = "/tux.png" }
                , el [] <| text <| "> " ++ message
                , case subscription of
                    Just _ ->
                        Input.button []
                            { onPress = Just Unsubscribe
                            , label = buttonLabel "unsubscribe"
                            }

                    Nothing ->
                        Input.button []
                            { onPress = Just Subscribe
                            , label = buttonLabel "subscribe"
                            }
                , case pushField of
                    Just str ->
                        column
                            []
                            [ Input.text
                                [ id "input1"
                                , onEnter <| SendPush
                                ]
                                { onChange = Just <| Update Push
                                , text = str
                                , label = Input.labelAbove [] empty
                                , notice = Nothing
                                , placeholder = Nothing
                                }
                            , row
                                [ center, spacing 5, padding 4 ]
                                [ Input.button []
                                    { onPress = Just <| Cancel Push
                                    , label = smallButtonLabel "cancel"
                                    }
                                , Input.button []
                                    { onPress = Just SendPush
                                    , label = smallButtonLabel "send"
                                    }
                                ]
                            ]

                    Nothing ->
                        Input.button []
                            { onPress = Just <| Edit Push
                            , label = buttonLabel "push"
                            }
                , case passwordField of
                    Just str ->
                        column
                            []
                            [ Input.currentPassword
                                [ id "input2"
                                , onEnter <| SetPw
                                ]
                                { onChange = Just <| Update Pw
                                , text = str
                                , label = Input.labelAbove [] empty
                                , notice = Nothing
                                , placeholder = Nothing
                                }
                            , row
                                [ center, spacing 5, padding 4 ]
                                [ Input.button []
                                    { onPress = Just <| Cancel Pw
                                    , label = smallButtonLabel "cancel"
                                    }
                                , Input.button []
                                    { onPress = Just SetPw
                                    , label = smallButtonLabel "set"
                                    }
                                ]
                            ]

                    Nothing ->
                        Input.button []
                            { onPress = Just <| Edit Pw
                            , label = buttonLabel "set password"
                            }
                ]



-- HELPERS


onEnter : msg -> Attribute msg
onEnter msg =
    keyCode
        |> Decode.andThen
            (\code ->
                if code == 13 then
                    Decode.succeed msg
                else
                    Decode.fail ""
            )
        |> on "keydown"
        |> attribute


is401 : Http.Error -> Bool
is401 err =
    case err of
        Http.BadStatus { status } ->
            status.code == 401

        _ ->
            False



-- COMMANDS


focusOn : String -> Cmd Msg
focusOn =
    Dom.focus >> Task.attempt FocusCb


push : String -> String -> Cmd Msg
push str pw =
    Http.post "/api/push"
        (Http.jsonBody
            (object
                [ ( "password", Json.Encode.string pw )
                , ( "text", Json.Encode.string str )
                ]
            )
        )
        statusDecoder
        |> Http.send SendPushCb


saveSub : Subscription -> Cmd Msg
saveSub sub =
    Http.post "/api/subscribe"
        (Http.jsonBody
            (encodeSubscription sub)
        )
        statusDecoder
        |> Http.send SubscribeCb


subscribe : Cmd Msg
subscribe =
    Http.get "/api/config" serverKeyDecoder
        |> Http.send ServerKeyCb


validateSubscription : List Int -> Subscription -> Cmd Msg
validateSubscription key sub =
    Http.post "/api/validate"
        (Http.jsonBody
            (object
                [ ( "subscription", encodeSubscription sub )
                , ( "key", Json.Encode.list (List.map Json.Encode.int key) )
                ]
            )
        )
        (field "valid" bool)
        |> Http.send ValidateSubscriptionCb


log : String -> a -> Cmd Msg
log tag a =
    let
        _ =
            Debug.log tag a
    in
    Cmd.none



-- DECODERS


statusDecoder : Decoder String
statusDecoder =
    field "status" string


serverKeyDecoder : Decoder (List Int)
serverKeyDecoder =
    list int


subscriptionDecoder : Decoder Subscription
subscriptionDecoder =
    map2 Subscription
        (field "endpoint" string)
        (field "keys"
            (map2 Keys
                (field "auth" string)
                (field "p256dh" string)
            )
        )


savedDataDecoder : Decoder Saved
savedDataDecoder =
    map3 Saved
        (field "subscription" (nullable subscriptionDecoder))
        (field "serverKey" (list int))
        (field "pushPassword" string)



-- ENCODERS


encodeSubscription : Subscription -> Value
encodeSubscription sub =
    object
        [ ( "endpoint", Json.Encode.string sub.endpoint )
        , ( "keys"
          , object
                [ ( "p256dh", Json.Encode.string sub.keys.p256dh )
                , ( "auth", Json.Encode.string sub.keys.auth )
                ]
          )
        ]
