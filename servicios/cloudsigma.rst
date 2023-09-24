==========
CloudSigma
==========
-----------------------------------
Notas generales sobre este servicio
-----------------------------------

Descripción
===========
Pendiente.


Acceso
======
Primero entrar a https://mia.cloudsigma.com/.

Hacer login con usuario y contraseña


Crear un servidor
=================
A continuación, se describe como instalar un servidor.

Inicio
-------
* Dar click en "compute" en el menú lateral izquierdo.
* Dar click en "create" en el menú superior.

Properties
----------

::

    Name: siguiendo las características de lenguaje de un dominio agregar un nombre al servidor
    CPU type: seleccionar el adecuado de acuerdo al que se está suscrito
    CPU y RAM: seleccionar tamaño de acuerdo a lo necesario

Drives
------
* Dar click en "Attach Drive".
* Dar click en "New Drive".

::

    Name: éste debe ser nuestro principal disco duro, darle nombre
    Device Type: Establecer el tipo de dispositivo que éste será
    Size: Elegir el tamaño que éste tendrá

Para finalizarlo dar click en "Create and attach drive" en el menú superior

* Para el disco de instalación, crear otro dispositivo.

::

    Type: CD-ROM
    Browse: <disco de instalación>

Advanced
--------

::

    Processor distribution: Multi-CPU
    Procession units to be simulated: <máximo número de procedores>
    Enable NUMA: activado

Para terminar dar click en el botón "Save" ubicado en la parte inferior derecha.


Finalizar
=========
Una vez terminada la configuración dar click en el ícono verde de guardar en el menú superior.


Correr un servidor
==================
A continuación, el procedimiento necesario para correr un servidor

Inicio
------
1. Dar click en el botón "Compute" en el menú lateral izquierdo
2. Dar click en el servidor que querramos correr.
#. Dar click en el botón de iniciar en el menú superior.
#. Activar el VNC Tunnel.
#. Abrir el visor de escritorios remotos y ecribir el link proporcionado en la página.

.. note::  Para entrar a ésta aplicación presionar la tecla **súper** y escribir **VNC**.


Referencias
===========
