=====================
Simulacro de desastre
=====================

Descripción
===========
Procedimiento de contingencia y recuperación ante desastres (DRP) en caso de fallo crítico de un servidor, recuperando el catálogo, la base de datos PostgreSQL y los volúmenes de respaldo de Bareos desde un disco o partición rescatada.


Prerrequisitos
==============
Un nuevo servidor operativo con CentOS Stream 10 o Fedora 44, con PostgreSQL, NginX y Bareos instalados y configurados con una topología compatible.


Procedimiento
=============

1. Copia de configuración previa
--------------------------------
Debemos asegurarnos de que el nuevo servidor cuente con la misma configuración de directores, dispositivos de almacenamiento (SD) y clientes (FD) que el servidor original para poder interpretar los volúmenes y catálogos:

.. code:: sh

    # verificar permisos de los archivos de configuración
    chown -R bareos:bareos /etc/bareos/
    find /etc/bareos/ -type d -exec chmod 750 {} \;
    find /etc/bareos/ -type f -exec chmod 640 {} \;


2. Montar el almacenamiento rescatado
-------------------------------------
Identificar el disco o partición que contiene los datos y montarlo en un punto temporal:

.. code:: sh

    mount /dev/sda4 /mnt/

.. note::
    Puedes verificar las particiones y discos disponibles con el comando ``lsblk -f`` o ``fdisk -l``.


3. Restaurar los archivos de almacenamiento de Bareos
-----------------------------------------------------
Sincronizar el directorio de datos de Bareos preservando permisos y atributos:

.. code:: sh

    mkdir -p /var/lib/bareos/
    chmod 755 /var/lib/bareos/
    chown bareos:bareos /var/lib/bareos/
    rsync -avP /mnt/var/lib/bareos/ /var/lib/bareos/


4. Respaldo preventivo de la base de datos actual
-------------------------------------------------
Detener los servicios de Bareos antes de operar sobre el catálogo:

.. code:: sh

    systemctl stop bareos-dir.service bareos-sd.service bareos-fd.service

Crear una copia de seguridad preventiva de la base de datos en PostgreSQL:

.. code:: sh

    su - postgres -c "psql -c 'CREATE DATABASE bareos_previo TEMPLATE bareos;'"


5. Recrear tablas del catálogo de Bareos
----------------------------------------
Reinicializar las estructuras de datos de Bareos en PostgreSQL:

.. code:: sh

    su - postgres -c /usr/lib/bareos/scripts/drop_bareos_tables
    su - postgres -c /usr/lib/bareos/scripts/make_bareos_tables
    su - postgres -c /usr/lib/bareos/scripts/grant_bareos_privileges


6. Restauración del catálogo y recarga de servicios
---------------------------------------------------
Si se cuenta con el volcado SQL del catálogo (``bareos.sql``):

.. code:: sh

    chown postgres:postgres /var/lib/bareos/bareos.sql
    su - postgres -c "psql bareos < /var/lib/bareos/bareos.sql"

Posteriormente, reiniciar los servicios de Bareos:

.. code:: sh

    systemctl restart bareos-dir.service bareos-sd.service bareos-fd.service

Para verificar y recargar la configuración desde la consola interactiva:

.. code:: sh

    bconsole
    # Dentro de bconsole ejecutar:
    # * reload
    # * status dir


Verificación y Pruebas
======================
Procedimientos para validar que la recuperación ante desastres fue exitosa y el catálogo es íntegro:

1. **Estado de los demonios de Bareos y PostgreSQL**:

   .. code:: bash

      systemctl status postgresql.service bareos-dir.service bareos-sd.service bareos-fd.service

2. **Verificación de integridad del catálogo en PostgreSQL**:

   Comprueba que las tablas del catálogo restaurado contengan los registros históricos de trabajos (Jobs), clientes y volúmenes:

   .. code:: bash

      # Contar la cantidad de clientes registrados en el catálogo
      su - postgres -c "psql -d bareos -c 'SELECT count(*) AS total_clientes FROM Client;'"

      # Verificar los últimos trabajos registrados antes del incidente
      su - postgres -c "psql -d bareos -c 'SELECT jobid, name, starttime, endtime, jobstatus, joberrors FROM Job ORDER BY jobid DESC LIMIT 5;'"

3. **Verificación del estado operativo desde bconsole**:

   Ejecuta comandos no interactivos con ``bconsole`` para auditar el estado del Director, Storage Daemon y Fileset:

   .. code:: bash

      # Consultar el estado del Director y programaciones pendientes
      bconsole -c "status dir"

      # Validar la conectividad con el demonio de almacenamiento (Storage Daemon)
      bconsole -c "status storage"

      # Listar los volúmenes reconocidos por el catálogo en el Storage Daemon
      bconsole -c "list media"

4. **Prueba de restauración en seco (Dry-Run Restore)**:

   Ejecuta un trabajo de restauración hacia un directorio temporal (por ejemplo, ``/tmp/bareos-restore/``) para confirmar la legibilidad física de los datos rescatados:

   .. code:: bash

      # Restaurar un archivo específico de prueba a través de bconsole
      bconsole <<EOF
      restore select current all done yes
      EOF

5. **Monitoreo de bitácoras del sistema**:

   .. code:: bash

      journalctl -u bareos-dir.service -u bareos-sd.service -e --no-pager


Problemática
============

Discrepancia en permisos de volúmenes o base de datos (Permission Denied)
------------------------------------------------------------------------
Si el Storage Daemon no puede leer los volúmenes rescatados o el Director falla al conectar a PostgreSQL:

.. code:: bash

   # Restaurar propiedad y permisos de los volúmenes de respaldo
   chown -R bareos:bareos /var/lib/bareos/storage/
   chmod 750 /var/lib/bareos/storage/
   chmod 640 /var/lib/bareos/storage/*

   # Comprobar contexto de SELinux si los datos se ubican en una partición dedicada
   semanage fcontext -a -t bareos_var_lib_t "/var/lib/bareos(/.*)?"
   restorecon -Rv /var/lib/bareos

El catálogo reporta inconsistencia o versión incompatible de esquema
--------------------------------------------------------------------
Si la versión de Bareos en el nuevo servidor es superior a la del respaldo, ejecuta la actualización del esquema:

.. code:: bash

   su - postgres -c /usr/lib/bareos/scripts/update_bareos_tables
   systemctl restart bareos-dir.service


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación oficial de Bareos: https://docs.bareos.org/

