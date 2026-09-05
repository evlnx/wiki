============
Servidor NFS
============
-----------------------------------------------------------------------
HowTo: Cómo instalar y configurar NFS en CentOS Stream 10 y/o Fedora 44
-----------------------------------------------------------------------

Descripción
===========
Guía práctica para compartir almacenamiento entre servidores utilizando NFS (Network File System v4) específicamente en **CentOS Stream 10** y/o **Fedora 44**.


Prerrequisitos
==============

```bash:/howto/nfs/prerrequisitos.bash```


Servicios
=========

```bash:/howto/nfs/servicios.bash```

.. note::
    Estos comandos deben ejecutarse tanto en el servidor como en el cliente.


Servidor
========

```bash:/howto/nfs/servidor.bash```


Cliente
=======

```bash:/howto/nfs/cliente.bash```


Opciones de Montaje (Mount options)
===================================

soft/hard:
    Determina el comportamiento del cliente NFS si la conexión se interrumpe:
    * `hard` (predeterminado): La petición se reintenta indefinidamente hasta que el servidor responde, evitando corrupción de datos.
    * `soft`: Si tras un tiempo límite el servidor no responde, el cliente reporta error a la aplicación.

sec=mode:
    Especifica el esquema de seguridad y autenticación para la conexión (ej. `sec=sys` para autenticación estándar por UID/GID, o `sec=krb5p` para Kerberos cifrado).

.. note::
    En entornos de producción se recomienda utilizar `hard,intr` para asegurar consistencia transaccional.


Opciones de Exportación (Export options)
========================================

ro:
    Acceso de solo lectura (*read-only*).

rw:
    Acceso de lectura y escritura (*read-write*).

sync:
    Fuerza al servidor a responder a peticiones solo después de que los cambios hayan sido grabados en almacenamiento no volátil.

no_root_squash:
    Permite al usuario root del cliente operar como root en el directorio exportado (utilizar con precaución).


autofs
======
Para montaje bajo demanda automático, el archivo principal de configuración se encuentra en ``/etc/auto.master``:

```bash:/howto/nfs/autofs```


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Proyecto Linux NFS: https://linux-nfs.org/

