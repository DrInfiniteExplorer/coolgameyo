set /P latest= <latestBuildType
if "%1" == "client" goto client
if "%1" == "server" goto server
..\cgy\%latest%\cgy.exe --settingsFile=debugSettings.json  --playerName=DebugPlayer
goto exit
:client
..\cgy\%latest%\cgy.exe --settingsFile=debugSettings.json  --playerName=DebugPlayer --joinGame=127.0.0.1
goto exit
:server
..\cgy\%latest%\cgy.exe --settingsFile=debugSettings.json  --playerName=DebugPlayer --hostGame=880128
goto exit
:exit
