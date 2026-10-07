# Contribuir / Contributing

La comunidad puede aportar documentación, reportes, pruebas de compatibilidad y mejoras de código.

## Primer aporte

Puedes empezar con una corrección de documentación o un reporte de compatibilidad; no hace falta enviar código. Revisa los [issues existentes](https://github.com/archidemus/touchwin-winusb-arm64/issues) antes de abrir uno nuevo. Si el proyecto te resulta útil, una estrella en GitHub también ayuda a darle visibilidad.

Mantenido por [Ignacio Norambuena — archidemus.me](https://archidemus.me/).

## Reportar y probar

Incluye modelo y sufijo del HMI, versión TouchWin, arquitectura de Windows, virtualización y VID/PID. Distingue entre probe, descarga terminada y confirmación física. No publiques proyectos privados, firmware ni DLL originales del fabricante.

## Proponer cambios

1. Crea un fork y una rama.
2. Lee LICENSE y CONTRIBUTOR_AGREEMENT.md.
3. Explica problema, cambio y validación.
4. Declara material de terceros y su licencia; identifica el uso sustancial de código generado y su revisión.
5. Antes de integrar código, acepta expresamente el acuerdo con esta declaración en el PR:

> Yo, [nombre completo], acepto TouchWin WinUSB Contributor Agreement 1.0 de CONTRIBUTOR_AGREEMENT.md para mis aportes en este pull request. Conservo su propiedad y concedo a Ignacio Norambuena los derechos allí indicados, incluida la licencia comercial separada.

Cada autor o titular relevante debe autorizar su aporte. Un issue, fork o PR sin la declaración no constituye aceptación. Si el código pertenece a un empleador, se necesita su autorización.

Conservas la propiedad. Ignacio podrá ofrecer licencias comerciales de los aportes aceptados, incluso acuerdos con XINJE. El acuerdo no promete participación en ingresos.

## Validación

Compila con LLVM y SDK obtenidos legalmente. Conserva la DLL validada de dist salvo que se prepare expresamente una nueva versión. Los probes no envían firmware. Las descargas físicas necesitan autorización del operador y un proyecto conocido; no introduzcas escritura automática de salidas del PLC.

## English

Community contributions are welcome. Contributors retain ownership. Before merge, explicitly accept Contributor Agreement 1.0 identifying yourself and the PR. It grants Ignacio Norambuena community and separate commercial licensing rights; it promises no revenue share. Declare third-party material and submit only work you have authority to license.
