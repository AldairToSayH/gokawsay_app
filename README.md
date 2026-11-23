# GoKawsay

Aplicación Flutter para publicar habitaciones y coordinar alquileres en Cusco.
El arrendador elige manualmente entre las solicitudes y conversa en privado
con cada persona. La app registra acuerdos, evidencias y comprobantes de
pagos externos. El contrato se genera y se acepta dentro de GoKawsay.

## Configuración inicial

El proyecto utiliza Flutter 3.50 y Dart 3.14. Para instalar las dependencias
y configurar Firebase, ejecuta desde la raíz del proyecto.

```powershell
flutter pub get
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Selecciona el proyecto Firebase y las plataformas que utilizarás. Habilita
Google como proveedor de autenticación y configura Realtime Database con
las reglas de `database.rules.json`.

La configuración de Firebase de cada entorno se mantiene localmente en
`lib/firebase_options.dart`, `android/app/google-services.json` y, para iOS,
`ios/Runner/GoogleService-Info.plist`. FlutterFire permite generar la
configuración. Los archivos nativos también se pueden descargar desde la
consola de Firebase. Configura las claves de Maps como se indica más abajo.
En iOS, comprueba que el cliente OAuth y su esquema de URL correspondan a
la aplicación registrada en tu proyecto Firebase.

[Configuración de Firebase para Flutter](https://firebase.google.com/docs/flutter/setup)

## Demostración en Android o iOS

Inicia Firebase Local Emulator Suite desde la raíz del proyecto.

```powershell
firebase emulators:start --only auth,database --project demo-gokawsay
```

Con el emulador Android o el simulador iOS abierto, inicia Flutter en otra terminal.

```powershell
flutter run --dart-define=GOKAWSAY_DEMO=true
```

Si usas un teléfono, indica la IP local del equipo con
`--dart-define=FIREBASE_EMULATOR_HOST=<ip-local>` y configura Firebase Emulator
Suite para escuchar en esa red. En Android el tráfico local sin TLS está
habilitado en la compilación de depuración.

1. Entra como Mateo, confirma el rol **Arrendador** y pulsa **Publicar habitación de ejemplo**.
2. Cierra sesión desde **Perfil**. Entra como Lucía, confirma el rol **Arrendatario**, abre la habitación, solicita la reserva y escribe por chat. Repite con Diego.
3. Vuelve a Mateo. En **Solicitudes** verás dos personas interesadas. Abre cada conversación y elige una solicitud.
4. Acuerda el período y la garantía. Alterna las dos cuentas para guardar ambos checklists de ingreso con fotos y aceptar el contrato.
5. Registra la entrega de la garantía y confirma la recepción. Desde el alquiler activo, registra un pago y confírmalo como arrendador.
6. Inicia el check-out. Completa ambas inspecciones, registra la liquidación y confirma el cierre desde las dos cuentas.

Usa fotos de la galería de hasta 500 KB después de compresión. La foto de ejemplo
y cualquier foto o comprobante subido durante la demostración usan el entorno
local. Los datos del emulador se pueden conservar con
`--import=./.firebase-demo --export-on-exit=./.firebase-demo` una vez creado el
directorio mediante `firebase emulators:export .firebase-demo`.

## Firebase del proyecto

Ejecuta Flutter sin `GOKAWSAY_DEMO` para usar el proyecto compartido `gokawsay`.
Las reglas de Realtime Database y el proveedor de Google ya están activados.
Para volver a desplegar las reglas usa
`firebase deploy --only database --project gokawsay`.

La configuración de Google en Android corresponde al certificado de
depuración registrado en Firebase. Si cambias el certificado de firma,
registra su huella y actualiza `android/app/google-services.json`.
Runner incluye el cliente OAuth y su esquema de URL en iOS.

Desde GoKawsay 1.0.6, las cuentas pueden usar la app en cada sesión con su
cuenta de Google. El perfil queda reservado a su titular y los chats,
evidencias y registros del alquiler a sus participantes.

## Google Maps

Activa la facturación y los SDK de Google Maps para Android e iOS en Google
Cloud. Crea una clave por plataforma y limita cada una a su SDK y a la app
`com.example.gokawsay`. En Android incluye la huella SHA-1 del certificado
con el que firmas el APK. Puedes consultarla con `gradlew signingReport`
desde el directorio `android`.

- Android. Define `GOKAWSAY_MAPS_ANDROID_API_KEY` en `android/maps.properties`
  o como variable de entorno antes de ejecutar Flutter o el build de Gradle.
- iOS. Crea `ios/Flutter/MapsKeys.xcconfig` en el equipo de compilación con una
  línea `GOKAWSAY_MAPS_IOS_API_KEY = <clave restringida para iOS>`.

Las fichas con coordenadas incluyen un enlace para abrir el pin en Google Maps.
La selección sobre el mapa integrado depende de la clave de la plataforma.

## APK para instalar en Android

```powershell
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.
Esta compilación usa Firebase `gokawsay` y la firma de desarrollo configurada
en el proyecto. Las animaciones de `assets/animations/` y las fuentes se
incluyen en el APK.

## Verificación

```powershell
flutter analyze
flutter test
node test/firebase_flow_test.mjs
```

La última prueba requiere los emuladores de Auth y Realtime Database
iniciados. Usa una base de datos local separada de la demostración.
Crea cuentas de prueba para comprobar el recorrido completo, la migración
de perfiles, el acceso de cuentas con una sesión de cortesía anterior
finalizada, los permisos por rol y el acceso a chats privados.
