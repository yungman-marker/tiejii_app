@echo off
setlocal EnableExtensions

REM Anchor everything to the folder where THIS script lives,
REM so it works no matter what the current directory is
REM (double-click / "Run as administrator" often start in C:\Windows\system32).
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"

echo ===============================================
echo   Tieji Desktop Installer v8
echo ===============================================
echo.
echo Install folder: %DIR%
echo.

if exist "%DIR%\tiejii_app.msix" goto msix_ok
echo [ERROR] Missing file: tiejii_app.msix
echo         Put install.cmd together with tiejii_app.msix.
echo.
pause
goto finish

:msix_ok
REM Detect administrator: net session succeeds only with admin rights
net session >nul 2>&1
if %errorlevel%==0 (set STORE=LocalMachine) else (set STORE=CurrentUser)

if not "%STORE%"=="LocalMachine" (
echo NOTE: Not running as administrator.
echo       Newer Windows requires the signing cert in the MACHINE-trusted
echo       root store (LocalMachine\Root). If step 2 fails, close this window,
echo       right-click install.cmd and choose "Run as administrator", then re-run.
echo.
)

echo [1/3] Extracting signing cert from .msix and trusting it (%STORE% Root)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%DIR%\tiejii_app.msix'; $c=(Get-AuthenticodeSignature -FilePath $p).SignerCertificate; if(-not $c){Write-Error 'MSIX_NOT_SIGNED'; exit 1}; Write-Host ('  Signer: '+$c.Subject); $c | Export-Certificate -FilePath '%DIR%\_signtmp.cer' -Type CERT -ErrorAction Stop; Import-Certificate -FilePath '%DIR%\_signtmp.cer' -CertStoreLocation Cert:\%STORE%\Root -ErrorAction SilentlyContinue | Out-Null; Import-Certificate -FilePath '%DIR%\_signtmp.cer' -CertStoreLocation Cert:\%STORE%\TrustedPeople -ErrorAction SilentlyContinue | Out-Null; Remove-Item '%DIR%\_signtmp.cer' -ErrorAction SilentlyContinue; Write-Host '  OK'"
if errorlevel 1 goto err_cert
echo.

echo [2/3] Installing APPX package (may take 10-30s)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-AppxPackage -Path '%DIR%\tiejii_app.msix'"
if errorlevel 1 goto err_appx
echo         OK.
echo.

echo [3/3] Done. Package info:
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -Name com.tiejii.app | Format-Table Name,Version -AutoSize | Out-String | Write-Host"
echo.
echo Installation complete! Look for the app in the Start menu.
goto finish

:err_cert
echo.
echo [ERROR] Could not extract/trust the signing certificate.
echo   The .msix may be unsigned or corrupted. Re-sign it properly.
goto finish

:err_appx
echo.
echo [ERROR] APPX installation failed.
echo.
echo If error is 0x800B0109 (signing root cert not trusted):
echo   This PC needs the cert in the MACHINE-trusted root store.
echo   -> Close this window. Right-click install.cmd and choose
echo      "Run as administrator", then run it again.
echo.
echo If error mentions sideloading / group policy:
echo   Enable Developer Mode (Settings - Privacy and security - For developers),
echo   or ask IT to allow AppxPackage sideloading (AllowSideloadedPackages).
goto finish

:finish
echo.
pause
