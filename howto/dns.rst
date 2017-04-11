=============
Servidor DNS
=============
----------------------------------------------------------
HowTo sobre como instalar; en GNU & Linux, un servidor DNS
----------------------------------------------------------


[[_TOC_]]


Descripción
===========
Es un servidor que nos ayuda a traducir nombres de dominio a IP. Hay dos tipos de servidores: autoritativo y recursivo.


Prerrequisitos
==============

* CentOS 7


Instalación
===========

```bash:/howto/dns/prerrequisitos```


Configuración
=============

/etc/rndc.key
-------------
Para no quedarnos con la llave pre-generada, vamos a generar una nosotros mismos.

```bash:/howto/dns/rndc```

De lo que resulte, vamos a obtener las funciones `key` y `controls`; y las acomodaremos en `/etc/rndc.key` y `/etc/named.conf`
respectivamente.

Ejemplo:

```bash:/howto/dns/rndc.key```

.. note::
    ver la sección `/etc/named.conf` para el ejemplo de controls.

/etc/named.conf
---------------
Debemos cambiar las intancias de `127.0.0.1` o `::1` en las funciones: `listen-on`, `listen-on-v6` y `allow-query` a `localnets`.
Además, debemos incluir `localhost`.

Ejemplo:

```bash:/howto/dns/named.conf```


/var/named/example.tld.db
-------------------------

```bash:/howto/dns/example.tld.db```


Servicios
=========

```bash:/howto/dns/servicios```


Seguridad
=========


Troubleshooting
===============

Verificar tu configuración general
----------------------------------
Para hacer ésto, solo necesitas correr el comando: `named-checkconf`.

.. note::
    Cuando no sale nada, quiere decir que todo está bien.


Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/sec-BIND.html

