@echo off
REM TieJi DaMoXing MSIX installer. Right-click and choose Run as administrator.
setlocal
cd /d "%~dp0"

echo ============================================
echo  TieJi DaMoXing MSIX Installer
echo ============================================
echo.
echo  This package is signed with a self-signed
echo  test certificate. Windows will show an
echo  Unknown publisher warning. It is safe to
echo  continue for internal distribution.
echo.
echo  STEP 1 install signing certificate admin needed
echo.

powershell -NoProfile -Command "$sig=Get-AuthenticodeSignature -FilePath '.\TieJiDaMoXing-1.0.0.1-x64.msix'; $c=$sig.SignerCertificate; $c|Export-Certificate -FilePath '.\_tieji.cer' -Type CERT >$null; try { Import-Certificate -FilePath '.\_tieji.cer' -CertStoreLocation 'Cert:\LocalMachine\Root' >$null; Import-Certificate -FilePath '.\_tieji.cer' -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' >$null; Write-Host 'Cert installed to machine trusted root' } catch { Write-Host 'Admin import failed'; Import-Certificate -FilePath '.\_tieji.cer' -CertStoreLocation 'Cert:\CurrentUser\Root' >$null; Import-Certificate -FilePath '.\_tieji.cer' -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' >$null; Write-Host 'Cert installed to CURRENT USER stores (try Developer Mode if this still fails)' }"

if errorlevel 1 goto CERTFAIL

echo.
echo  STEP 2 install app package
echo.
powershell -NoProfile -Command "Add-AppxPackage -Path '.\TieJiDaMoXing-1.0.0.1-x64.msix'"

if errorlevel 1 goto APPFAIL

echo.
echo  Done. Find TieJi in the Start menu.
goto END

:CERTFAIL
echo.
echo  ERROR could not import certificate.
echo  Right-click this file and choose Run as administrator.
echo  Or enable Developer Mode in Windows settings.
goto END

:APPFAIL
echo.
echo  ERROR install failed. Code 0x800B0109 means cert not trusted.
echo  Run this script as administrator, or enable Developer Mode.
goto END

:END
if exist ".\_tieji.cer" del /q ".\_tieji.cer"
pause
