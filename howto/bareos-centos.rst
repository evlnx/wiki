==========================================
Servidor de respaldos con Bareos en Centos
==========================================

-----------------------------------------------------------------------------
HowTo de como instalar; en GNU & Linux, Bareos, NginX, PostgreSQL y PHP55-FPM
-----------------------------------------------------------------------------

[[_TOC_]]

Descripción
===========
Servidor para respaldos automatizados en Centos 7. Los respaldos automatizados se hacen a través de Bareos. Se utiliza, además:
Nginx, Postgresql y PHP55-fpm.

Prerrequisitos
--------------
Para la instalación de CentOS 7.x, puedes leer el siguiente howto: http://wiki.evalinux.com/centos/instalacion

```bash:/howto/```

NginX
=====

```bash:```

Instancia del servidor
----------------------
`server.name` deberá ser sustituido por el nombre del servidor que se utilizará. La locación de la webui puede variar.

Php55-fpm
=========

```bash:```

SELinux
=======

```bash:```

Servicios(nginx, php55)
=======================

```bash:```

Seguridad
=========

```bash:```

Postgresql
==========

```bash:```

Bareos
======

```bash:```

.. note::
    
    La contraseña y el usuario pueden ser generados aleatoriamente con apg, recomendamos utilizar
    contraseñas y nombres de usuario de 30 caracteres.

Troubleshooting
===============

Referencias
===========
* https://wiki.centos.org/es
* https://www.nginx.com/resources/wiki/
* https://www.softwarecollections.org/en/scls/rhscl/php55/
* http://doc.bareos.org
