=====
BtrFS
=====

* Es un sistema de archivos B-tree con naturaleza *Copy-on-Write* (CoW).
* Inicialmente diseñado por Chris Mason (Oracle Corporation) en 2007; posteriormente adoptado y desarrollado por Facebook, SUSE, Red Hat, Fujitsu y la comunidad de Linux.
* Sistema de archivos predeterminado en Fedora (estándar en Fedora 44).
* Características principales:
  * Subvolúmenes independientes con gestión de cuotas y snapshots casi instantáneos.
  * Verificación de integridad basada en sumas de verificación (checksums: CRC32C, XXHASH, SHA256, BLAKE2b) tanto para metadatos como para datos.
  * Soporte nativo para compresión transparente (zstd, lzo, zlib).
  * Soporte multi-dispositivo (RAID 0, 1, 10 integrados en el sistema de archivos).


===
LVM
===

* Logical Volume Manager (LVM2), basado en el framework `device-mapper` del kernel de Linux.
* Autor original: Heinz Mauelshagen.
* Permite abstraer el almacenamiento físico en tres capas:
  * **PV** (Physical Volumes): Particiones o discos físicos inicializados.
  * **VG** (Volume Groups): Agrupaciones de uno o más PVs en un grupo unificado.
  * **LV** (Logical Volumes): Volúmenes lógicos creados a partir del espacio de un VG, redimensionables en caliente.
* Soporta aprovisionamiento dinámico (*thin provisioning*), snapshots de lectura/escritura y redundancia (LVM-RAID).
* Estándar habitual en CentOS Stream 10 para flexibilidad de particionado.


===
XFS
===

* Creador original: Silicon Graphics (SGI) en 1993 para IRIX; portado al kernel de Linux en 2001.
* Sistema de archivos predeterminado en CentOS Stream 10.
* Sistema de archivos de 64 bits de alto rendimiento, optimizado para operaciones de E/S paralelas a gran escala.
* Capacidad: tamaño máximo de archivo y sistema de archivos de hasta 8 exabytes.
* Incorpora journaling de metadatos, asignación por demoras (*delayed allocation*) y reflink (copia en escritura para deduplicación eficiente).


====
Ext4
====

* Nombre: Fourth Extended File System.
* Evolución directa y compatible de **ext3** y **ext2**, desarrollado por Mingming Cao, Andreas Dilger, Dave Kleikamp, Theodore Ts'o y colaboradores.
* Sistema de archivos con journaling confiable y universalmente soportado en cualquier entorno GNU & Linux.
* Capacidad: volúmenes de hasta 1 exabyte (EiB) y archivos individuales de hasta 16 terabytes (TiB).
* Características:
  * Asignación por extensiones (*extents*) que reducen la fragmentación frente a bloques indirectos.
  * Pre-asignación persistente y multiasignador de bloques.
  * Desfragmentación en línea (`e4defrag`).
  * Altísima estabilidad y amplia compatibilidad para sistemas de rescate, almacenamiento integrado y servidores legacy.


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/

