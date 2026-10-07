param(
 [string]$CompilerPath='clang.exe',
 [string]$LinkerPath='ld.lld.exe',
 [string]$SdkLibraryPath=(Join-Path $PSScriptRoot 'tools\sdk-x86\c\um\x86')
)
$ErrorActionPreference='Stop'
$compiler=(Get-Command $CompilerPath -ErrorAction Stop).Source
$linker=(Get-Command $LinkerPath -ErrorAction Stop).Source
foreach($libraryName in @('kernel32.Lib','SetupAPI.Lib','winusb.lib')){
 if(-not (Test-Path -LiteralPath (Join-Path $SdkLibraryPath $libraryName))){throw "Missing SDK library $libraryName. Supply -SdkLibraryPath."}
}
$build=Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& $compiler '--target=i686-pc-windows-msvc' '-c' '-O2' '-ffreestanding' '-fno-builtin' '-fno-stack-protector' (Join-Path $PSScriptRoot 'easyusb_winusb.c') '-o' (Join-Path $build 'bridge.obj')
if($LASTEXITCODE){throw 'Compilation failed.'}
& $linker '-flavor' 'link' '/dll' '/noentry' '/machine:x86' '/nodefaultlib' ('/out:'+(Join-Path $build 'EasyUSB2400_XJ.dll')) ('/def:'+(Join-Path $PSScriptRoot 'easyusb_winusb.def')) (Join-Path $build 'bridge.obj') (Join-Path $SdkLibraryPath 'kernel32.Lib') (Join-Path $SdkLibraryPath 'SetupAPI.Lib') (Join-Path $SdkLibraryPath 'winusb.lib')
if($LASTEXITCODE){throw 'Link failed.'}
Get-FileHash -LiteralPath (Join-Path $build 'EasyUSB2400_XJ.dll') -Algorithm SHA256
