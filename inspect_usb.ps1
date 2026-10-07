param([string]$OutputPath=(Join-Path $PSScriptRoot 'results\usb-descriptors.json'))
$ErrorActionPreference='Stop'
$reportDirectory=Split-Path -Parent $OutputPath
if($reportDirectory){New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null}
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class HmiUsbDescriptors {
 [StructLayout(LayoutKind.Sequential)] public struct InterfaceData { public int Size; public Guid Guid; public uint Flags; public IntPtr Reserved; }
 public class Port { public string Hub; public int Index; public string Vid; public string Pid; public string Descriptor; public string Configuration; public int Error; }
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr SetupDiGetClassDevs(ref Guid g,string e,IntPtr w,uint f);
 [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiEnumDeviceInterfaces(IntPtr s,IntPtr d,ref Guid g,uint i,ref InterfaceData a);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr s,ref InterfaceData a,IntPtr b,uint n,out uint required,IntPtr d);
 [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string p,uint a,uint s,IntPtr security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool DeviceIoControl(IntPtr h,uint c,byte[] input,uint ni,byte[] output,uint no,out uint returned,IntPtr overlapped);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 public static List<Port> Inspect() {
  var result=new List<Port>(); var g=new Guid("F18A0E88-C30C-11D0-8815-00A0C906BED8");
  var set=SetupDiGetClassDevs(ref g,null,IntPtr.Zero,18);
  if(set==new IntPtr(-1)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
  try { for(uint i=0;;i++) {
   var data=new InterfaceData(); data.Size=Marshal.SizeOf(typeof(InterfaceData));
   if(!SetupDiEnumDeviceInterfaces(set,IntPtr.Zero,ref g,i,ref data)) { int err=Marshal.GetLastWin32Error(); if(err==259) break; throw new System.ComponentModel.Win32Exception(err); }
   uint needed; SetupDiGetDeviceInterfaceDetail(set,ref data,IntPtr.Zero,0,out needed,IntPtr.Zero);
   var detail=Marshal.AllocHGlobal((int)needed); string path;
   try { Marshal.WriteInt32(detail,IntPtr.Size==8?8:6); if(!SetupDiGetDeviceInterfaceDetail(set,ref data,detail,needed,out needed,IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); path=Marshal.PtrToStringUni(IntPtr.Add(detail,4)); } finally {Marshal.FreeHGlobal(detail);}
   var hub=CreateFile(path,0x40000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
   if(hub==new IntPtr(-1)) { result.Add(new Port {Hub=path,Error=Marshal.GetLastWin32Error()}); continue; }
   try {
    var node=new byte[128]; uint returned;
    if(!DeviceIoControl(hub,0x220408,node,(uint)node.Length,node,(uint)node.Length,out returned,IntPtr.Zero)) { result.Add(new Port{Hub=path,Error=Marshal.GetLastWin32Error()}); continue; }
    int count=node[6];
    for(int p=1;p<=count;p++) {
     var conn=new byte[4096]; Array.Copy(BitConverter.GetBytes(p),conn,4);
     if(!DeviceIoControl(hub,0x220448,conn,(uint)conn.Length,conn,(uint)conn.Length,out returned,IntPtr.Zero)) continue;
     ushort vid=BitConverter.ToUInt16(conn,12),pid=BitConverter.ToUInt16(conn,14);
     if(vid==0) continue;
     var port=new Port{Hub=path,Index=p,Vid=vid.ToString("X4"),Pid=pid.ToString("X4"),Descriptor=BitConverter.ToString(conn,4,18)};
     if(vid==0x0471 && pid==0x2400) {
      var request=new byte[4108]; Array.Copy(BitConverter.GetBytes(p),request,4);
      request[4]=0x80;request[5]=6;request[7]=2;request[10]=0;request[11]=16;
      if(DeviceIoControl(hub,0x220410,request,(uint)request.Length,request,(uint)request.Length,out returned,IntPtr.Zero)) {
       int len=BitConverter.ToUInt16(request,14); if(len>=9 && len<=4096 && returned>=12+len) port.Configuration=BitConverter.ToString(request,12,len);
      } else port.Error=Marshal.GetLastWin32Error();
     }
     result.Add(port);
    }
   } finally { CloseHandle(hub); }
  }} finally {SetupDiDestroyDeviceInfoList(set);}
  return result;
 }
}
'@
$ports=@([HmiUsbDescriptors]::Inspect())
$hmi=@($ports | Where-Object {$_.Vid -eq '0471' -and $_.Pid -eq '2400'})
$report=[ordered]@{Time=(Get-Date).ToString('o');OSArchitecture=[Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString();HmiFound=($hmi.Count -gt 0);Ports=$ports;Interfaces=@();Endpoints=@()}
foreach($device in $hmi) {
 if(-not $device.Configuration){continue}
 [byte[]]$config=@($device.Configuration.Split('-') | ForEach-Object {[Convert]::ToByte($_,16)})
 $interface=$null
 for($offset=0;$offset -lt $config.Length;) {
  $length=[int]$config[$offset]
  if($length -lt 2 -or $offset+$length -gt $config.Length){throw 'Malformed USB descriptor.'}
  if($config[$offset+1] -eq 4 -and $length -ge 9) {
   $interface=[int]$config[$offset+2]
   $report.Interfaces+= [ordered]@{Number=$interface;AlternateSetting=[int]$config[$offset+3];EndpointCount=[int]$config[$offset+4];Class=[int]$config[$offset+5];Subclass=[int]$config[$offset+6];Protocol=[int]$config[$offset+7]}
  }
  if($config[$offset+1] -eq 5 -and $length -ge 7) {
   $address=[int]$config[$offset+2]
   $report.Endpoints+= [ordered]@{Interface=$interface;Address=('0x{0:X2}' -f $address);Direction=$(if($address -band 128){'IN'}else{'OUT'});TransferType=@('Control','Isochronous','Bulk','Interrupt')[$config[$offset+3] -band 3];MaxPacketSize=[BitConverter]::ToUInt16($config,$offset+4)}
  }
  $offset+=$length
 }
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8
