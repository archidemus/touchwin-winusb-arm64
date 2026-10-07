param(
 [string]$DllPath=(Join-Path $PSScriptRoot 'dist\EasyUSB2400_XJ.dll'),
 [string]$OutputPath=(Join-Path $PSScriptRoot 'results\bridge-test.json')
)
$reportDirectory=Split-Path -Parent $OutputPath
if($reportDirectory){New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null}
$ErrorActionPreference='Stop'
if([IntPtr]::Size -ne 4){throw 'Run this test with C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe (x86).'}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class HmiBridgeAbiTest {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern IntPtr LoadLibrary(string file);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi,SetLastError=true)] public static extern IntPtr GetProcAddress(IntPtr lib,string name);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int Ping();
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int Status(int index,[Out]byte[] bytes,int length);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int Read([Out]byte[] bytes,int length,int timeout);
 public static int CallPing(IntPtr lib){return ((Ping)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib,"HmiBridge_Ping"),typeof(Ping)))();}
 public static int CallStatus(IntPtr lib,int index,byte[] data){return ((Status)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib,"LPC2400_GetPipeStatus"),typeof(Status)))(index,data,data.Length);}
 public static int ReadUnsupportedPort(IntPtr lib){return ((Read)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib,"LPC2400_ReadPort2"),typeof(Read)))(new byte[1],1,10);}
}
'@
$dll=$DllPath
$handle=[HmiBridgeAbiTest]::LoadLibrary($dll)
if($handle -eq [IntPtr]::Zero){throw ('LoadLibrary error '+[Runtime.InteropServices.Marshal]::GetLastWin32Error())}
$ping=[HmiBridgeAbiTest]::CallPing($handle)
$inputStatus=New-Object byte[] 2
$outputStatus=New-Object byte[] 2
$inResult=[HmiBridgeAbiTest]::CallStatus($handle,0,$inputStatus)
$outResult=[HmiBridgeAbiTest]::CallStatus($handle,1,$outputStatus)
$unsupported=[HmiBridgeAbiTest]::ReadUnsupportedPort($handle)
$result=[ordered]@{Time=(Get-Date).ToString('o');ProcessBits=32;NativeOS='ARM64';LibraryLoaded=$true;Ping=$ping;InputStatusResult=$inResult;InputStatus=[BitConverter]::ToString($inputStatus);OutputStatusResult=$outResult;OutputStatus=[BitConverter]::ToString($outputStatus);UnsupportedPortResult=$unsupported;FirmwareWritePerformed=$false;Passed=($ping -eq 1 -and $inResult -eq 0 -and $outResult -eq 0 -and $unsupported -eq -1)}
$result | ConvertTo-Json | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result | ConvertTo-Json
if(-not $result.Passed){exit 1}
