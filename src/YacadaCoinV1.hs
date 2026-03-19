{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE NumericUnderscores #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# HLINT ignore "Use newtype instead of data" #-}

module YacadaCoinV1 
    ( yacadaSymbol
    , policy
    , yacadaWriteSerialisedScriptV1
    ) where

-- Cardano / Plutus
import           Cardano.Api (PlutusScriptV1, writeFileTextEnvelope)
import           Cardano.Api.Shelley (PlutusScript(..))
import           Codec.Serialise
import qualified Data.ByteString.Lazy  as LBS
import qualified Data.ByteString.Short as SBS
import qualified PlutusTx

-- Ledger
import           Ledger hiding (mint, singleton)
import           Ledger.Value as Value
import qualified Plutus.Script.Utils.V1.Scripts as Scripts
import qualified Plutus.Script.Utils.V1.Typed.Scripts as PSU.V1
import qualified Plutus.V1.Ledger.Api as PlutusV1
import           PlutusTx.Prelude hiding (Semigroup(..), unless)

-- Utils / Types
import qualified Common.UtilsV1 as U
import qualified Common.TypesV1 as T

-- Standard
import           Control.Monad (void)
import           Prelude (IO)

--------------------------------------------------------------------------------
-- Minting Policy
--------------------------------------------------------------------------------

{-# INLINABLE yacadaPolicy #-}
yacadaPolicy :: BuiltinData -> PlutusV1.ScriptContext -> Bool
yacadaPolicy redeemer' ctx =
    if noReferral
        then traceIfFalse "Validation failed (no referral)" (allTrue [mintCheck, noRefQtCheck])
        else traceIfFalse "Validation failed" (allTrue [mintCheck, qtCheck, adaCheck])
  where
    mp :: T.MintParams
    mp = PlutusTx.unsafeFromBuiltinData redeemer'

    info = U.info ctx

    minted :: Value
    minted = txInfoMint info

    flatMinted = flattenValue minted

    ownSymbol = ownCurrencySymbol ctx

    -- Checks
    mintCheck :: Bool
    mintCheck = traceIfFalse "Not Minted"
        (U.hashMinted ownSymbol flatMinted)

    mintedAmount :: Integer
    mintedAmount = U.mintedQtOfValue ownSymbol flatMinted 0

    treasuryAda :: Integer
    treasuryAda = U.sentAda ctx (T.treasury mp)

    referralAda :: Integer
    referralAda = U.sentAda ctx (T.referral mp)

    expectedMint :: Integer
    expectedMint = U.calculateYacada (treasuryAda + referralAda)

    qtCheck :: Bool
    qtCheck = traceIfFalse "Wrong quantity"
        (mintedAmount == expectedMint)

    noRefQtCheck :: Bool
    noRefQtCheck = traceIfFalse "Should mint zero"
        (mintedAmount == 0)

    adaCheck :: Bool
    adaCheck = traceIfFalse "Incorrect ADA distribution"
        (treasuryAda + referralAda == T.mpAdaAmount mp)

    treasuryAddr :: Address
    treasuryAddr = pubKeyHashAddress (T.treasury mp) Nothing

    referralAddr :: Address
    referralAddr = pubKeyHashAddress (T.referral mp) Nothing

    noReferral :: Bool
    noReferral = treasuryAddr == referralAddr

    allTrue :: [Bool] -> Bool
    allTrue = all id

--------------------------------------------------------------------------------
-- Policy Wrapper
--------------------------------------------------------------------------------

policy :: Scripts.MintingPolicy
policy =
    PlutusV1.mkMintingPolicyScript
        $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = PSU.V1.mkUntypedMintingPolicy yacadaPolicy

--------------------------------------------------------------------------------
-- Currency Symbol
--------------------------------------------------------------------------------

{-# INLINABLE yacadaSymbol #-}
yacadaSymbol :: CurrencySymbol
yacadaSymbol = Scripts.scriptCurrencySymbol policy

--------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------

yacadaScriptV1 :: PlutusV1.Script
yacadaScriptV1 = PlutusV1.unMintingPolicyScript policy

yacadaSerialisedScriptV1 :: PlutusScript PlutusScriptV1
yacadaSerialisedScriptV1 =
    PlutusScriptSerialised
        . SBS.toShort
        . LBS.toStrict
        $ serialise yacadaScriptV1

yacadaWriteSerialisedScriptV1 :: IO ()
yacadaWriteSerialisedScriptV1 =
    void $
        writeFileTextEnvelope
            "output/yacada-policy-V1.plutus"
            Nothing
            yacadaSerialisedScriptV1
