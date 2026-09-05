==========
CloudSigma
==========
-----------------------------------
Notas generales sobre este servicio
-----------------------------------

Descripción
===========
CloudSigma es un proveedor europeo de infraestructura como servicio (IaaS) en la nube que ofrece servidores virtuales flexibles y recursos desagregados (asignación libre de núcleos de CPU, memoria RAM y almacenamiento SSD/NVMe sin restricciones de tamaños fijos predefinidos).

Permite el montaje directo de imágenes ISO personalizadas, configuración granular de redes privadas/públicas y acceso administrativo fuera de banda mediante consola remota VNC.


Acceso
======
1. Acceder al panel de control en https://mia.cloudsigma.com/ (o la región correspondiente).
2. Iniciar sesión con las credenciales asignadas.


Crear un Servidor
=================
A continuación se describe el procedimiento para aprovisionar un servidor virtual.

Inicio
------
* Seleccionar **Compute** en el menú lateral izquierdo.
* Hacer clic en **Create** en la barra superior.

Propiedades (Properties)
------------------------
* **Name**: Asignar el FQDN o identificador del servidor siguiendo la convención de nomenclatura de la infraestructura.
* **CPU type**: Seleccionar la arquitectura y perfil de CPU adecuado según la carga prevista.
* **CPU y RAM**: Asignar la cantidad exacta requerida de núcleos y gigabytes de memoria.

Almacenamiento (Drives)
-----------------------
* Hacer clic en **Attach Drive** y luego en **New Drive**.
* Configurar el disco raíz principal:
  - **Name**: Identificador del disco (ej. ``disco-raiz``).
  - **Device Type**: Tipo de bus (VirtIO para máximo rendimiento).
  - **Size**: Tamaño requerido en GB.
* Confirmar haciendo clic en **Create and attach drive**.
* Para instalar desde un medio de instalación (ISO):
  - Hacer clic en **Attach Drive** y seleccionar **CD-ROM**.
  - Seleccionar la imagen ISO requerida desde el repositorio de medios.

Avanzado (Advanced)
-------------------
* **Processor distribution**: Multi-CPU.
* **Processing units to be simulated**: Número máximo de procesadores asignados.
* **Enable NUMA**: Habilitado (recomendado para instancias medianas y grandes).

Guardar la configuración haciendo clic en el botón de confirmación en la parte superior derecha.


Operación y Conexión al Servidor
================================
Para iniciar la máquina virtual y acceder a la consola:

1. Seleccionar **Compute** en el menú lateral.
2. Hacer clic sobre la instancia deseada.
3. Iniciar el servidor con el botón **Start/Run**.
4. Activar la opción **VNC Tunnel**.
5. Copiar la dirección y puerto del túnel VNC generado y abrirlo con el cliente de escritorio remoto preferido.

.. note::

    En escritorios GNOME, puedes presionar la tecla **Súper** y abrir la aplicación **Conexiones** (o **Remmina**) e ingresar los datos del túnel VNC.


Referencias
===========
* https://www.cloudsigma.com/
* https://docs.cloudsigma.com/
