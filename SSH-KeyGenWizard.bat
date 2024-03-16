@echo off
setlocal enabledelayedexpansion
REM chcp 886 >nul

rem Check for spaces in the current directory path
if "%CD: =%"=="%CD%" (goto :run) else (goto :space)

rem # Variables
:run
set "dir=%~dp0"
set "tempdir=%~dp0temp\"

REM # Cleanup
:clear
rd /s /q %tempdir%
del /q /f public
del /q /f private.ppk
del /q /f opnssh.pub
del /q /f opnssh
cls

REM Check for required software
:softcheck
cd %dir%
rd /s /q %tempdir% >nul 2>&1
echo.
if not exist "WinSCP.com" goto :downloadwinscp
if not exist "WinSCP.exe" goto :downloadwinscp
if not exist "libcrypto.dll" goto :downloadopnessh
if not exist "ssh-keygen.exe" goto :downloadopnessh
if not exist "plink.exe" goto :downloadplink

REM # Generate Open SSH keys using the EdDSA algorithm
:keysgen
echo.
echo Enter a passphrase for the private key
echo  P.S. Characters will not be displayed when typing - this is normal.
echo.
REM Generating a new private key
REM PS when using the system ssh-keygen the script breaks...
ssh-keygen.exe -t ed25519 -f opnssh

REM # Convert OpenSSH private key to Putty format
echo.
echo Enter the passphrase for the private key again (if it was set)
echo.
winscp.com /keygen opnssh /output=private.ppk

REM # Extract the public key from the private one for Putty
if exist public del /q /f
echo ---- BEGIN SSH2 PUBLIC KEY ---->> "public"
set counter=0
for /f "usebackq tokens=*" %%A IN ("private.ppk") DO @(set /a counter+=1) && @(if !counter! equ 3 (echo %%A>>"public")) && @(if !counter! GEQ 5 if !counter! LEQ 6 (echo %%A>>"public"))
echo ---- END SSH2 PUBLIC KEY ---->> "public"

REM Send RSA key to the server
echo. 
echo Copy the new key to the server?
echo.
choice /C YN /M "Y - yes, N - no"
if %errorlevel%==2 goto :datetime

REM # Server data request
:serverauth
echo.
set /p "host=Server IP address: "
set /p "sshport=SSH port of the server: "
set /p "user=User name: "
set /p "pass=User password for %user%: "
if not "%user%"=="root" (goto :connectcheck)

REM
:noroot
echo.
echo Executing as root is not recommended and has not been tested
echo Are you sure you want to continue?
echo.
choice /C RN /M "R - continue as root, N - no, change the user"
if %errorlevel%==2 goto :serverauth

REM # connection check
:connectcheck
echo Checking connection...
echo y | plink.exe -P %sshport% %user%@%host% -pw %pass% exit
if %errorlevel%==1 goto :serverauth
echo.
echo SSH connection to %host% established.
echo.
set "srvauth=yes"

REM Erase or leave old keys?
echo.
echo Leave old keys on the %host% host?
echo.
echo 1 - Add new one to the existing ones.
echo 2 - Delete all old keys and add the new one.
echo.
choice /C 12 /M "Your choice"
if %errorlevel%==1 set "clrak=>>"
if %errorlevel%==2 set "clrak=>"

REM # Copy the public key to the server, set chmod 600 permissions
:copykeytosrv
REM create home/%user%/.ssh in case it doesn't exist
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "mkdir /home/%user%/.ssh" > nul 2>&1

REM # extract the public key into a variable
for /f "usebackq delims=" %%A in ("opnssh.pub") do set "pubkey=%%A"

REM # Add the new public key
:addpubkey
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "echo %pass% | sudo -S echo "%pubkey%" %clrak% /home/%user%/.ssh/authorized_keys"
if %errorlevel%==1 goto :keycopyerr

REM # set chmod 600 permissions on authorized_keys
:chmo
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "echo %pass% | sudo -S chmod 600 /home/%user%/.ssh/authorized_keys"
if %errorlevel%==1 goto :keycopyerr

REM Enable access only via RSA
:passblock
echo.
echo.
echo Disable password authentication on the %host% host (for ALL users)?
echo  P.S. SSH access will only be possible via the private key.
echo.
choice /C YN /M "Y - disable password login, N - leave as is"
if %errorlevel%==2 goto :datetime

REM change PasswordAuthentication yes to PasswordAuthentication no in /etc/ssh/sshd_config on the host
:denypassauth
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "echo %pass% | sudo -S sed -i -E 's/#?PasswordAuthentication\s+(yes|no)/PasswordAuthentication no/g' /etc/ssh/sshd_config"
if %errorlevel%==1 goto :denypassautherr
echo.
echo.
echo SSH settings on the %host% host have been changed, authentication will only be possible via the private key,
echo  P.S. changes will take effect after its reboot.

REM Get current date and time hardcore
:datetime
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "year=%datetime:~0,4%"
set "month=%datetime:~4,2%"
set "day=%datetime:~6,2%"
set "hour=%datetime:~8,2%"
set "minute=%datetime:~10,2%"
set "moment=%year%%month%%day%"

REM # Collect keys into the Keys folder
:copykeytolocaldir
set "keydir=%dir%Keys\%moment%\"
md %keydir% > nul 2>&1
echo.
echo Collecting keys into the Keys folder:
move /y %dir%opnssh.pub %keydir%opnssh.pub
move /y %dir%public %keydir%public
move /y %dir%private.ppk %keydir%private.ppk
move /y %dir%opnssh %keydir%opnssh

