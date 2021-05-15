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


NginX
=====


server.d
--------
Para facilitar el manejo de las instancias de servidor de NginX que vamos a utilizar, vamos a utilizar la funcionalidad de `include`
para poder segmentar la configuración.

Para agregar una instancia es necesario simplemente crear un archivo en `/etc/nginx/server.d/`; el cual tiene que tener `.conf`
como extensión. Por ejemplo: `/etc/nginx/server.d/misitio.tld.conf`.

include.d
---------
Para facilitar la configuración de nuestras instancias de servidor, preferimos agregar el directorio `include.d` para manejar
nuestras configuraciones específicas.

En el caso de PHP, es necesario solamente incluir el archivo `include.d/php.conf` para activar su uso.

.. warning::

    Es muy importante que borremos el archivo: `/srv/www/php/misitio.tld/default/public/info.php` después de usarlo para verificar
    el buen funcionamiento de PHP.

    El dejarlo implica el, potencialmente, mostrar mucha información; la cual, un cracker, pudiera usar para planear un ataque; por
    alguno de los medios disponibles.


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
