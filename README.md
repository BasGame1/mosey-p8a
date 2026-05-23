> [!CAUTION]
> This is ongoing experemental research.  
> FLASH ANY MODULES AT YOUR OWN RISK! You MUST know what are you doing.  
> For research and debug purpuses only. 

<h1 align="center">Mosey extended v2 (MMT-Ex)</h1>

<div align="center">
  <!-- Version -->
    <img src="https://img.shields.io/badge/Version-v2-blue.svg?longCache=true&style=popout-square"
      alt="Version" />
  <!-- Last Updated -->
    <img src="https://img.shields.io/badge/Updated-April 24, 2024-green.svg?longCache=true&style=flat-square"
      alt="_time_stamp_" />
  <!-- Min Magisk -->
    <img src="https://img.shields.io/badge/MinMagisk-20.4-red.svg?longCache=true&style=flat-square"
      alt="_time_stamp_" />
  <!-- Min KSU -->
    <img src="https://img.shields.io/badge/MinKernelSU-0.6.6-red.svg?longCache=true&style=flat-square"
      alt="_time_stamp_" /></div>

### [EN] What is this all about

A few weeks ago, I reverse-engineered a Pixel 10 firmware image and I may have identified a missing component required for enabling AirDrop functionality on older Pixel devices (or even for any other device). And these are not just identification files i tried before.

I have found a native binary named mosey_server (the name matches the server component referenced by the corresponding APK extension). Static analysis shows that this binary:
+ Is a native Android service, not a CLI tool.
+ Links against:
  + libbinder_ndk.so
  + liblog.so
  + libc.so
  + libdl.so
+ Contains the string: AServiceManager_addService

<img width="720" height="522" alt="image" src="https://github.com/user-attachments/assets/43b4809b-4271-4acf-95ef-4188a0745c20" />

This and some on-device testing indicates that the binary attempts to register a native AIDL (NDK Binder) service via `AServiceManager_addService() ` with the service name: `com.google.pixel.service.IService/default`. The source path embedded in the binary  `vendor/google/services/QuickShareExtension/src/server.rs` suggests that the binary is part of the Quick Share extension and it is also expected to launch on boot.

Init configuration (mosey.rc) looks as follows:

```
on boot
    start mosey_server

service mosey_server /vendor/bin/mosey_server
    user system
    group system inet
    disabled
    capabilities NET_ADMIN NET_RAW
```

Attempts to manually inject this binary into the system and start it via KSU module were unsuccessful for the following (as far as I can say) reasons:
1. AServiceManager_addService() performs more than SELinux allow-rule checks.
2. The service name MUST be mapped to a valid SELinux service type via: vendor_service_contexts
3. Without this mapping, service registration fails with either PERMISSION_DENIED or UNKNOWN_ERROR (if you try to lauch it using su shell)

The Pixel 10 series vendor image already include all required components for this service:
+ A vendor_service_contexts entry mapping the service name to an SELinux type.
+ Corresponding SELinux type definitions and allow rules, for example:
+ _service
+  _server
+  mosey_app

Extracted policy fragments include definitions such as:
```
(typeattributeset mosey_app_202504 (mosey_app))
(expandtypeattribute (mosey_app_202504) true)
(typeattribute mosey_app_202504)
(dontaudit mosey_app fwmarkd_socket (sock_file (write)))
(typetransition mosey_app mosey_app anon_inode "[userfaultfd]")
(typeattributeset base_typeattr_1097
  (and (appdomain) (not (runas_app shell simpleperf mosey_app))))
(typeattributeset base_typeattr_1096
  (and (mosey_app) (not (runas_app shell simpleperf))))
```

This confirms that the service is explicitly whitelisted and integrated into SELinux policy and just switching SELinux to Permissive does not solve the problem because binder service registration still requires a SELinux-type mapping and this mapping is enforced by the servicemanager logic itself.
A theoretical workaround would be modifying the firmware images to include the missing policy and context files or (what is better for pixel devices) replacing them with their Pixel 10 counterparts and then re-signing the images using a tool such as avbroot.