REM Putty?
if "%srvauth%"=="yes" (echo.) else (goto :done)
if "%keycopyerr%"=="yes" (goto :done)
echo Create a desktop shortcut for quick access to %host% with one click?
echo  P.S. PuTTY application will be automatically downloaded if not installed on this PC.
echo.
choice /C YN /M "Y - create shortcut, N - I'll manage myself"
if %errorlevel%==1 goto :puttytime
goto :done

REM # Software download section
:downloadwinscp
md %tempdir% > nul 2>&1
cd %tempdir%
echo Downloading WinSCP...
echo.
curl -Lo WinSCP.zip https://winscp.net/download/WinSCP-6.3.1-Portable.zip
tar -xf WinSCP.zip
copy /y WinSCP.com %dir%
copy /y WinSCP.exe %dir%
goto :softcheck

:downloadplink
md %tempdir% > nul 2>&1
cd %tempdir%
echo Downloading plink...
echo.
curl -Lo plink.exe https://the.earth.li/~sgtatham/putty/latest/w32/plink.exe
copy /y plink.exe %dir%
goto :softcheck

:downloadopnessh
md %tempdir% > nul 2>&1
cd %tempdir%
echo Downloading OpenSSH-Win32...
echo.
curl -Lo OpenSSH-Win32.zip https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.5.0.0p1-Beta/OpenSSH-Win32.zip
tar -xf OpenSSH-Win32.zip
copy /y OpenSSH-Win32\ssh-keygen.exe %dir%
copy /y OpenSSH-Win32\libcrypto.dll %dir%
goto :softcheck

REM # Final information
:done
echo.
echo Operations completed, check the console for any errors.
echo.
echo New keys are located in the folder:
echo  %keydir% - save them in a secure location.
echo.
pause
pause
setlocal disabledelayedexpansion
exit


REM # Insufficient privileges to modify the authorized_keys file
:keycopyerr
set "keycopyerr=yes"
echo.
echo User %user% on the %host% server does not have sufficient privileges
echo to modify the /home/%user%/.ssh/authorized_keys file, possibly
echo it was created by another user including root.
echo Correct access privileges to it for SSH with RSA to work correctly
echo.
echo New key not sent to the %host% host.
echo.
goto :datetime

REM # No access
:denypassautherr
echo.
echo User %user% on the %host% server does not have sufficient
echo privileges to modify these settings.
echo.
goto :datetime

REM Putty
:puttytime
REM extract the path to the desktop of the current user into a variable
for /f "delims=" %%A in ('powershell.exe -Command "(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Desktop).Desktop"') do set "desktopFolder=%%A"
REM Create folders
md "%ProgramFiles%\PuTTY" > nul 2>&1
cd "%ProgramFiles%\PuTTY"
REM download Putty to Program Files
:downloadputty
if exist "putty.exe" goto :puttykeycopy
echo.
echo Downloading PuTTY...
echo.
curl -Lo putty.exe https://the.earth.li/~sgtatham/putty/latest/w32/putty.exe
REM copy the private key
:puttykeycopy
echo Copying the private key to the Putty folder
copy /y %keydir%private.ppk "%ProgramFiles%\PuTTY\private-%user%@%host%.ppk"

REM shortcut
set "vbsScript=%temp%\CreateShortcut.vbs"
del /q /f "%vbsScript%" > nul 2>&1
chcp 1251 >nul
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%vbsScript%"
echo sLinkFile = "%desktopFolder%\Putty-%user%@%host%.lnk" >> "%vbsScript%"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%vbsScript%"
echo oLink.TargetPath = "%ProgramFiles%\PuTTY\putty.exe" >> "%vbsScript%"
echo oLink.Arguments = "-ssh -P %sshport% -i ""%ProgramFiles%\PuTTY\private-%user%@%host%.ppk"" %user%@%host%" >> "%vbsScript%"
echo oLink.Save >> "%vbsScript%"
chcp 866 >nul
cscript /nologo "%vbsScript%"
if %errorlevel%==1 goto :linkerr
del /q /f "%vbsScript%"
echo.
echo A shortcut has been created on the desktop: %user%@%host%.lnk
echo.
goto :done

:linkerr
REM just in case, for safety...
del /q /f "%vbsScript%"
REM create a bat file for PuTTY
echo cd "C:\Program Files\PuTTY\"> "%desktopFolder%\Putty-%user%@%host%.bat"
echo start putty.exe -ssh -P %sshport% -i "%ProgramFiles%\PuTTY\private-%user%@%host%.ppk" %user%@%host%>> "%desktopFolder%\Putty-%user%@%host%.bat"
echo.
echo since CScript is not available on this PC, instead of a shortcut, a bat file %user%@%host%.bat has been created
echo.
goto :done

:space
REM just in case, for safety...
title WARNING
cls
echo.
echo The path to the current directory contains spaces, continuing
echo    operation may lead to errors and system corruption...
echo.
echo ---------- Script execution stopped ----------
echo.
echo For OS security, move this bat file to a directory without spaces
echo    in the path, for example: C:\Gen\ and run it from there.
echo.
timeout /t 1 > nul
title DANGER
cls
echo.
echo The path to the current directory contains spaces, continuing
echo    operation may lead to errors and system corruption...
echo.
echo ----------    close this window     ----------
echo.
echo For OS security, move this bat file to a directory without spaces
echo    in the path, for example: C:\Gen\ and run it from there.
echo.
timeout /t 1 > nul
goto :space
exit
