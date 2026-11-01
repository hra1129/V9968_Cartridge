@echo off
rem V9968UPD for Windows build script (Visual Studio 2022 MSBuild)
rem Builds both the Japanese (V9968UpdWin.exe) and English (V9968UpdWinEn.exe) versions.
setlocal
cd /d "%~dp0"

set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`%VSWHERE% -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set MSBUILD="%%i"
if not defined MSBUILD (
	echo MSBuild not found. Install Visual Studio 2022.
	exit /b 1
)

rem Japanese version (default UiLanguage=Ja). Copy the exe out before the
rem English build: rebuilding the same project makes MSBuild remove the
rem previous build's output from bin.
%MSBUILD% V9968UpdWin.sln -restore -p:Configuration=Release -v:minimal -nologo
if errorlevel 1 exit /b 1
copy /Y V9968UpdWin\bin\Release\net472\V9968UpdWin.exe . > nul
if errorlevel 1 exit /b 1

rem English version (UiLanguage=En)
%MSBUILD% V9968UpdWin\V9968UpdWin.csproj -restore -p:Configuration=Release -p:UiLanguage=En -v:minimal -nologo
if errorlevel 1 exit /b 1
copy /Y V9968UpdWin\bin\Release\net472\V9968UpdWinEn.exe . > nul
if errorlevel 1 exit /b 1
echo.
echo Output: %~dp0V9968UpdWin.exe
echo Output: %~dp0V9968UpdWinEn.exe
endlocal
