=====================================
Instalando CentOS Stream 10/Fedora 44
=====================================
---------------------------------
Notas del proceso de instalación
---------------------------------

Descripción
===========
Guía de instalación de **CentOS Stream 10** y/o **Fedora 44** utilizando netboot.xyz (descargable en https://boot.netboot.xyz/ipxe/netboot.xyz.iso) o los medios oficiales de instalación.


Antes del lanzador gráfico
==========================
* Seleccionar **Linux Network Installs** (o **Linux Installers**).
* Seleccionar la distribución de preferencia: **CentOS Stream 10** o **Fedora 44**.
* Seleccionar el instalador interactivo estándar (Anaconda).


En el instalador gráfico
========================
Hay distintos apartados que deben ser configurados durante la instalación:

Language
--------
Seleccionar **English (United States)** (recomendado en servidores para consistencia de logs) o el idioma de tu preferencia.

Date & Time
-----------

::

    Region: Etc
    City: Coordinated Universal Time (UTC)

Keyboard
--------
#. Conservar o agregar la distribución de teclado deseada (ej. **Spanish; Castilian** o **English (US)**).

Security Policy
---------------
Seleccionar perfil de seguridad deseado (ej. **standard system security profile** o CIS benchmark según requerimiento).

Installation Destination
------------------------
#. Seleccionar el disco de destino y marcar **I will configure partitioning**.
#. Al presionar **Done**, seleccionar el esquema de particionado (**Btrfs** para **Fedora 44**, o bien **LVM/XFS** para **CentOS Stream 10**).
#. Crear los puntos de montaje requeridos: **/boot**, **/**, **/srv**, **/var** y **/home**.
#. Presionar **Done** y aceptar los cambios en disco.

Network & Hostname
------------------
En el apartado **Host Name** colocar el FQDN asignado para el nodo (ej. ``srv01.evalinux.net``) y encender la interfaz de red con DHCP o IP estática.

Root Password & User Creation
-----------------------------
* **Root Password**: Asignar una contraseña robusta (o deshabilitar acceso por contraseña y usar exclusivamente llaves SSH).
* **User Creation**:
  #. Crear el usuario principal y marcar **Make this user administrator** (acceso sudo).
  #. En **Advanced**, agregar los grupos de sistema correspondientes (ej. ``wheel``, ``webdev``, ``deployer``).


Finalizar
=========
#. Una vez finalizada la instalación dar click en el botón **Reboot System**.
#. Desmontar la imagen ISO de netboot.xyz en el hipervisor o BIOS para asegurar que el sistema inicie desde el almacenamiento local.


Otras Operaciones
=================
* Para acceder al servidor remotamente por medio de SSH:

  .. code:: sh

      ssh usuario@<IP-del-servidor>

* Para generar una contraseña segura y aleatoria de 30 caracteres (sin depender de herramientas obsoletas como apg):

  .. code:: sh

      cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 30; echo

  O bien con OpenSSL:

  .. code:: sh

      openssl rand -base64 24

* Para cambiar la contraseña de un usuario o root se utiliza:

  .. code:: sh

      passwd


Referencias
===========
* Documentación oficial de Red Hat: https://docs.redhat.com/
* Documentación de Fedora: https://docs.fedoraproject.org/
* Documentación de CentOS Stream: https://www.centos.org/centos-stream/