Relevant files likely include (by search query "mosey"):
Here is a brief description of each file from the unpacked Android image (from Gemini):
+ **202504.cil:** This is a Common Intermediate Language (CIL) file containing the public SELinux policy rules for a specific Android API level (in this case, likely API 36/Android 16) to ensure backward compatibility with older vendor partitions.
+ **compatibility_matrix.xml:** This file defines the hardware and software requirements that a device must meet to be compatible with a specific version of the Android framework, including HAL versions and kernel configurations.
+ **product_sepolicy.cil:** This file contains the SELinux security policies specific to the product partition, defining permissions for apps and services added by the device manufacturer.
+ **system_ext_sepolicy.cil:** This file houses the SELinux policies for the system_ext partition, which contains non-core system components and extensions provided by the vendor (Google).
+ **system_ext_seapp_contexts:** This configuration file maps app package names or signatures to specific SELinux security domains for processes running on the system_ext partition.
+ **vendor_file_contexts:** This file maps file system paths on the vendor partition to specific SELinux security labels to control access to hardware-specific files and libraries.
+ **vendor_sepolicy.cil:** This is the primary SELinux policy file for the vendor partition, containing the security rules that govern low-level hardware services and drivers.
+ **vendor_service_contexts:** This file assigns SELinux security labels to the various binder services registered by the vendor partition to regulate inter-process communication.

If these files correctly integrated, theoretically the system should be able to automatically start mosey_server and register the binder service, which may activate Quick Share functionality, although additional conditions may still apply (_because even some Pixel 10 series still missing this feature_).

I don't have sufficient experience in modifying android factory images and using avbroot therefore I won't try it on my only pixel phone. However, it would be interesting to hear feedback from someone with experience in android image modification. In theory, this method should be applicable **not only to Pixel devices, but to any modern Android phone.**

[RU] О чем вообще это всё

Несколько недель назад я провёл реверс-инженеринг прошивки Pixel 10 Pro и, возможно, обнаружил недостающий компонент, необходимый для включения функциональности AirDrop (Quick Share) на старых устройствах Pixel (и потенциально вообще на любых других устройствах). Речь идёт не просто об идентификационных файлах, которые я пробовал ранее (pixel-expirience-YYYY).

Я нашёл нативный бинарник с именем mosey_server (название совпадает с APK-расширением для Quick Share, доступно на ApkPure). Статический анализ показывает, что этот бинарник:
+ Является нативным Android-сервисом, а не CLI-утилитой.
+ Линкуется с:
  + libbinder_ndk.so
  + liblog.so
  + libc.so
  + libdl.so
+ Содержит строку: AServiceManager_addService

<img width="720" height="522" alt="image" src="https://github.com/user-attachments/assets/43b4809b-4271-4acf-95ef-4188a0745c20" />

Это, а также некоторые тесты прямо на устройстве, указывает на то, что бинарник пытается зарегистрировать нативный AIDL-сервис (NDK Binder) через `AServiceManager_addService()` с именем сервиса:
`com.google.pixel.service.IService/default`.

Встроенный в бинарник путь к исходникам —
`vendor/google/services/QuickShareExtension/src/server.rs` —
указывает на то, что этот бинарник является частью расширения Quick Share и, предположительно, должен запускаться при загрузке системы.

Init-конфигурация (mosey.rc) выглядит следующим образом:
```
on boot
    start mosey_server

service mosey_server /vendor/bin/mosey_server
    user system
    group system inet
    disabled
    capabilities NET_ADMIN NET_RAW
```
Попытки вручную внедрить этот бинарник в систему и запустить его через KSU-модуль оказались неудачными по следующим (насколько я могу судить) причинам:
	1. AServiceManager_addService() выполняет проверки, выходящие за рамки обычных SELinux allow-правил.
	2. Имя сервиса обязательно должно быть сопоставлено с валидным SELinux-типом сервиса через vendor_service_contexts.
	3. Без такого сопоставления регистрация сервиса завершается ошибкой PERMISSION_DENIED или UNKNOWN_ERROR (если пытаться запускать его из su-shell).

