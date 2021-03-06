{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
module Generate.JavaScript.Variable
    ( fresh
    , canonical
    , qualified
    , native
    , coreNative
    , staticProgram
    , define
    , safe
    )
    where

import qualified Control.Monad.State as State
import Data.Monoid
import qualified Data.Set as Set
import qualified Data.Text as Text
import Data.Text (Text)

import qualified AST.Helpers as Help
import qualified AST.Module.Name as ModuleName
import qualified AST.Variable as Var
import qualified Elm.Package as Pkg
import qualified Generate.JavaScript.Builder as JS
import qualified Generate.JavaScript.Helpers as JS



-- FRESH NAMES


fresh :: State.State Int Text
fresh =
  do  n <- State.get
      State.modify (+1)
      return (Text.pack ("_v" ++ show n))



-- DEF NAMES


define :: Maybe ModuleName.Canonical -> Text -> JS.Expr -> [JS.Stmt]
define maybeHome name body =
  if not (Help.isOp name) then
    let
      jsName =
        maybe unqualified qualified maybeHome name
    in
      [ JS.VarDeclStmt [ JS.varDecl jsName body ] ]

  else
    case maybeHome of
      Nothing ->
        error "can only define infix operators at the top level"

      Just home ->
        let
          opsDictName =
            getOpsDictName (Var.TopLevel home)

          lvalue =
            JS.LBracket (JS.ref opsDictName) (JS.String name)
        in
          [ JS.VarDeclStmt [ JS.varDecl opsDictName (JS.refOrObject opsDictName) ]
          , JS.ExprStmt (JS.Assign JS.OpAssign lvalue body)
          ]



-- INSTANTIATE VARIABLES


canonical :: Var.Canonical -> JS.Expr
canonical (Var.Canonical home name) =
  if Help.isOp name then
    JS.BracketRef (JS.ref (getOpsDictName home)) (JS.String name)

  else
    case home of
      Var.Local ->
        JS.ref (unqualified name)

      Var.BuiltIn ->
        JS.ref (unqualified name)

      Var.Module moduleName@(ModuleName.Canonical _ rawName) ->
        if ModuleName.isNative rawName then
          native moduleName name

        else
          JS.ref (qualified moduleName name)

      Var.TopLevel moduleName ->
        JS.ref (qualified moduleName name)


unqualified :: Text -> Text
unqualified =
  safe


qualified :: ModuleName.Canonical -> Text -> Text
qualified moduleName name =
  moduleToText moduleName <> "$" <> name


native :: ModuleName.Canonical -> Text -> JS.Expr
native moduleName name =
  JS.obj [ moduleToText moduleName, name ]


coreNative :: Text -> Text -> JS.Expr
coreNative moduleName name =
  native (ModuleName.inCore ("Native." <> moduleName)) name


staticProgram :: JS.Expr
staticProgram =
  native (ModuleName.inVirtualDom "Native.VirtualDom") "staticProgram"


getOpsDictName :: Var.Home -> Text
getOpsDictName home =
  let
    moduleName =
      case home of
        Var.Local -> error "infix operators should only be defined in top-level declarations"
        Var.BuiltIn -> error "there should be no built-in infix operators"
        Var.Module name -> name
        Var.TopLevel name -> name
  in
    moduleToText moduleName <> "_ops"


moduleToText :: ModuleName.Canonical -> Text
moduleToText (ModuleName.Canonical (Pkg.Name user project) moduleName) =
  let
    safeUser =
      Text.replace "-" "_" user

    safeProject =
      Text.replace "-" "_" project

    safeModuleName =
      Text.replace "." "_" moduleName
  in
    "_" <> safeUser <> "$" <> safeProject <> "$" <> safeModuleName



-- SAFE NAMES


safe :: Text -> Text
safe name =
  if Set.member name jsReserveds then "$" <> name else name


jsReserveds :: Set.Set Text
jsReserveds =
  Set.fromList
    -- JS reserved words
    [ "null", "undefined", "Nan", "Infinity", "true", "false", "eval"
    , "arguments", "int", "byte", "char", "goto", "long", "final", "float"
    , "short", "double", "native", "throws", "boolean", "abstract", "volatile"
    , "transient", "synchronized", "function", "break", "case", "catch"
    , "continue", "debugger", "default", "delete", "do", "else", "finally"
    , "for", "function", "if", "in", "instanceof", "new", "return", "switch"
    , "this", "throw", "try", "typeof", "var", "void", "while", "with", "class"
    , "const", "enum", "export", "extends", "import", "super", "implements"
    , "interface", "let", "package", "private", "protected", "public"
    , "static", "yield"
    -- reserved by the Elm runtime system
    , "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9"
    , "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9"
    ]
