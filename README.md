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
+ **compatibility_matrix.xml: **This file defines the hardware and software requirements that a device must meet to be compatible with a specific version of the Android framework, including HAL versions and kernel configurations.
+ **product_sepolicy.cil: **This file contains the SELinux security policies specific to the product partition, defining permissions for apps and services added by the device manufacturer.
+ **system_ext_sepolicy.cil: **This file houses the SELinux policies for the system_ext partition, which contains non-core system components and extensions provided by the vendor (Google).
+ **system_ext_seapp_contexts:** This configuration file maps app package names or signatures to specific SELinux security domains for processes running on the system_ext partition.
+ **vendor_file_contexts:** This file maps file system paths on the vendor partition to specific SELinux security labels to control access to hardware-specific files and libraries.
+ **vendor_sepolicy.cil:** This is the primary SELinux policy file for the vendor partition, containing the security rules that govern low-level hardware services and drivers.
+ **vendor_service_contexts:** This file assigns SELinux security labels to the various binder services registered by the vendor partition to regulate inter-process communication.

If these files correctly integrated, theoretically the system should be able to automatically start mosey_server and register the binder service, which may activate Quick Share functionality, although additional conditions may still apply (_because even some Pixel 10 series still missing this feature_).

I don't have sufficient experience in modifying android factory images and using avbroot therefore I won't try it on my only pixel phone. However, it would be interesting to hear feedback from someone with experience in android image modification. In theory, this method should be applicable **not only to Pixel devices, but to any modern Android phone.**
