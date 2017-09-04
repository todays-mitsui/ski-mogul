{-# LANGUAGE OverloadedStrings #-}

module SpecExpr (
  specExprIsFreeIn,
  specExprResolve,
  specExprUnlambda,
  specExprSubst,
  specExprCompile,
  specExprApply
) where


import Test.Hspec
-- import Control.Exception (evaluate)

import Control.Monad.Trans   (liftIO)
import Text.Parsec           (parse)
import Text.Parsec.Error     (ParseError, errorMessages)
import qualified Data.ByteString.Char8 as BS

import Data
import Parser hiding (context)
import qualified Parser as P
import Expr


readSampleContext :: IO (Either ParseError Context)
readSampleContext = parse P.context "" <$> BS.readFile "test/sample.context"

--------------------------------------------------------------------------------

specExprIsFreeIn = describe "x `Expr.isFreeIn` expr" $ do
  context "when x is free in expr" $ do
    it "retrun True" $
      x `isFreeIn` (y :^ Var y :$ Var x)

  context "when x is bound in expr" $ do
    it "retrun False" $
      not (x `isFreeIn` (x :^ Var x :$ Var y))


specExprResolve = describe "Expr.resolve" $ do
  it "resolve ^x.x to i" $ do
    resolve x (Var x) `shouldBe` i

  it "resolve ^x.y to `ky" $ do
    resolve x (Var y) `shouldBe` (k :$ Var y)

  it "resolve ^x.``fgx to `fg" $ do
    resolve x (f :$ g :$ Var x) `shouldBe` (f :$ g)

  it "resolve ^x.``fx`gx to ``s^x.`fx^x.`gx" $ do
    resolve x (f :$ Var x :$ (g :$ Var x))
      `shouldBe` (s :$ resolve x (f :$ Var x) :$ resolve x (g :$ Var x))


specExprUnlambda = describe "Expr.unlambda" $ do
  it "resolve ^x.x to i" $ do
    unlambda (x :^ Var x) `shouldBe` i

  it "resolve ^x.y to `ky" $ do
    unlambda (x :^ Var y) `shouldBe` (k :$ Var y)

  it "resolve ^xy.`yx to ``s`k`sik" $ do
    unlambda (x :^ y :^ Var y :$ Var x)
      `shouldBe` (s :$ (k :$ (s :$ i)) :$ k)

  it "resolve ^x.`xx to ``sii" $ do
    unlambda (x :^ Var x :$ Var x) `shouldBe` (s :$ i :$ i)

  -- The Y combinator, discovered by Haskell B. Curry
  it "resolve ^x.`^y.`x`yy^y.`x`yy to ``s``s``s`ksk`k`sii``s``s`ksk`k``sii" $ do
    unlambda (x :^ (y :^ Var x :$ (Var y :$ Var y)) :$ (y :^ Var x :$ (Var y :$ Var y)))
      `shouldBe` (s :$ (s :$ (s :$ (k :$ s) :$ k) :$ (k :$ (s :$ i :$ i))) :$ (s :$ (s :$ (k :$ s) :$ k) :$ (k :$ (s :$ i :$ i))))


specExprSubst = describe "Expr.subst" $ do
  it "substitute ISZERO combination of subfunctions" $ do
    Right context <- liftIO readSampleContext
    subst context (Var (Ident "ISZERO"))
      `shouldBe` (n :^ (Var n :$ (Ident "_" :^ x :^ y :^ Var y)) :$ (x :^ y :^ Var x))

  it "dosent substitute undefined variable" $ do
    Right context <- liftIO readSampleContext
    subst context (Var (Ident "FOO"))
      `shouldBe` Var (Ident "FOO")

  it "dosent substitute undefined variable" $ do
    Right context <- liftIO readSampleContext
    subst context (Var (Ident "NAMED"))
      `shouldBe` (Ident "NAMED" :^ Var (Ident "NAMED") :$ Var (Ident "NAMED"))


specExprCompile = describe "Expr.compile" $ do
  it "compile ISZERO to SKI Combinator" $ do
    Right context <- liftIO readSampleContext
    compile context (Var (Ident "ISZERO"))
      `shouldBe` (s :$ (s :$ i :$ (k :$ (k :$ (k :$ i)))) :$ (k :$ k))

  it "dosent compile undefined variable" $ do
    Right context <- liftIO readSampleContext
    compile context (Var (Ident "FOO"))
      `shouldBe` Var (Ident "FOO")

  it "dosent compile undefined variable" $ do
    Right context <- liftIO readSampleContext
    compile context (Var (Ident "NAMED"))
      `shouldBe` (s :$ i :$ i)

specExprApply = describe "Expr.apply" $ do
  it "..." $ do
    Right context <- liftIO readSampleContext
    apply context (Ident "FLIP") [Var (Ident "F"), Var (Ident "X"), Var (Ident "Y")]
      `shouldBe` (Var (Ident "F") :$ Var (Ident "Y") :$ Var (Ident "X"))

  --------------------------------------------------------------------------------

x = Ident "x"
y = Ident "y"
z = Ident "z"

n = Ident "n"

f = s :$ k :$ k
g = k :$ i