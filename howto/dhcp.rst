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


Configuración
=============

```bash:/howto/dhcp/dhcpd```

.. note::

    la dirección MAC; declarada en `hardware-ethernet` es solo un ejemplo. Debes incluir la dirección de la interfaz de red del
    cliente a asignar.


Servicios
=========

```bash:/howto/dhcp/servicios```

.. warning::

    Nunca habilitar DHCP para la interfaz pública (eth0) porque podemos causar grandes problemas para nuestro ISP.


Probar
======
Para probar, simplemente debes agregar a un cliente a la red. En cuanto su interfaz se conecte, vas a ver información al
respecto en: `/var/lib/dhcpd/dhcpd.leases`.

Si el cliente es: `client.example.tld` y su dirección de hardware coincide, deberías ver que se le asignó la IP que definiste en la
configuración.


Comandos comunes
================
Estos comandos son para revisar configuraciones y ver información de logs.


`ip a`:
    Es para verificar la dirección de nuestras interfaces de red.

`ip link set dev eth1 down`:
    Es para desactivar la interfaz de red eth1.

`ip link set dev eth1 up`:
    Es para activar la interfaz de red eth1.

`journalctl -u dhcpd`:
    Es para revisar el estado constante de la aplicación.


Problemática
============
Nada por el momento.


Referencias
===========
* https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/ch-DHCP_Servers.html
* https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol
