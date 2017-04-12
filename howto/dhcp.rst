====
DHCP
====
--------------------------------------------
HowTo de como instalar; en GNU & Linux, DHCP
--------------------------------------------

Descripción
===========
Un servidor DHCP ofrece configuración de red a las máquinas conectadas. Es el que se encargará de mantener la red tal cual y la
queramos.


Prerrequisitos
==============

* CentOS 7.x


Instalación
===========

```bash:/howto/dhcp/instalacion```


Activar la red privada
======================

# Entrar al configurador de redes.

.. code:: bash

    nmtui

Modificar una conexión
______________________

#. Seleccionar la red "eth1".
#. Establecerla como manual.
#. Añadir la dirección deseada.
#. Agregar la búsqueda de dominios requerida.
#. Activar la opción de "nunca usar...".
#. Activar la opción de "ignorar rutas obtenidas automáticamente"

Activar una conexión
____________________
#. Activar la red "eth1".


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

.. warning::

    Nunca habilitar DHCP para la interfaz pública (eth0) porque podemos causar grandes problemas para nuestro ISP.


Tips
====
`ip a`:
    es para verificar las conexiones con las que se cuenta.

`journalctl -u dhcpd`:
    es para revisar el estado constante de la aplicación.


TODO
====
Hace falta explicar los elementos de la configuración de DHCP.


Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-DHCP_Servers.html
