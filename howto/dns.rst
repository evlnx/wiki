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

Vamos a asumir que tenemos dos redes. La pública y la privada. La privada es: ``192.168.77.0/24``. El DNS primario, vivirá en:
``192.168.77.10``.

El dominio a configurar es: ``example.tld``.


Instalación
===========

```bash:/howto/dns/prerrequisitos.bash```


Configuración
=============

/etc/rndc.key
-------------
Para no quedarnos con la llave pre-generada, vamos a generar una nosotros mismos.

```bash:/howto/dns/rndc.bash```

De lo que resulte, vamos a obtener las funciones ```key` y ``controls``; y las acomodaremos en ``/etc/rndc.key`` y
``/etc/named.conf`` respectivamente.

Ejemplo:

```bash:/howto/dns/rndc.key```

.. note::
    ver la sección ``/etc/named.conf`` para el ejemplo de controls.

/etc/named.conf
---------------
Debemos cambiar las intancias de ``127.0.0.1`` o ``::1`` en las funciones: ``listen-on``, ``listen-on-v6`` y ``allow-query`` a
``localnets``.  Además, debemos incluir ``localhost``.

Ejemplo:

```bash:/howto/dns/named.conf```


/var/named/masters/example.tld.db
---------------------------------
Este archivo contiene varias secciones que requieren algo de explicación:

La '@':
    Este signo se substituye por el valor declarado de ``$ORIGIN``. Es decir, si tienes ``example.tld.`` como el valor de
    ``$ORIGIN``, cada vez que pongas '@' o nada, se substituirá por ``example.tld.``.

Serial '2017041100':
    El serial es un número que debe aumentar cada vez que actualizas una zona para notificarle a los esclavos de que hay cambios. Se
    estila poner año, mes, dia e id. Así, puedes hacer hasta 99 cambios en un día.

```bash:/howto/dns/example.tld.db```

Permisos
########
El directorio ``masters`` debe tener de dueño/grupo a: ``root:named``. Los permisos recomendados son ``2750``. Los archivos o zonas
deben tener al mismo dueño/grupo, pero con permisos ``640``.


Servicios
=========

```bash:/howto/dns/servicios.bash```


Pruebas
=======
Para probar, necesitamos hacer que ``/etc/resolv.conf`` luzca así:

.. code-block:: sh

    search example.tld
    nameserver 192.168.77.10

