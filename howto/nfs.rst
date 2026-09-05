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


Verificación y Pruebas
======================
Para validar la correcta exportación, montaje y consistencia transaccional del almacenamiento compartido NFSv4, sigue estos pasos:

1. **Estado del servicio y socket en el servidor**:

   .. code:: bash

      # Comprobar estado del servicio nfs-server
      systemctl status nfs-server.service

      # Verificar que el demonio está escuchando en el puerto TCP 2049
      ss -t4lnp | grep ':2049'

2. **Inspección de recursos exportados en el servidor**:

   .. code:: bash

      # Listar exportaciones activas del kernel y sus opciones efectivas
      exportfs -v

      # Consultar la lista de montajes remotos publicados
      showmount -e localhost

3. **Prueba funcional de montaje y lectura/escritura desde el cliente**:

   .. code:: bash

      # Montar explícitamente utilizando el protocolo NFSv4
      mount -t nfs4 -o rw,sync,hard,intr 192.168.77.10:/compartido /mnt

      # Comprobar estado del punto de montaje en el sistema de archivos
      findmnt /mnt

      # Crear un archivo de prueba con contenido para verificar permisos de escritura
      echo "EVALinux NFSv4 Test: $(date)" > /mnt/evalinux_test.txt

      # Leer el archivo y validar atributos
      cat /mnt/evalinux_test.txt
      ls -l /mnt/evalinux_test.txt

      # Limpiar archivo de prueba
      rm -f /mnt/evalinux_test.txt

4. **Monitoreo de telemetría y llamadas RPC**:

   .. code:: bash

      # Estadísticas de llamadas en el servidor
      nfsstat -s

      # Estadísticas de rendimiento y latencia en el cliente
      nfsstat -c
      nfsiostat 2 3


Problemática
============

Bloqueos de SELinux en directorios compartidos no convencionales
---------------------------------------------------------------
Por defecto, SELinux restringe el acceso de NFS a rutas del sistema a menos que tengan el tipo de contexto adecuado o se habiliten los booleanos pertinentes:

.. code:: bash

   # Asignar el tipo de contexto para exportación NFS a la carpeta compartida
   semanage fcontext -a -t nfs_t "/compartido(/.*)?"
   restorecon -Rv /compartido

   # Alternativa global si se exportan sistemas de archivos arbitrarios
   setsebool -P nfs_export_all_rw 1

Desconexión o congelamiento por bloqueo de cortafuegos
-----------------------------------------------------
NFSv4 opera exclusivamente sobre el puerto TCP 2049, pero utilidades auxiliares de descubrimiento o compatibilidad requieren servicios adicionales en Firewalld:

.. code:: bash

   # En el servidor, habilitar servicios indispensables en la zona activa
   firewall-cmd --permanent --add-service=nfs
   firewall-cmd --permanent --add-service=rpc-bind
   firewall-cmd --permanent --add-service=mountd
   firewall-cmd --reload

Mapeo erróneo de propietarios como nobody:nogroup
-------------------------------------------------
En NFSv4, los nombres de usuario y grupo se traducen usando cadenas de texto de la forma ``usuario@dominio``. Si el parámetro ``Domain`` en ``/etc/idmapd.conf`` no coincide entre servidor y cliente:

.. code:: bash

   # Configurar en /etc/idmapd.conf tanto en servidor como en cliente
   # [General]
   # Domain = example.tld

   # Vaciar la caché del resolutor idmap
   nfsidmap -c


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Proyecto Linux NFS: https://linux-nfs.org/

