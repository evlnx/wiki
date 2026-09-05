====================================================
Servidor de respaldos con Bareos en Enterprise Linux
====================================================

---------------------------------------------------------------------------
HowTo de cómo instalar en GNU & Linux Bareos, NginX, PostgreSQL y PHP-FPM
---------------------------------------------------------------------------

Descripción
===========
Servidor para respaldos automatizados en distribuciones Enterprise Linux (Rocky Linux, AlmaLinux, RHEL). Los respaldos se gestionan a través de Bareos (Backup Archiving Recovery Open Sourced), utilizando NginX, PostgreSQL y PHP-FPM para el panel web Bareos-WebUI.


Prerrequisitos
==============

Instalación del sistema operativo
---------------------------------
Para la instalación base de Enterprise Linux, consulta: [[Instalando Enterprise Linux|centos/instalacion]]

Instalación de herramientas y paquetes esenciales
-------------------------------------------------
```bash:/howto/bareos-centos/prerrequisitos.bash```


Procedimiento
=============

NginX
-----

```bash:/howto/bareos-centos/nginx.bash```

.. note::
   `server.name` deberá ser sustituido por el FQDN o dirección asignada al servidor de administración.


PHP-FPM
-------

```bash:/howto/bareos-centos/php-fpm.bash```


SELinux
-------

```bash:/howto/bareos-centos/selinux.bash```


Servicios (NginX y PHP-FPM)
---------------------------

```bash:/howto/bareos-centos/servicios.bash```


Firewall
--------

```bash:/howto/bareos-centos/seguridad.bash```


PostgreSQL
----------

```bash:/howto/bareos-centos/postgresql.bash```


Bareos
------

```bash:/howto/bareos-centos/bareos.bash```

.. note::
    La contraseña y el usuario para el perfil de administración web pueden generarse de manera aleatoria y segura con:

    .. code:: sh

        openssl rand -base64 24

    O mediante:

    .. code:: sh

        cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 30; echo


Problemática
============
Nada por el momento.


Referencias
===========
* https://docs.bareos.org/
* https://www.nginx.com/resources/wiki/
* https://www.postgresql.org/docs/

