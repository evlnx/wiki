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


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación oficial de Bareos: https://docs.bareos.org/

