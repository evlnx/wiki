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

Vamos a asumir que tenemos dos redes. La pública y la privada. La privada es: `192.168.77.0/24`. El DNS primario, vivirá en:
`192.168.77.10`.

El dominio a configurar es: `example.tld`.


Instalación
===========

```bash:/howto/dns/prerrequisitos.bash```


Configuración
=============

/etc/rndc.key
-------------
Para no quedarnos con la llave pre-generada, vamos a generar una nosotros mismos.

```bash:/howto/dns/rndc.bash```

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


/var/named/masters/example.tld.db
-------------------------
Este archivo contiene varias secciones que requieren algo de explicación:

La '@':
    Este signo se substituye por el valor declarado de `$ORIGIN`. Es decir, si tienes `example.tld.` como el valor de `$ORIGIN`, cada
    vez que pongas '@' o nada, se substituirá por `example.tld.`.

Serial '2017041100':
    El serial es un número que debe aumentar cada vez que actualizas una zona para notificarle a los esclavos de que hay cambios. Se
    estila poner año, mes, dia e id. Así, puedes hacer hasta 99 cambios en un día.

```bash:/howto/dns/example.tld.db```

Permisos
########
El directorio `masters` debe tener de dueño/grupo a: `root:named`. Los permisos recomendados son `2750`. Los archivos o zonas deben
tener al mismo dueño/grupo, pero con permisos `640`.


Servicios
=========

```bash:/howto/dns/servicios.bash```


Pruebas
=======
Para probar, necesitamos hacer que `/etc/resolv.conf` luzca así:

.. code-block:: bash

    search example.tld
    nameserver 192.168.77.10

Una vez que esté así en nuestro cliente y nuestro servidor, podemos iniciar las pruebas:

```bash:/howto/dns/pruebas.bash```


Troubleshooting
===============

Verificar tu configuración general
----------------------------------
Para hacer ésto, solo necesitas correr el comando: `named-checkconf`.

Para verificar que tus zonas son válidas, debes usar el comando: `named-checkzone <dominio> <archivo>`. Por ejemplo:
`named-checkzone example.tld /var/named/masters/example.tld.db`.

.. note::
    Cuando no sale nada, quiere decir que todo está bien.

Errores en los logs
-------------------
Es importante saber que en `/var/named/data/named.run` está el log de todo lo que sucede con bind. Por otro lado, tenemos el log de
`journalctl -u named`; el cual nos muestra la información relevante al sistema.


Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/sec-BIND.html

