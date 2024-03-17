@echo off
setlocal enabledelayedexpansion
title SSH-KeyGenWizard

REM # Compatibility check
:syschek
REM # Path spaces check
if not "%CD: =%"=="%CD%" goto :space
REM # curl ?
curl -h
if %errorlevel%==1 (cls
echo Unfortunately, your OS is not supported.
pause
exit)
REM # Access rights check
md "%ProgramFiles%\chk00"
if %errorlevel%==1 (cls
echo Please restart the script with administrator privileges.
pause
exit)

REM # Start
:run
rem # Variables
set "dir=%~dp0"
set "tempdir=%~dp0temp\"

REM # Cleaning
:clean
rd /s /q %tempdir%
rd /s /q "%ProgramFiles%\chk00"
del /q /f public
del /q /f private.ppk
del /q /f opnssh.pub
del /q /f opnssh
cls

REM Software check
:softchek
cd %dir%
rd /s /q %tempdir% >nul 2>&1
echo.
if not exist "WinSCP.com" goto :downloadwinscp
if not exist "WinSCP.exe" goto :downloadwinscp
if not exist "libcrypto.dll" goto :downloadopnessh
if not exist "ssh-keygen.exe" goto :downloadopnessh
if not exist "plink.exe" goto :downloadplink

REM # OpenSSH keys generation using EdDSA algorithm
REM PS when using the system ssh-keygen, the script breaks..
:keysgen
echo.
echo Enter a password for the private key (optional),
echo  P.S. Characters will not be displayed when typing - this is normal.
ssh-keygen.exe -t ed25519 -f opnssh

REM # Converting OpenSSH private key to Putty format
REM # PuTTYgen always leads to a graphical interface where further actions for an ordinary user are not obvious
REM # ssh-keygen does not support converting EdDSA private key to any other
echo.
echo Enter the password of the private key again (if it was set)
winscp.com /keygen opnssh /output=private.ppk

REM # Extracting public key from private for Putty
echo ---- BEGIN SSH2 PUBLIC KEY ----> "public"
set counter=0
for /f "usebackq tokens=*" %%A IN ("private.ppk") DO @(set /a counter+=1) && @(if !counter! equ 3 (echo %%A>>"public")) && @(if !counter! GEQ 5 if !counter! LEQ 6 (echo %%A>>"public"))
echo ---- END SSH2 PUBLIC KEY ---->> "public"

REM # Sending key to the server
echo. 
echo Copy the new key to the server?
choice /C YN /M "Y - yes, N - no"
if %errorlevel%==2 goto :datetime

REM # Server data request
:serverauth
echo.
set /p "host=Server IP address: "
set /p "sshport=Server SSH port: "
set /p "user=User name: "
set /p "pass=User password %user%: "
if not "%user%"=="root" goto :connectchek

REM # Not recommended under root
:noroot
echo.
echo Running as root is not recommended and not tested
choice /C RN /M "R - continue as root, N - change user"
if %errorlevel%==2 goto :serverauth


REM # Connection check
:connectchek
echo Checking connection...
echo y | plink.exe -P %sshport% %user%@%host% -pw %pass% exit
if %errorlevel%==1 goto :serverauth
set "srvauth=yes"
echo.
echo SSH connection with %host% established.

REM Delete or keep old keys?
echo.
echo Keep old keys on host %host%?
echo.
echo 1 - Add new to existing.
echo 2 - Delete all old keys and add new.
echo.
choice /C 12 /M "Your choice"
if %errorlevel%==1 set "clrak=>>"
if %errorlevel%==2 set "clrak=>"

REM # Copy the public key to the server, set chmod 600
:copykeytosrv
REM creating home/%user%/.ssh in case it doesn't exist
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "mkdir /home/%user%/.ssh" > nul 2>&1

REM # extracting the public key into a variable
for /f "usebackq delims=" %%A in ("opnssh.pub") do set "pubkey=%%A"

REM # Add new public key to the server, set chmod 600 on authorized_keys
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "echo %pass% | sudo -S sh -c 'echo %pubkey% %clrak% /home/%user%/.ssh/authorized_keys && chown %user% /home/%user%/.ssh/authorized_keys && chmod 600 /home/%user%/.ssh/authorized_keys'"
if %errorlevel%==1 (set "keycopyerr=yes"
echo.
echo User %user% on server %host% does not have sufficient privileges
echo to modify the file /home/%user%/.ssh/authorized_keys
echo.
echo New key not sent to host %host%.
goto :datetime)

REM Enable access only by private key
:passblock
echo.
echo Disable SSH password authentication on host %host% (for ALL users)?
echo  P.S. SSH access will only be possible using the private key.
echo.
choice /C BS /M "B - block password login, S - leave as is"
if %errorlevel%==2 goto :datetime

REM # Change PasswordAuthentication yes to PasswordAuthentication no in /etc/ssh/sshd_config on the host
:denypassauth
plink.exe -batch -P %sshport% %user%@%host% -pw %pass% "echo %pass% | sudo -S sed -i -E 's/#?PasswordAuthentication\s+(yes|no)/PasswordAuthentication no/g' /etc/ssh/sshd_config"
if %errorlevel%==1 (echo.
echo User %user% on server %host% does not have
echo  sufficient privileges to modify these settings.
goto :datetime)
echo.
echo.
echo SSH host %host% settings changed, authentication is only possible using the private key,
echo  P.S. changes will take effect after its reboot.

