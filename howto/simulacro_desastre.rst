=====================
Simulacro de desastre
=====================

Descripción
===========
Explicación sobre qué hacer en caso de desastre, es decir, en caso de que el servidor deje de funcionar y el disco duro donde se
almacena la información de bareos(catalogo, base de datos, etc) aún funcione.

Prerrequisitos
==============
Un servidor con Archlinux, NginX, PHP56, BareOS y Postgresql instalados y corriendo en estado mínimo.

Procedimiento
=============

1. Copiar configuración del servidor dañado al servidor nuevo.
--------------------------------------------------------------
Ésta es tal vez la parte más importante pues debemos tener la misma configuración del servidor antiguo para que el nuevo pueda leer
las bases de datos de las cuales queremos recuperar la información.

2. Montar disco duro al nuevo servidor.
---------------------------------------
mount /dev/sda4 /mnt/

.. note::

    Puedes revisar tus discos duros disponibles con el comando `fdisk -l`.

3. Copiar con todo y permisos el directorio /var/lib/bareos/ del disco duro del servidor dañado.
------------------------------------------------------------------------------------------------
rm - /var/lib/bareos/
mkdir /var/lib/bareos/
chmod 755 /var/lib/bareos/
chown bareos:bareos /var/lib/bareos/
rsync -avP /mnt/var/lib/bareos/ /var/lib/bareos/

4. Crear copia de la base de datos actual.
------------------------------------------
systemctl stop bareos-dir bareos-sd bareos-fd
su postgres
psql
create database newdb template bareos;
\l
Ctrl + D dos veces.

5. Remover y crear tablas de la base de datos
---------------------------------------------
su postgres -c /usr/lib/bareos/scripts/drop_bareos_tables
su postgres -c /usr/lib/bareos/scripts/make_bareos_tables
su postgres -c /usr/lib/bareos/scripts/grant_bareos_privileges

Ingresamos a bconsole y correr `run` --> `RestoreFiles` --> JobId to restore: `0` --> `mod` --> `9` --> ingresar ruta completa al archivo bsr.
chown postgres:postgres /var/lib/bareos/bareos.sql
su postgres
psql bareos < /var/lib/bareos/bareos.sql
Ingresar a bconsole y correr `reload`
