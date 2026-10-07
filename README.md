# XINJE TouchWin USB en Windows ARM64: WinUSB para TG765-ET

**Descarga proyectos TouchWin por USB-B desde Windows 11 ARM64 en un Mac con Apple Silicon y VMware Fusion.** Puente de compatibilidad independiente, probado con **XINJE TG765-ET**, **TouchWin v2.E.9_241018** y el dispositivo USB **0471:2400**.

**English:** Independent WinUSB bridge for XINJE TouchWin USB-B project downloads on Windows ARM64. Tested on TG765-ET in VMware Fusion on Apple Silicon.

[Instalación](#instalación) · [Preguntas frecuentes](#preguntas-frecuentes) · [Contribuir](CONTRIBUTING.md) · [Licencia](LICENSE)

## Qué resuelve

El controlador USB x64 original probado no podía asociarse al HMI en Windows ARM64. Esta solución combina el **WinUSB ARM64 firmado de Microsoft**, incluido en Windows, con una **DLL x86** que conserva las funciones esperadas por TouchWin.

    TouchWin x86 → EasyUSB2400_XJ.dll x86 → WinUSB de Windows → HMI USB-B

No es un controlador de kernel nuevo ni un producto oficial de XINJE. El repositorio incluye la DLL validada, código C, funciones exportadas y scripts de instalación, diagnóstico y compilación.

## Compatibilidad comprobada

| Componente | Configuración validada |
| --- | --- |
| HMI | XINJE TG765-ET, 800 × 480 |
| Editor | TouchWin v2.E.9_241018, x86 |
| Sistema | Windows 11 ARM64 |
| Virtualización | VMware Fusion en Mac Apple Silicon |
| USB | VID 0471, PID 2400 |
| Interfaz | 0, DC/A0/B0 |
| Transferencia | Bulk IN 0x81, OUT 0x02, paquetes de 64 bytes |
| Controlador | WINUSB / winusb.inf firmado de Microsoft |
| Operación | Descarga normal con Ctrl+D |
| Fecha de validación | 7 de octubre de 2026 |

TouchWin mostró **“Download finish !”** y el operador confirmó el funcionamiento físico con la prueba de Y0 del PLC. El ciclo previsto era de cinco segundos; no se midió con instrumentación. Véase [registro de validación](evidence/validation.json).

No se han validado otras versiones, modelos, subida ni descarga completa. La API del segundo puerto no está implementada.

## Instalación

### 1. Obtener y verificar la DLL

Descarga el ZIP del repositorio mediante **Code → Download ZIP** y extráelo en una carpeta local de Windows. La DLL está en [dist/EasyUSB2400_XJ.dll](dist/EasyUSB2400_XJ.dll).

Desde la raíz del repositorio, en PowerShell:

    Get-FileHash .\dist\EasyUSB2400_XJ.dll -Algorithm SHA256

SHA-256 esperado:

    E74328F8900DB63ABD21ACA6A01104AEBF91492ADE05301AA2A7C31908870999

### 2. Asignar el USB a Windows

Conecta un cable USB de datos al puerto USB-B del HMI. En **USB y Bluetooth** de VMware Fusion, asigna el dispositivo a Windows; puede aparecer como Philips o XINJE.

    Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VID_0471&PID_2400' }

Si no aparece, revisa el cable y la asignación a la VM antes de instalar nada.

### 3. Asociar WinUSB

Desde **Windows PowerShell administrador**, utiliza la instancia real devuelta por el comando anterior:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\bind_winusb.ps1 -InstanceId 'USB\VID_0471&PID_2400\TU_INSTANCIA'
    powershell -NoProfile -ExecutionPolicy Bypass -File .\bind_winusb.ps1 -Apply -InstanceId 'USB\VID_0471&PID_2400\TU_INSTANCIA'

La primera ejecución inspecciona la selección; la segunda la aplica. El resultado esperado es servicio WINUSB, estado OK y problema 0. Se registra el GUID {59219E36-23D1-4DC6-8B98-FD37A8163182} y se reinicia únicamente ese dispositivo.

No hace falta desactivar Secure Boot ni la comprobación de firmas. El script selecciona el nombre de modelo “WinUsb Device”, probado en Windows en inglés; otras traducciones pueden requerir adaptación.

### 4. Preparar una copia de TouchWin

Con el editor cerrado, copia tu instalación legal de TouchWin a otra carpeta. En esa copia:

1. Renombra su DLL existente a EasyUSB2400_XJ.original.dll.
2. Copia allí la DLL de dist.
3. Abre TWinEx.exe desde esa carpeta. Configura el directorio de trabajo del acceso directo en la misma carpeta.

Conserva la instalación original.

### 5. Comprobar y descargar

Ejecuta cada diagnóstico en un proceso separado:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\probe_winusb.ps1
    & "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File .\test_bridge.ps1

Los diagnósticos no envían un proyecto ni firmware. Sus informes se guardan en results. Después, abre tu proyecto en la copia de TouchWin y pulsa **Ctrl+D**. Confirma “Download finish !” y el comportamiento del HMI físico.

La descarga PC–HMI es distinta de la comunicación HMI–PLC. Este puente no cambia el programa ni los parámetros serie del PLC.

## Compilar desde el código fuente

Se necesitan clang y lld para i686-pc-windows-msvc y las bibliotecas x86 kernel32.Lib, SetupAPI.Lib y winusb.lib del Windows SDK.

La compilación validada usó clang/lld 12.0.0 y Microsoft.Windows.SDK.CPP.x86 10.0.26100.9169, carpeta c/um/x86. Las herramientas y el SDK se obtienen de sus distribuidores; no se incluyen.

    powershell -NoProfile -ExecutionPolicy Bypass -File .\build_bridge.ps1 -CompilerPath 'C:\LLVM\bin\clang.exe' -LinkerPath 'C:\LLVM\bin\ld.lld.exe' -SdkLibraryPath 'C:\SDK\c\um\x86'

Resultado: build/EasyUSB2400_XJ.dll. Para comprobar ese binario, ejecuta test_bridge.ps1 en PowerShell x86 con -DllPath .\build\EasyUSB2400_XJ.dll.

## Diagnóstico de fallos

| Síntoma | Comprobación |
| --- | --- |
| Windows no ve 0471:2400 | Cable de datos y asignación USB de VMware |
| Dispositivo con error | Instancia real, servicio WINUSB y código de problema |
| El probe no encuentra interfaz | Asociación WinUSB y registro del GUID |
| La DLL no carga | Usar PowerShell x86 y comprobar la ruta |
| TouchWin sigue fallando | Abrir la copia que contiene la DLL nueva |
| Descarga termina pero Y0 no cambia | Revisar el enlace HMI–PLC por separado |

## Preguntas frecuentes

### ¿Funciona TouchWin por USB en Windows ARM64?

La descarga normal USB-B se comprobó con este puente en TG765-ET y TouchWin v2.E.9_241018. Otros modelos y versiones necesitan pruebas independientes.

### ¿La DLL es un driver ARM64?

La DLL es x86, como TouchWin. El controlador nativo ARM64 es el WinUSB firmado que ya incluye Microsoft Windows.

### ¿Funciona en un Mac con Apple Silicon?

La configuración comprobada fue Windows 11 ARM64 dentro de VMware Fusion. No se probó la ejecución nativa en macOS.

### ¿Necesito un adaptador USB–RS232?

La descarga PC–HMI validada utiliza USB-B. La conexión del HMI al PLC es un enlace separado.

### ¿Puede contribuir la comunidad?

Sí: issues, documentación, pruebas y pull requests. Cada colaborador conserva sus derechos. Para incorporar código se requiere aceptar expresamente el [acuerdo de contribución](CONTRIBUTOR_AGREEMENT.md).

### ¿Puede XINJE publicarlo o mencionarlo oficialmente?

La licencia comunitaria reserva la redistribución y las menciones o promociones oficiales de XINJE a un acuerdo escrito separado. No garantiza impedir cualquier referencia veraz o enlace amparado por derechos independientes. Los detalles están en [LICENSING.md](LICENSING.md).

### ¿Es open source aprobado por la OSI?

No. Es **código disponible / source available con contribución comunitaria**. La restricción específica a XINJE no cumple la definición de open source de la OSI.

## Autor, licencia y contacto

Trabajo original de **Ignacio Norambuena** · [archidemus](https://github.com/archidemus) · [ignacio@archidemus.me](mailto:ignacio@archidemus.me).

La [licencia personalizada](LICENSE) permite uso, modificación y redistribución comunitarios, incluso comerciales, con sus condiciones. Las autorizaciones comerciales de XINJE se negocian con el titular; no existe una tarifa o deuda automática.

Proyecto independiente, sin respaldo de XINJE ni Microsoft. No se incluyen TouchWin, firmware, la DLL original del fabricante ni binarios del SDK.

Referencias: [Microsoft WinUSB](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb), [instalación WinUSB](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation), [Open Source Definition](https://opensource.org/osd).


Las opciones ExecutionPolicy de estos comandos se limitan al proceso y no cambian la política global. Ejecuta solo scripts revisados.
