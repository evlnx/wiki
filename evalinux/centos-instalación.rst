=================
Instalando CentOS
=================
--------------------------------
Notas del proceso de instalación
--------------------------------

Descripción
===========
Esta es la instalación utilizando netboot.xyz


Antes del lanzador gráfico
==========================
* Seleccionar "Linux Installers".
* Seleccionar "CentOS".
* Seleccionar la versión más nueva.
* Seleccionar el instalador gráfico.


En el lanzador gráfico
======================
Hay distintos apartados que deben ser llenados durante la instalación.

Language
--------
Seleccionar English (United States).

Date & Time
-----------

::

    Region: Etc
    City: Coordinated Universal Time

Keyboard
--------
#. Eliminar **English (US)**.
#. Agregar **Spanish; Castilian (Spanish)**.

Security Policy
---------------
Seleccionar **standard system security profile**.

Installation Destination
------------------------
#. Seleccionar la opción **i will configure partitioning** en la parte inferior del menú.
#. Al presionar **Done** aparecerá otro menú, cambiar **LVM** por **Btrfs**.
#. Dar click en **Click here to create them automatically**.
#. De nuevo dar click en **Done** en la esquina superior izquierda.

.. note:: Para crear subvolúmenes en **Btrfs** antes de presionar **Done**, dar click en el signo **+** en el menú del recuadro que aparece a la izquierda e insertar el nombre de éste.

Network & Hostname
------------------
En el apartado "Host Name" cambiarlo por el más apropiado (en mi caso "test1.axl.evalinux.net").

``Una vez presionado el botón "begin instalation"``

Root Password
-------------
Agregar un "strong" password.

User Creation
-------------
#. Crear un usuario.
#. Nombrarlo administrador.
#. Ponerle un "strong" password.
#. Dar click en el botón **advanced** ubicado en la parte inferior.
#. En el apartado "grupos" en la parte inferior izquierda, agregar, separados con una coma los grupos: webdev, gitter y deployer.
#. Dar click en **Done** en la esquina superior izquierda.


Finalizar
=========
Una vez finalizada la instalación dar click en el botón **Reboot** en la esquina inferior derecha.


Otras Operaciones
=================
* Para acceder al servidor remotamente por medio de una llave SSH es necesario que el servidor esté corriendo y correr el comando
  ``ssh root@<<IP-del-servidor>>`` y entrar con la clave de root del servidor.
* Para generar un password de 30 caracteres seguro se usa la aplicación **apg** y el comando ``apg -M CLN -m 30``.
* Para cambiar el password de root se utiliza el comando ``passwd``.
