=============
Servidor DNS
=============
------------------------------------------------------------------
HowTo: Cómo instalar un servidor DNS en CentOS Stream 10/Fedora 44
------------------------------------------------------------------


Descripción
===========
Un servidor DNS traduce nombres de dominio a direcciones IP (resolución directa) e inversamente. Esta guía aborda la implementación autoritativa y recursiva con BIND 9.


Prerrequisitos
==============

* CentOS Stream 10 y/o Fedora 44.

Vamos a asumir que tenemos dos redes: la pública y la privada. La privada es ``192.168.77.0/24``. El DNS primario vivirá en ``192.168.77.10``.

El dominio a configurar es: ``example.tld``.


Instalación
===========

```bash:/howto/dns/prerrequisitos.bash```


Configuración
=============

/etc/rndc.key
-------------
Para no quedarnos con la llave pre-generada, vamos a generar una nosotros mismos:

```bash:/howto/dns/rndc.bash```

De lo que resulte, vamos a obtener las secciones ``key`` y ``controls``; y las acomodaremos en ``/etc/rndc.key`` y ``/etc/named.conf`` respectivamente.

Ejemplo:

```bash:/howto/dns/rndc.key```

.. note::
    Ver la sección ``/etc/named.conf`` para el ejemplo de controls.

/etc/named.conf
---------------
Debemos cambiar las instancias de ``127.0.0.1`` o ``::1`` en las directivas ``listen-on``, ``listen-on-v6`` y ``allow-query`` a ``localnets`` y ``localhost``.

Ejemplo:

```bash:/howto/dns/named.conf```


/var/named/masters/example.tld.db
---------------------------------
Este archivo contiene varias secciones que requieren algo de explicación:

La '@':
    Este signo se substituye por el valor declarado de ``$ORIGIN``. Es decir, si tienes ``example.tld.`` como el valor de
    ``$ORIGIN``, cada vez que pongas '@' o nada, se substituirá por ``example.tld.``.

Serial '2017041100':
    El serial es un número que debe aumentar cada vez que actualizas una zona para notificarle a los secundarios (esclavos) de que hay cambios. Se estila poner año, mes, día e ID incremental (YYYYMMDDNN).

```bash:/howto/dns/example.tld.db```

Permisos
########
El directorio ``masters`` debe tener como dueño y grupo a ``root:named`` con permisos ``2750``. Los archivos de zona deben pertenecer a ``root:named`` con permisos ``640``.


Servicios
=========

```bash:/howto/dns/servicios.bash```


Pruebas
=======
Para probar, necesitamos hacer que ``/etc/resolv.conf`` apunte al servidor DNS configurado:

.. code:: sh

    search example.tld
    nameserver 192.168.77.10

Una vez que esté así en nuestro cliente y nuestro servidor, podemos iniciar las pruebas:

.. code:: sh

    # buscar el dominio principal
    dig example.tld

    # buscar los subdominios
    dig ns1.example.tld
    dig mail1.example.tld

    # buscar uno no existente y verificar la respuesta autoritativa
    dig nonexistent.example.tld


Problemática
============

Verificar tu configuración general
----------------------------------
Para verificar la sintaxis de la configuración principal, corre el comando:

.. code:: sh

    named-checkconf

Para verificar que tus zonas son válidas:

.. code:: sh

    named-checkzone example.tld /var/named/masters/example.tld.db

.. note::
    Cuando no arroja salida de error, indica que la sintaxis de zona es válida.

Errores en los logs
-------------------
Revisar el registro de actividad de bind en el log del sistema:

.. code:: sh

    journalctl -u named.service -f


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación oficial de BIND 9: https://bind9.readthedocs.io/


