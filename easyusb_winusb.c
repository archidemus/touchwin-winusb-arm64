/* Experimental compatibility adapter for this inspected HMI only.
 * Device 0471:2400, interface DC/A0/B0, bulk IN 81 and OUT 02.
 * The exported stdcall ABI and byte-count/-1 conventions were inspected
 * in the installed EasyUSB2400_XJ.dll. This is not an ARM kernel driver:
 * this x86 DLL calls the Microsoft WinUSB driver on Windows ARM64.
 */
typedef unsigned char U8;
typedef unsigned short U16;
typedef unsigned long U32;
typedef unsigned int UPTR;
typedef int BOOL;
typedef void *HANDLE;
typedef struct { U32 a; U16 b,c; U8 d[8]; } GUID;
typedef struct { U32 size; GUID guid; U32 flags; UPTR reserved; } INTERFACE_DATA;
typedef struct { int type; U8 address; U16 maximum; U8 interval; } PIPE;
#pragma pack(push,1)
typedef struct {U8 length,type,number,alternate,count,cls,subcls,protocol,str;} USB_INTERFACE;
typedef struct {U8 requestType,request;U16 value,index,length;} SETUP_PACKET;
#pragma pack(pop)
#define API __declspec(dllimport)
#define CALL __stdcall
API HANDLE CALL CreateFileW(const unsigned short*,U32,U32,void*,U32,U32,HANDLE);
API BOOL CALL CloseHandle(HANDLE);
API void CALL SetLastError(U32);
API HANDLE CALL GetProcessHeap(void);
API void * CALL HeapAlloc(HANDLE,U32,UPTR);
API BOOL CALL HeapFree(HANDLE,U32,void*);
API HANDLE CALL SetupDiGetClassDevsW(const GUID*,const unsigned short*,HANDLE,U32);
API BOOL CALL SetupDiEnumDeviceInterfaces(HANDLE,void*,const GUID*,U32,INTERFACE_DATA*);
API BOOL CALL SetupDiGetDeviceInterfaceDetailW(HANDLE,INTERFACE_DATA*,void*,U32,U32*,void*);
API BOOL CALL SetupDiDestroyDeviceInfoList(HANDLE);
API BOOL CALL WinUsb_Initialize(HANDLE,HANDLE*);
API BOOL CALL WinUsb_Free(HANDLE);
API BOOL CALL WinUsb_GetDescriptor(HANDLE,U8,U8,U16,U8*,U32,U32*);
API BOOL CALL WinUsb_QueryInterfaceSettings(HANDLE,U8,USB_INTERFACE*);
API BOOL CALL WinUsb_QueryPipe(HANDLE,U8,U8,PIPE*);
API BOOL CALL WinUsb_SetPipePolicy(HANDLE,U8,U32,U32,void*);
API BOOL CALL WinUsb_ReadPipe(HANDLE,U8,U8*,U32,U32*,void*);
API BOOL CALL WinUsb_WritePipe(HANDLE,U8,U8*,U32,U32*,void*);
API BOOL CALL WinUsb_ControlTransfer(HANDLE,SETUP_PACKET,U8*,U32,U32*,void*);
API BOOL CALL WinUsb_ResetPipe(HANDLE,U8);
static const GUID deviceGuid={0x59219e36,0x23d1,0x4dc6,{0x8b,0x98,0xfd,0x37,0xa8,0x16,0x31,0x82}};
typedef struct {HANDLE file,usb;} CONNECTION;
void *memset(void *p,int c,UPTR n){U8 *b=(U8*)p;while(n--)*b++=(U8)c;return p;}
void *memcpy(void *d,const void *s,UPTR n){U8 *a=(U8*)d;const U8 *b=(const U8*)s;while(n--)*a++=*b++;return d;}
static void closeUsb(CONNECTION *c){if(c->usb)WinUsb_Free(c->usb);if(c->file && c->file!=(HANDLE)-1)CloseHandle(c->file);memset(c,0,sizeof(*c));}
static BOOL openUsb(CONNECTION *c){
 HANDLE set;INTERFACE_DATA info;U32 needed=0,used=0;void *detail=0;U8 descriptor[18];USB_INTERFACE iface;PIPE pipe;int haveIn=0,haveOut=0;U8 i;
 memset(c,0,sizeof(*c));memset(&info,0,sizeof(info));info.size=sizeof(info);
 set=SetupDiGetClassDevsW(&deviceGuid,0,0,18);if(set==(HANDLE)-1)return 0;
 if(!SetupDiEnumDeviceInterfaces(set,0,&deviceGuid,0,&info))goto fail;
 SetupDiGetDeviceInterfaceDetailW(set,&info,0,0,&needed,0);
 if(needed<8 || needed>16384){SetLastError(87);goto fail;}
 detail=HeapAlloc(GetProcessHeap(),8,needed);if(!detail)goto fail;
 *(U32*)detail=6; /* SP_DEVICE_INTERFACE_DETAIL_DATA_W in a 32-bit caller. */
 if(!SetupDiGetDeviceInterfaceDetailW(set,&info,detail,needed,&needed,0))goto fail;
 c->file=CreateFileW((const unsigned short*)((U8*)detail+4),0xc0000000,3,0,3,0x40000000,0);
 if(c->file==(HANDLE)-1 || !WinUsb_Initialize(c->file,&c->usb))goto fail;
 if(!WinUsb_GetDescriptor(c->usb,1,0,0,descriptor,18,&used) || used!=18)goto fail;
 if(descriptor[8]!=0x71 || descriptor[9]!=0x04 || descriptor[10]!=0 || descriptor[11]!=0x24){SetLastError(87);goto fail;}
 if(!WinUsb_QueryInterfaceSettings(c->usb,0,&iface) || iface.number!=0 || iface.cls!=0xdc || iface.subcls!=0xa0 || iface.protocol!=0xb0)goto fail;
 for(i=0;i<iface.count;i++){if(!WinUsb_QueryPipe(c->usb,0,i,&pipe))goto fail;if(pipe.type==2 && pipe.address==0x81)haveIn=1;if(pipe.type==2 && pipe.address==2)haveOut=1;}
 if(!haveIn || !haveOut){SetLastError(87);goto fail;}
 HeapFree(GetProcessHeap(),0,detail);SetupDiDestroyDeviceInfoList(set);return 1;
fail:
 if(detail)HeapFree(GetProcessHeap(),0,detail);SetupDiDestroyDeviceInfoList(set);closeUsb(c);return 0;
}
static U32 policyTimeout(int timeout){return timeout<0?0:timeout==0?1:(U32)timeout;}
int CALL LPC2400_ReadData(int index,char *buffer,int length,int timeout){
 CONNECTION c;U32 used=0,t=policyTimeout(timeout);BOOL ok;
 if(index!=0 || !buffer || length<1 || timeout< -1){SetLastError(87);return -1;}
 if(!openUsb(&c))return -1;
 ok=WinUsb_SetPipePolicy(c.usb,0x81,3,sizeof(t),&t) && WinUsb_ReadPipe(c.usb,0x81,(U8*)buffer,(U32)length,&used,0);
 closeUsb(&c);return ok?(int)used:-1;
}
int CALL LPC2400_WriteData(int index,char *buffer,int length,int timeout){
 CONNECTION c;U32 used=0,t=policyTimeout(timeout);BOOL ok;
 if(index!=1 || !buffer || length<1 || timeout< -1){SetLastError(87);return -1;}
 if(!openUsb(&c))return -1;
 ok=WinUsb_SetPipePolicy(c.usb,2,3,sizeof(t),&t) && WinUsb_WritePipe(c.usb,2,(U8*)buffer,(U32)length,&used,0);
 closeUsb(&c);return ok?(int)used:-1;
}
int CALL LPC2400_ReadPort1(char *b,int n,int t){return LPC2400_ReadData(0,b,n,t);}
int CALL LPC2400_ReadPort2(char *b,int n,int t){return LPC2400_ReadData(2,b,n,t);}
int CALL LPC2400_WritePort1(char *b,int n,int t){return LPC2400_WriteData(1,b,n,t);}
int CALL LPC2400_WritePort2(char *b,int n,int t){return LPC2400_WriteData(3,b,n,t);}
int CALL LPC2400_GetPipeStatus(int index,char *buffer,int length){
 CONNECTION c;SETUP_PACKET setup;U32 used=0;BOOL ok;
 if(index<0 || index>1 || !buffer || length<2){SetLastError(87);return -1;}
 if(!openUsb(&c))return -1;
 memset(&setup,0,sizeof(setup));setup.requestType=0x82;setup.index=index==0?0x81:2;setup.length=2;
 ok=WinUsb_ControlTransfer(c.usb,setup,(U8*)buffer,2,&used,0);
 closeUsb(&c);return ok && used==2?0:-1;
}
int CALL LPC2400_ResetPipe(int index){
 CONNECTION c;BOOL ok;if(index<0 || index>1){SetLastError(87);return -1;}
 if(!openUsb(&c))return -1;ok=WinUsb_ResetPipe(c.usb,index==0?0x81:2);closeUsb(&c);return ok?0:-1;
}
int CALL HmiBridge_Ping(void){CONNECTION c;if(!openUsb(&c))return 0;closeUsb(&c);return 1;}
