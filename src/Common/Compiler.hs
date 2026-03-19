{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NumericUnderscores #-}

module Common.Compiler (writeRedeemer, mpa) where

-- Cardano / Plutus
import           Cardano.Api
import           Plutus.V1.Ledger.Address
import           Plutus.V1.Ledger.Credential
import           Plutus.V1.Ledger.Value
import           PlutusTx.Prelude           hiding (Semigroup (..), unless)

-- Ledger / Wallet
import           Ledger                     hiding (mint, singleton)
import           Ledger.Ada                 as Ada
import           Wallet.Emulator.Wallet     (Wallet, knownWallet, mockWalletPaymentPubKeyHash)

-- Project modules
import           Common.TypesV1
import           Common.Utils
import qualified Common.UtilsV1             as U

-- Standard Prelude (minimal)
import           Prelude                    (IO)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

wallet :: Integer -> Wallet
wallet = knownWallet

pkh :: Integer -> PaymentPubKeyHash
pkh = mockWalletPaymentPubKeyHash . wallet

--------------------------------------------------------------------------------
-- Default Mint Parameters
--------------------------------------------------------------------------------

mpa :: MintParams
mpa = MintParams
    { treasury   = pkh 1
    , referral   = pkh 1
    , referralTx = []
    , mpAdaAmount = 200_000_000
    }

--------------------------------------------------------------------------------
-- IO
--------------------------------------------------------------------------------

writeRedeemer :: MintParams -> IO ()
writeRedeemer =
    writeJSON "output/redeemer.json"
