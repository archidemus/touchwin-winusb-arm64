param([string]$OutputPath=(Join-Path $PSScriptRoot 'results\winusb-probe.json'))
$ErrorActionPreference='Stop'
$reportDirectory=Split-Path -Parent $OutputPath
if($reportDirectory){New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null}
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.ComponentModel;
public class HmiWinUsbProbe {
 [StructLayout(LayoutKind.Sequential)] struct InterfaceData {public int Size;public Guid Guid;public uint Flags;public IntPtr Reserved;}
 [StructLayout(LayoutKind.Sequential,Pack=1)] struct UsbInterface {public byte Length,Type,Number,Alternate,EndpointCount,Class,Subclass,Protocol,StringIndex;}
 [StructLayout(LayoutKind.Sequential)] struct Pipe {public int Type;public byte Address;public ushort MaxPacketSize;public byte Interval;}
 public class Endpoint {public string Address;public string Type;public int MaxPacketSize;}
 public class Report {public bool Opened;public string DevicePath;public string Vendor;public string Product;public int Interface;public List<Endpoint> Endpoints=new List<Endpoint>();}
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr SetupDiGetClassDevs(ref Guid g,string e,IntPtr w,uint f);
 [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiEnumDeviceInterfaces(IntPtr s,IntPtr d,ref Guid g,uint i,ref InterfaceData a);
 [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr s,ref InterfaceData a,IntPtr b,uint n,out uint required,IntPtr d);
 [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string p,uint a,uint s,IntPtr security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 [DllImport("winusb.dll",SetLastError=true)] static extern bool WinUsb_Initialize(IntPtr device,out IntPtr usb);
 [DllImport("winusb.dll")] static extern bool WinUsb_Free(IntPtr usb);
 [DllImport("winusb.dll",SetLastError=true)] static extern bool WinUsb_GetDescriptor(IntPtr usb,byte t,byte index,ushort language,byte[] data,uint size,out uint used);
 [DllImport("winusb.dll",SetLastError=true)] static extern bool WinUsb_QueryInterfaceSettings(IntPtr usb,byte alt,out UsbInterface result);
 [DllImport("winusb.dll",SetLastError=true)] static extern bool WinUsb_QueryPipe(IntPtr usb,byte alt,byte index,out Pipe result);
 static void Check(bool result,string op) {if(!result)throw new Win32Exception(Marshal.GetLastWin32Error(),op);}
 public static Report Run() {
  var guid=new Guid("59219E36-23D1-4DC6-8B98-FD37A8163182");var set=SetupDiGetClassDevs(ref guid,null,IntPtr.Zero,18);
  if(set==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error());
  try {
   var info=new InterfaceData();info.Size=Marshal.SizeOf(typeof(InterfaceData));
   Check(SetupDiEnumDeviceInterfaces(set,IntPtr.Zero,ref guid,0,ref info),"Find HMI WinUSB interface");
   uint needed;SetupDiGetDeviceInterfaceDetail(set,ref info,IntPtr.Zero,0,out needed,IntPtr.Zero);
   var detail=Marshal.AllocHGlobal((int)needed);string path;
   try{Marshal.WriteInt32(detail,IntPtr.Size==8?8:6);Check(SetupDiGetDeviceInterfaceDetail(set,ref info,detail,needed,out needed,IntPtr.Zero),"Read device path");path=Marshal.PtrToStringUni(IntPtr.Add(detail,4));}finally{Marshal.FreeHGlobal(detail);}
   if(path.IndexOf("vid_0471&pid_2400",StringComparison.OrdinalIgnoreCase)<0)throw new Exception("Unexpected USB device.");
   var device=CreateFile(path,0xC0000000,3,IntPtr.Zero,3,0x40000000,IntPtr.Zero);
   if(device==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error(),"Open HMI");
   try {
    IntPtr usb;Check(WinUsb_Initialize(device,out usb),"Initialize WinUSB");
    try{
     var descriptor=new byte[18];uint used;Check(WinUsb_GetDescriptor(usb,1,0,0,descriptor,18,out used),"Read device descriptor");
     if(used!=18 || BitConverter.ToUInt16(descriptor,8)!=0x0471 || BitConverter.ToUInt16(descriptor,10)!=0x2400)throw new Exception("Unexpected descriptor.");
     UsbInterface iface;Check(WinUsb_QueryInterfaceSettings(usb,0,out iface),"Read interface");
     var report=new Report {Opened=true,DevicePath=path,Vendor="0471",Product="2400",Interface=iface.Number};
     for(byte i=0;i<iface.EndpointCount;i++){Pipe pipe;Check(WinUsb_QueryPipe(usb,0,i,out pipe),"Read endpoint");report.Endpoints.Add(new Endpoint{Address="0x"+pipe.Address.ToString("X2"),Type=new string[]{"Control","Isochronous","Bulk","Interrupt"}[pipe.Type],MaxPacketSize=pipe.MaxPacketSize});}
     return report;
    }finally{WinUsb_Free(usb);}
   }finally{CloseHandle(device);}
  }finally{SetupDiDestroyDeviceInfoList(set);}
 }
}
'@
try {
 $probe=[HmiWinUsbProbe]::Run()
 $result=[ordered]@{Time=(Get-Date).ToString('o');OSArchitecture=[Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString();Success=$true;Probe=$probe;FirmwareWritePerformed=$false}
} catch {
 $result=[ordered]@{Time=(Get-Date).ToString('o');OSArchitecture=[Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString();Success=$false;Error=$_.Exception.ToString();FirmwareWritePerformed=$false}
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result | ConvertTo-Json -Depth 6
if(-not $result.Success){exit 1}