REM # Getting current date and time hardcore
:datetime
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "year=%datetime:~0,4%"
set "month=%datetime:~4,2%"
set "day=%datetime:~6,2%"
set "hour=%datetime:~8,2%"
set "minute=%datetime:~10,2%"
set "moment=%year%%month%%day%-%hour%%minute%"


REM # Collecting keys in the Keys folder
:copykeytolocaldir
set "keydir=%dir%Keys\%moment%\"
md %keydir% > nul 2>&1
cd %dir% > nul 2>&1
echo.
echo Collecting keys in the Keys folder:
move /y opnssh.pub %keydir%
move /y public %keydir%
move /y private.ppk %keydir%
move /y opnssh %keydir%

REM Putty?
if not "%srvauth%"=="yes" goto :done
if "%keycopyerr%"=="yes" goto :done
echo.
echo Create a desktop shortcut for quick access to %host% in one click (authentication by private key)?
echo  P.S. PuTTY application will be automatically downloaded if not installed on this PC.
choice /C YN /M "Y - create shortcut, N - I'll handle it myself"
if %errorlevel%==1 goto :puttytime
goto :done

REM # Software download section
:downloadwinscp
md %tempdir% > nul 2>&1
cd %tempdir%
echo Downloading WinSCP...
echo.
curl -Lo WinSCP.zip https://winscp.net/download/WinSCP-6.3.1-Portable.zip
if %errorlevel%==0 (tar -xf WinSCP.zip
copy /y WinSCP.com %dir%
copy /y WinSCP.exe %dir%
goto :softchek)
Echo Unable to download WinSCP, please try again later.
pause
exit
:downloadplink
md %tempdir% > nul 2>&1
cd %tempdir%
echo Downloading plink...
echo.
curl -Lo plink.exe https://the.earth.li/~sgtatham/putty/latest/w32/plink.exe
if %errorlevel%==0 (copy /y plink.exe %dir%
goto :softchek)
Echo Unable to download plink, please try again later.
pause
exit
:downloadopnessh
md %tempdir% > nul 2>&1
cd %tempdir%
echo Downloading OpenSSH-Win32...
echo.
curl -Lo OpenSSH-Win32.zip https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.5.0.0p1-Beta/OpenSSH-Win32.zip
if %errorlevel%==0 (tar -xf OpenSSH-Win32.zip
copy /y OpenSSH-Win32\ssh-keygen.exe %dir%
copy /y OpenSSH-Win32\ssh-add.exe %dir%
copy /y OpenSSH-Win32\libcrypto.dll %dir%
goto :softchek)
Echo Unable to download OpenSSH, please try again later.
pause
exit

REM # Final information
:done
echo.
echo Operations completed, check the console for any errors.
echo.
echo New keys are located in the folder:
echo  %keydir% - keep them in a secure place.
echo.
pause
setlocal disabledelayedexpansion
exit

REM Putty
:puttytime
if exist "%ProgramFiles%\PuTTY\putty.exe" goto :puttykeycopy
REM # Download Putty to Program Files
:downloadputty
md "%ProgramFiles%\PuTTY" > nul 2>&1
cd "%ProgramFiles%\PuTTY"
echo.
echo Downloading PuTTY...
curl -Lo putty.exe https://the.earth.li/~sgtatham/putty/latest/w32/putty.exe
if %errorlevel% GEQ 1 (echo Unable to download PuTTY.
goto :done)

REM # Copy the private key
:puttykeycopy
echo Copying the private key to the Putty folder:
copy /y %keydir%private.ppk "%ProgramFiles%\PuTTY\private-%user%@%host%.ppk"

REM # Shortcut
powershell -Command "$desktopFolder = [Environment]::GetFolderPath('Desktop'); $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut(\"$desktopFolder\\Putty-%user%@%host%.lnk\"); $Shortcut.TargetPath = \"%ProgramFiles%\\PuTTY\\putty.exe\"; $Shortcut.Arguments = \"-ssh -P %sshport% -i `\"%ProgramFiles%\PuTTY\private-%user%@%host%.ppk`\" %user%@%host%\"; $Shortcut.Save()"
if %errorlevel% GEQ 1 (echo.
echo Failed to create shortcut on the desktop for user %username%...
goto :done)
echo.
echo Desktop shortcut created for user %username%: %user%@%host%.lnk
goto :done

:space
REM # For security reasons...
title WARNING
cls
echo.
echo The path to the current directory contains spaces, continuing operation
echo             may lead to errors and system damage...
echo.
echo ---------- Script execution aborted ----------
echo.
echo For OS security, move this bat file to a directory where there are
echo  no spaces in the path, for example: C:\Gen\ and run it from there.
echo.
timeout /t 1 > nul
title DANGER
cls
echo.
echo The path to the current directory contains spaces, continuing operation
echo             may lead to errors and system damage...
echo.
echo ----------    close this window     ----------
echo.
echo For OS security, move this bat file to a directory where there are
echo  no spaces in the path, for example: C:\Gen\ and run it from there.
echo.
timeout /t 1 > nul
goto :space
exit