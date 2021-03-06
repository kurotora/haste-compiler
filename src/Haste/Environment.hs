{-# LANGUAGE CPP #-}
-- | Paths, host bitness and other environmental information about Haste.
module Haste.Environment (
    hasteSysDir, jsmodSysDir, pkgSysDir, pkgSysLibDir, jsDir,
    hasteUserDir, jsmodUserDir, pkgUserDir, pkgUserLibDir,
    hasteGhcLibDir,
    hostWordSize,
    ghcPkgBinary, ghcBinary,
    hasteBinDir, hasteBinary, hastePkgBinary, hasteCabalBinary,
    closureCompiler, bootFile,
    portableHaste, hasteNeedsReboot
  ) where
import Control.Shell
import Data.Bits
import Foreign.C.Types (CIntPtr)
import System.Info
import System.IO.Unsafe
#if defined(PORTABLE)
import System.Environment (getExecutablePath)
#endif
import Haste.GHCPaths (ghcPkgBinary, ghcBinary)
import Haste.Version
import Paths_haste_compiler

-- | Subdirectory under Haste's root directory where all the stuff for this
--   version lives. Use "windows" instead of "mingw32", since this is what
--   cabal prefers.
hasteVersionSubDir :: FilePath
hasteVersionSubDir = arch ++ "-" ++ myos ++ "-" ++ myver
  where
    myos
      | os == "mingw32" = "windows"
      | otherwise       = os
    myver               = showBootVersion bootVersion

-- | Directory to search for GHC settings. Always equal to 'hasteSysDir'.
hasteGhcLibDir :: FilePath
hasteGhcLibDir = hasteSysDir

#if defined(PORTABLE)
-- | Was Haste built in portable mode or not?
portableHaste :: Bool
portableHaste = True

-- | Haste system directory. Identical to @hasteUserDir@ unless built with
--   -f portable.
hasteSysDir :: FilePath
hasteSysDir = dir </> hasteVersionSubDir
  where
    dir = joinPath . init . init . splitPath $ unsafePerformIO getExecutablePath

-- | Haste @bin@ directory.
hasteBinDir :: FilePath
hasteBinDir = takeDirectory $ unsafePerformIO getExecutablePath

-- | Haste JS file directory.
jsDir :: FilePath
jsDir = hasteSysDir </> "js"

#else

-- | Was Haste built in portable mode or not?
portableHaste :: Bool
portableHaste = False

-- | Haste system directory. Identical to 'hasteUserDir' unless built with
--   -f portable.
hasteSysDir :: FilePath
hasteSysDir = hasteUserDir

-- | Haste @bin@ directory.
hasteBinDir :: FilePath
hasteBinDir = unsafePerformIO $ getBinDir

-- | Haste JS file directory.
jsDir :: FilePath
jsDir = unsafePerformIO $ getDataDir
#endif

-- | Haste user directory. Usually ~/.haste.
hasteUserDir :: FilePath
Right hasteUserDir =
  unsafePerformIO . shell . withAppDirectory "haste" $ \d -> do
    return $ d </> hasteVersionSubDir

-- | Directory where user .jsmod files are stored.
jsmodSysDir :: FilePath
jsmodSysDir = hasteSysDir

-- | Base directory for Haste's system libraries.
pkgSysLibDir :: FilePath
pkgSysLibDir = hasteSysDir

-- | Directory housing package information.
pkgSysDir :: FilePath
pkgSysDir = hasteSysDir </> "package.conf.d"

-- | Directory where user .jsmod files are stored.
jsmodUserDir :: FilePath
jsmodUserDir = hasteUserDir

-- | Directory containing library information.
pkgUserLibDir :: FilePath
pkgUserLibDir = hasteUserDir

-- | Directory housing package information.
pkgUserDir :: FilePath
pkgUserDir = hasteUserDir </> "package.conf.d"

-- | Host word size in bits.
hostWordSize :: Int
hostWordSize = finiteBitSize (undefined :: CIntPtr)

-- | File extension of binaries on this system.
binaryExt :: String
binaryExt
  | os == "mingw32" = ".exe"
  | otherwise       = ""

-- | The main Haste compiler binary.
hasteBinary :: FilePath
hasteBinary = hasteBinDir </> "hastec" ++ binaryExt

-- | Binary for haste-pkg.
hastePkgBinary :: FilePath
hastePkgBinary = hasteBinDir </> "haste-pkg" ++ binaryExt

-- | Binary for haste-pkg.
hasteCabalBinary :: FilePath
hasteCabalBinary = hasteBinDir </> "haste-cabal" ++ binaryExt

-- | JAR for Closure compiler.
closureCompiler :: FilePath
closureCompiler = hasteSysDir </> "compiler.jar"

-- | File indicating whether Haste is booted or not, and for which Haste+GHC
--   version combo.
bootFile :: FilePath
bootFile = hasteUserDir </> "booted"

-- | Returns which parts of Haste need rebooting. A change in the boot file
--   format triggers a full reboot.
hasteNeedsReboot :: Bool
#ifdef PORTABLE
hasteNeedsReboot = False
#else
Right hasteNeedsReboot = unsafePerformIO . shell $ do
  (guard (not <$> isFile bootFile) >> pure True) `orElse` do
    bootedVerString <- withFile bootFile ReadMode hGetLine
    case parseBootVersion bootedVerString of
      Just (BootVer hasteVer ghcVer) ->
        return $ hasteVer /= hasteVersion || ghcVer /= ghcVersion
      _ ->
        return True
#endif
