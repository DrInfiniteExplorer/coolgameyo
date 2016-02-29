@echo off

setlocal

(where dmd.exe >NUL 2>&1) &&  set _DMD=dmd
(where gdc.exe >NUL 2>&1) &&  set _GDC=gdc
(where ldc2.exe >NUL 2>&1) && set _LDC=ldc2
(where dub.exe >NUL 2>&1) && set _DUB=YES

if [""] == ["%_DMD%%_GDC%%_LDC%"] goto NoCompiler
if [""] == ["%_DUB%"] goto NoDub

for /D %%c in (%_DMD% %_GDC% %_LDC%) do set Compiler=%%c

call dub generate visuald --arch=x86_64 --combined --compiler=%Compiler% && goto Success
goto :EOF

:Success
	echo Environment set up successfully. Open project? [y]
	set /P Open=
	if ["%Open%"] == ["y"] start coolgameyo.sln
	goto :EOF

:NoCompiler
	echo You are missing a D2 compiler. Get one at http://dlang.org/download.html
	echo Open page? [y]
	set /P Open=
	if ["%Open%"] == ["y"] start http://dlang.org/download.html
	goto :EOF

:NoDub
	echo You are missing a DUB installation (D package manager). Get at https://code.dlang.org/download
	echo Open page? [y]
	set /P Open=
	if ["%Open%"] == ["y"] start https://code.dlang.org/download
	goto :EOF

