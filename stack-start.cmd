@Echo Off
:: Nginx + PHP-FPM for Windows
CD /D "%~dp0"

::Settings
SET LogFile=.\%~n0.log
SET TimestampFormat=[%%DATE%% %%TIME:~,8%%]
SET WatcherTimeout=10

IF "%~1"=="" (
	START "" "%~dp0hidcon\hidcon" %~nx0 restart_hidden
	CALL ECHO.>>"%LogFile%"
	CALL :Log Loader started
	EXIT
)

SET PATH=%~dp0hidcon;%~dp0nginx;%~d0\PHP7;%PATH%

:: PHP
CALL :Log Starting PHP-FPM...
:start-php
PUSHD "%~d0\PHP7"
START hidcon php-cgi.exe -b 127.0.0.1:9123 -c ".\php.ini"
POPD
If "%1"=="restart" (
    Call :Log PHP-FPM crashed, restarting
    Exit /B
)

:: Nginx
CALL :Log Starting Nginx...
:start-nginx
PUSHD .\nginx
START nginx
POPD

TaskKill /F /IM "hidcon.exe"

SET LockFile=.\.loader.lock
ECHO.>"%LockFile%"

:Watcher
Ping -n %WatcherTimeout% 127.0.0.1>nul 2>nul
TaskList /FI "imagename EQ php-cgi.exe" /FO:CSV|FindStr /I /C:"php-cgi.exe">nul||CALL :start-php restart
IF NOT EXIST "%LockFile%" (
    CALL :Log Lockfile not found, starting shutdown process

    PUSHD .\nginx
    nginx -s stop
    POPD

    TaskKill /F /T /IM php-cgi.exe

    CALL :Log Loader stopped
    EXIT
)
GoTo :Watcher

:Log
	CALL ECHO %TimestampFormat% %*>>"%LogFile%"
	EXIT /B
	