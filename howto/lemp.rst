=============
Servidor LEMP
=============
----------------------------------------------------------------
HowTo de como instalar; en GNU & Linux, NginX, MariaDB y PHP-FPM
----------------------------------------------------------------


Descripción
===========
Éste es un servidor instalado en CentOS 7. Consta de servicios HTTP, de PHP por socket y Maria DB con un password de root generado
aleatoriamente y de 30 caracteres.


Prerrequisitos
==============

```bash:/howto/lemp/prerrequisitos```

.. note::

    Iniciamos los servicios porque MariaDB lo requiere para ser configurado.

MariaDB
=======

```bash:/howto/lemp/mariadb```

.. warning::

    El archivo: `/root/.my.cnf` representa un riesgo de seguridad, ya que, permite a root accesar a la base de datos sin requerir
    credenciales.

    Dicho ésto, si algún usuario no autorizado adquiere root en nuestro servidor, estaremos perdidos.


PHP-FPM
=======

```bash:/howto/lemp/php-fpm```

.. note::

    Por seguridad, practicidad y desempeño, utilizamos `PHP-FPM` por medio de sockets.


Servicios
=========

```bash:/howto/lemp/servicios```


Seguridad
=========

```bash:/howto/lemp/seguridad```


Problemática
============

Referencias
===========
* https://wiki.centos.org/es
* https://www.nginx.com/resources/wiki/
* https://mariadb.com/kb/es/
* http://php.net/manual/es/
