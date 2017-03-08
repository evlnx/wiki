============
Servidor NFS
============
-------------------------------------
HowTo de como instalar; en Linux, NFS
-------------------------------------

Descripción
===========
Éste es un ejemplo de dos servidores conectados por NFS en una red local con CentOS 7.


Prerrequisitos
==============

```bash:/howto/nfs/prerrequisitos```

Servicios
=========

```bash:/howto/nfs/servicios```

.. note::

    Éstos comandos deben correrse tanto en el servidor como en el cliente.


Servidor
========

```bash:/howto/nfs/servicios```


Cliente
=======

```bash:/howto/nfs/cliente```


Mount options
=============

soft/hard:
    Determina el comportamiento del cliente NFS luego de que el tiempo de una petición NFS se terminó, es decir, que no
    haya podido ser enviada. Si ninguna opción es especificada (o si la opción *hard* es especificada), entonces la petición NFS es
    reintentada indefinidamente. Si la opción *soft* es especificada, entonces el cliente falla la petición, la detiene y manda
    error.

sec=mode:
    Especifica el tipo de seguridad utilizada durante la autenticación de una conexión NFS.

sec=sys:
    Es la configuración predeterminada.

.. note::

    Más opciones en las referencias.


Export options
==============

ro:
    abreviación para *read only*.

rw:
    abreviación para *read and write*.


autofs
======

El archivo utilizado para ésta función se encuentra en */etc/auto.master* donde el formato general es el siguiente:

```bash:/howto/nfs/autofs```


Referencias
===========

* https://www.centos.org/docs/5/html/Deployment_Guide-en-US/ch-nfs.html
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Storage_Administration_Guide/ch-nfs.html
