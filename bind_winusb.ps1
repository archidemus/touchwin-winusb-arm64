param([switch]$Apply,[Parameter(Mandatory=$true)][string]$InstanceId)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
public class HmiWinUsbBinding {
 [StructLayout(LayoutKind.Sequential)] public struct DeviceData {public int Size;public Guid Class;public uint DevInst;public IntPtr Reserved;}
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] public struct InstallParams {public int Size;public uint Flags,FlagsEx;public IntPtr Parent,Callback,Context,Queue,ClassReserved;public uint Reserved;[MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)]public string Path;}
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] public struct DriverData {public int Size;public uint Type;public IntPtr Reserved;[MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)]public string Description;[MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)]public string Manufacturer;[MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)]public string Provider;public uint TimeLow,TimeHigh;public ulong Version;}
 [DllImport("setupapi.dll",SetLastError=true)] static extern IntPtr SetupDiCreateDeviceInfoList(IntPtr c,IntPtr w);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiOpenDeviceInfo(IntPtr s,string id,IntPtr w,uint f,ref DeviceData d);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiGetDeviceInstallParams(IntPtr s,ref DeviceData d,ref InstallParams p);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiSetDeviceInstallParams(IntPtr s,ref DeviceData d,ref InstallParams p);
 [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiBuildDriverInfoList(IntPtr s,ref DeviceData d,uint t);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiEnumDriverInfo(IntPtr s,ref DeviceData d,uint t,uint i,ref DriverData p);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiSetSelectedDriver(IntPtr s,ref DeviceData d,ref DriverData p);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiSetDeviceRegistryProperty(IntPtr s,ref DeviceData d,uint prop,byte[] b,uint size);
 [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiCallClassInstaller(uint f,IntPtr s,ref DeviceData d);
 [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);
 static void Check(bool ok,string operation) {if(!ok)throw new Win32Exception(Marshal.GetLastWin32Error(),operation);}
 public static List<string> Run(string id,bool apply) {
  if(!id.StartsWith("USB\\VID_0471&PID_2400\\",StringComparison.OrdinalIgnoreCase))throw new ArgumentException("Only the inspected Xinje HMI is allowed.");
  var output=new List<string>();var set=SetupDiCreateDeviceInfoList(IntPtr.Zero,IntPtr.Zero);
  if(set==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error());
  var dev=new DeviceData();dev.Size=Marshal.SizeOf(typeof(DeviceData));
  bool changedClass=false,installed=false;Guid oldClass=Guid.Empty;
  try {
   Check(SetupDiOpenDeviceInfo(set,id,IntPtr.Zero,0,ref dev),"Open HMI");oldClass=dev.Class;
   output.Add("OriginalClass="+oldClass);
   if(dev.Class==Guid.Empty) {
    if(!apply){output.Add("Device has no class. Apply will select the Microsoft USBDevice class, then the signed inbox WinUSB driver.");return output;}
    var classText=System.Text.Encoding.Unicode.GetBytes("{88BAE032-5A81-49f0-BC3D-A4FF138216D6}\0");
    Check(SetupDiSetDeviceRegistryProperty(set,ref dev,8,classText,(uint)classText.Length),"Select USBDevice class");
    changedClass=true;dev.Class=new Guid("88BAE032-5A81-49f0-BC3D-A4FF138216D6");
   }
   var p=new InstallParams();p.Size=Marshal.SizeOf(typeof(InstallParams));
   Check(SetupDiGetDeviceInstallParams(set,ref dev,ref p),"Read installer parameters");
   p.Path=Environment.GetFolderPath(Environment.SpecialFolder.Windows)+"\\INF\\winusb.inf";p.Flags|=0x10000;p.FlagsEx|=0x800;
   Check(SetupDiSetDeviceInstallParams(set,ref dev,ref p),"Use signed inbox WinUSB INF");
   Check(SetupDiBuildDriverInfoList(set,ref dev,1),"Enumerate Microsoft class drivers");
   var chosen=new DriverData();bool found=false;
   for(uint i=0;;i++) {
    var candidate=new DriverData();candidate.Size=Marshal.SizeOf(typeof(DriverData));
    if(!SetupDiEnumDriverInfo(set,ref dev,1,i,ref candidate)){int err=Marshal.GetLastWin32Error();if(err==259)break;throw new Win32Exception(err);}
    output.Add(candidate.Description+" | "+candidate.Provider);
    if(candidate.Description.Equals("WinUsb Device",StringComparison.OrdinalIgnoreCase)){chosen=candidate;found=true;}
   }
   if(!found)throw new Exception("The signed Microsoft WinUsb Device model was not found. No custom INF or signature changes will be used.");
   if(apply) {
    Check(SetupDiSetSelectedDriver(set,ref dev,ref chosen),"Select WinUSB");
    Check(SetupDiCallClassInstaller(2,set,ref dev),"Install signed WinUSB");installed=true;
    output.Add("WinUSB installation completed.");
   }
  } catch {
   if(changedClass && !installed)SetupDiSetDeviceRegistryProperty(set,ref dev,8,null,0);
   throw;
  } finally {SetupDiDestroyDeviceInfoList(set);}
  return output;
 }
}
'@
[HmiWinUsbBinding]::Run($InstanceId,[bool]$Apply)
if($Apply){
 $deviceParams=Join-Path ('HKLM:\SYSTEM\CurrentControlSet\Enum\'+$InstanceId) 'Device Parameters'
 New-Item -Path $deviceParams -Force | Out-Null
 New-ItemProperty -Path $deviceParams -Name DeviceInterfaceGUIDs -PropertyType MultiString -Value @('{59219E36-23D1-4DC6-8B98-FD37A8163182}') -Force | Out-Null
 Write-Output 'Interface GUID registered. Restarting only the HMI USB device.'
 & pnputil /restart-device $InstanceId
}