В vendor-образе Pixel 10 уже присутствуют все необходимые компоненты для работы этого сервиса:
+ Запись в vendor_service_contexts, сопоставляющая имя сервиса с SELinux-типом.
+ Соответствующие определения SELinux-типов и allow-правила, например:
  + _service
	+	_server
	+	mosey_app

Извлечённые фрагменты политики включают, в частности, такие определения:
```
(typeattributeset mosey_app_202504 (mosey_app))
(expandtypeattribute (mosey_app_202504) true)
(typeattribute mosey_app_202504)
(dontaudit mosey_app fwmarkd_socket (sock_file (write)))
(typetransition mosey_app mosey_app anon_inode "[userfaultfd]")
(typeattributeset base_typeattr_1097
  (and (appdomain) (not (runas_app shell simpleperf mosey_app))))
(typeattributeset base_typeattr_1096
  (and (mosey_app) (not (runas_app shell simpleperf))))
```
Это подтверждает, что сервис явно добавлен в whitelist и интегрирован в SELinux-политику. Простое переключение SELinux в Permissive-режим проблему не решает, поскольку регистрация binder-сервиса всё равно требует наличия сопоставления SELinux-типа, и это сопоставление проверяется логикой servicemanager на уровне системы.

Теоретическим обходным путём могло бы быть изменение образов прошивки с добавлением недостающих policy- и context-файлов или (что предпочтительнее для Pixel-устройств) замена их версиями из Pixel 10 с последующим пересозданием и переподписанием образов с помощью инструмента вроде **avbroot**.

Файлы, которые с высокой вероятностью имеют отношение к этому (по поиску строки mosey):

Ниже — краткое описание каждого файла из распакованного Android-образа (описание от Gemini):
+ 202504.cil — файл SELinux-политики в формате CIL (Common Intermediate Language), содержащий публичные правила для конкретного уровня API Android (вероятно, API 36 / Android 16) с целью обратной совместимости со старыми vendor-разделами.
+	compatibility_matrix.xml — файл, определяющий аппаратные и программные требования для совместимости устройства с конкретной версией Android framework, включая версии HAL и конфигурацию ядра.
+ product_sepolicy.cil — SELinux-политики, специфичные для product-раздела, описывающие разрешения для сервисов и приложений, добавленных производителем.
+ system_ext_sepolicy.cil — SELinux-политики для раздела system_ext, в котором находятся некритичные системные компоненты и расширения, поставляемые вендором (Google).
+ system_ext_seapp_contexts — файл, сопоставляющий имена пакетов или подписи приложений с SELinux-доменами для процессов, запускаемых из system_ext.
+ vendor_file_contexts — файл сопоставления путей файловой системы в vendor-разделе с SELinux-метками для контроля доступа к аппаратно-зависимым файлам и библиотекам.
+ vendor_sepolicy.cil — основной файл SELinux-политики для vendor-раздела, содержащий правила безопасности для низкоуровневых сервисов и драйверов.
+ vendor_service_contexts — файл, назначающий SELinux-метки binder-сервисам, регистрируемым из vendor-раздела, для регулирования межпроцессного взаимодействия.

Если все эти файлы корректно интегрировать, теоретически система сможет автоматически запускать mosey_server и регистрировать binder-сервис, что может активировать функциональность Quick Share. При этом возможны и дополнительные условия (тем более что даже на некоторых Pixel 10 эта функция всё ещё не работает).

У меня недостаточно опыта в модификации factory-образов Android и работе с avbroot, поэтому я не буду делать это прямо на своем пикселе. Тем не менее, было бы интересно получить обратную связь от людей с опытом модификации Android-образов. В теории этот подход применим не только к устройствам Pixel, но и к любому современному Android-смартфону.
