====
DHCP
====
--------------------------------------------
HowTo de como instalar; en GNU & Linux, DHCP
--------------------------------------------

Descripción
===========
Éste es un servidor DHCP; instalado en CentOS 7.

El servidor DHCP sirve, entre otras cosas, para asignar direcciones IP; automáticamente.


Prerrequisitos
==============

#. Tener una red privada en "eth1".


Instalación
===========
```bash:/howto/dhcp/instalacion```


DHCP
====

Configuración
-------------
```bash:/howto/dhcp/dhcpd```

.. note::

    la dirección MAC; declarada en `hardware-ethernet` es solo un ejemplo. Debes incluir la dirección de la interfaz de red del
    cliente a asignar.

Servicios
---------
```bash:/howto/dhcp/servicios```

TODO
----
Hace falta explicar los elementos de la configuración de DHCP.

.. note::

    `ip address` es para verificar las conexiones con las que se cuenta.

.. note::

    `journalctl -fu dhcpd` es para revisar los logs que la aplicación registra.

.. warning::

    Nunca habilitar DHCP para la interfaz pública (eth0) porque podemos causar grandes problemas para nuestro ISP.

Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-DHCP_Servers.html
