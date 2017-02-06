module GraphQL.Query.Builder.Structure exposing (..)

import GraphQL.Query.Builder.Arg as Arg


type Selection
    = FieldSelection Field
    | FragmentSpreadSelection FragmentSpread
    | InlineFragmentSelection InlineFragment


type Spec
    = AnySpec
    | IntSpec
    | FloatSpec
    | StringSpec
    | BooleanSpec
    | ObjectSpec (List Selection)
    | ListSpec Spec
    | NullableSpec Spec


type alias Field =
    { name : String
    , spec : Spec
    , fieldAlias : Maybe String
    , args : List ( String, Arg.Value )
    , directives : List Directive
    }


type FieldOption
    = FieldAlias String
    | FieldArgs (List ( String, Arg.Value ))
    | FieldDirective String (List ( String, Arg.Value ))


type alias Directive =
    { name : String
    , args : List ( String, Arg.Value )
    }


type alias FragmentDefinition =
    { name : String
    , typeCondition : String
    , spec : Spec
    , directives : List Directive
    }


type alias FragmentSpread =
    { name : String
    , directives : List Directive
    }


type alias InlineFragment =
    { typeCondition : Maybe String
    , directives : List Directive
    , spec : Spec
    }


type alias VariableDefinition =
    { name : String
    , variableType : String
    , defaultValue : Maybe Arg.Value
    }


type alias Query =
    { name : Maybe String
    , variables : List VariableDefinition
    , spec : Spec
    }


type QueryOption
    = QueryName String
    | QueryVariable String String (Maybe Arg.Value)


getBaseSpec : Spec -> Spec
getBaseSpec spec =
    case spec of
        ListSpec inner ->
            getBaseSpec inner

        NullableSpec inner ->
            getBaseSpec inner

        _ ->
            spec


type BuilderError
    = InvalidIntersection Spec Spec
    | InvalidFragment Spec


type Builder a
    = Builder (List BuilderError) a


mapBuilder : (a -> b) -> Builder a -> Builder b
mapBuilder f (Builder errs spec) =
    Builder errs (f spec)


appendSelections : List Selection -> List Selection -> List Selection
appendSelections a b =
    a ++ b


specIntersection : Spec -> Spec -> Result BuilderError Spec
specIntersection a b =
    case ( a, b ) of
        ( AnySpec, _ ) ->
            Ok b

        ( _, AnySpec ) ->
            Ok a

        ( ObjectSpec ssa, ObjectSpec ssb ) ->
            Ok (ObjectSpec (appendSelections ssa ssb))

        ( ListSpec innerA, ListSpec innerB ) ->
            specIntersection innerA innerB
                |> Result.map ListSpec

        ( NullableSpec innerA, NullableSpec innerB ) ->
            specIntersection innerA innerB
                |> Result.map NullableSpec

        ( IntSpec, IntSpec ) ->
            Ok IntSpec

        ( FloatSpec, FloatSpec ) ->
            Ok FloatSpec

        ( StringSpec, StringSpec ) ->
            Ok StringSpec

        ( BooleanSpec, BooleanSpec ) ->
            Ok BooleanSpec

        _ ->
            Err (InvalidIntersection a b)


specBuilderIntersection : Builder Spec -> Builder Spec -> Builder Spec
specBuilderIntersection (Builder errsA specA) (Builder errsB specB) =
    case specIntersection specA specB of
        Ok spec ->
            Builder (errsA ++ errsB) spec

        Err builderError ->
            Builder (errsA ++ errsB ++ [ builderError ]) specA


string : Builder Spec
string =
    Builder [] StringSpec


int : Builder Spec
int =
    Builder [] IntSpec


float : Builder Spec
float =
    Builder [] FloatSpec


bool : Builder Spec
bool =
    Builder [] BooleanSpec


list : Builder Spec -> Builder Spec
list =
    mapBuilder ListSpec


nullable : Builder Spec -> Builder Spec
nullable =
    mapBuilder NullableSpec


any : Builder Spec
any =
    Builder [] AnySpec


object : Builder Spec
object =
    Builder [] (ObjectSpec [])