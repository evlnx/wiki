==============================================================
Virtualización Headless KVM/QEMU con virt-install y Cloud-Init
==============================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
KVM (*Kernel-based Virtual Machine*) es el módulo de virtualización nativo del kernel Linux que transforma el sistema operativo en un hipervisor tipo 1 (*bare-metal*), aprovechando las extensiones de virtualización por hardware del procesador (Intel VT-x y AMD-V). QEMU (*Quick Emulator*) opera en espacio de usuario emulando buses, chipsets (arquitectura moderna Q35/ICH9) y proporcionando controladores paravirtualizados VirtIO (almacenamiento, red, canales de comunicación y consola) que minimizan las trampas de hipervisor (*VM-exits*) y maximizan el rendimiento de E/S.

Libvirt proporciona una capa de abstracción estandarizada y un conjunto de demonios que gestionan el ciclo de vida de los dominios virtuales, redes virtuales y pools de almacenamiento mediante definiciones declarativas en XML. En **CentOS Stream 10** y **Fedora 44**, Libvirt implementa una arquitectura de demonios modulares (como ``virtqemud``, ``virtnetworkd`` y ``virtstoraged``) activados bajo demanda mediante sockets de systemd, coexistiendo con el modo monolítico tradicional ``libvirtd``.

El aprovisionamiento desatendido sin entorno gráfico (*headless*) combina la herramienta CLI ``virt-install`` con ``cloud-init`` mediante la fuente de datos local *NoCloud*. Este paradigma permite descargar imágenes genéricas oficiales (*GenericCloud* o *Cloud Base Images* en formato QCOW2) y aprovisionar instancias personalizadas en segundos, inyectando de manera determinista llaves SSH, usuarios administrativos, nombres de host, direcciones de red y paquetes base sin requerir interacción manual con instaladores interactivos ni consolas gráficas.


Prerrequisitos
==============
* Compatibilidad con virtualización por hardware en el procesador del host. Se debe verificar la presencia de las extensiones Intel VMX (``vmx``) o AMD SVM (``svm``) mediante el comando ``lscpu`` o inspeccionando ``/proc/cpuinfo``:

   .. code:: bash

      # Comprobar soporte de virtualización en el microprocesador
      grep -E --color=auto '(vmx|svm)' /proc/cpuinfo
      # O mediante lscpu
      lscpu | grep -i virtualization

* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Privilegios de superusuario (acceso administrativo mediante ``sudo``).
* Políticas de SELinux en modo Enforcing activas (el confinamiento de máquinas virtuales se realiza mediante sVirt con categorías MCS dinámicas).
* Acceso a repositorios oficiales del sistema operativo configurado y operativo.


Instalación
===========
Para desplegar la pila completa de virtualización headless, herramientas de gestión de discos y utilidades de metadatos para cloud-init, se instalan los paquetes correspondientes mediante ``dnf``:

.. code:: bash

   # Instalar el hipervisor, demonios de libvirt, utilidades de aprovisionamiento y cloud-utils
   dnf -y install \
     qemu-kvm \
     libvirt \
     libvirt-daemon-kvm \
     virt-install \
     virt-viewer \
     libguestfs-tools \
     cloud-utils

Detalle de los componentes instalados:

* ``qemu-kvm``: Binarios del emulador QEMU optimizados para KVM y soporte para aceleración por hardware.
* ``libvirt`` y ``libvirt-daemon-kvm``: Biblioteca de virtualización, controladores para KVM/QEMU y utilidades de control como ``virsh``.
* ``virt-install``: Herramienta de línea de comandos para la creación declarativa y aprovisionamiento automatizado de máquinas virtuales.
* ``virt-viewer``: Cliente ligero de consola y visualización remota (incluye comandos para inspección de puertos gráficos y consolas).
* ``libguestfs-tools``: Conjunto de utilidades forenses y de manipulación de imágenes de disco sin requerir iniciar la máquina virtual (``virt-customize``, ``virt-sysprep``, ``guestfish``).
* ``cloud-utils``: Paquete que provee herramientas esenciales de automatización de nube, incluyendo ``cloud-localds`` para empaquetar archivos ``user-data`` y ``meta-data`` en volúmenes ISO NoCloud.


Configuración
=============

Habilitación e Inicio de Servicios (Monolítico vs Modular)
----------------------------------------------------------
En CentOS Stream 10 y Fedora 44, se puede optar por el demonio tradicional monolítico o por la arquitectura moderna de demonios modulares activados por socket de systemd.

Opción A: Demonio monolítico tradicional mediante activación por socket (recomendado):
Al activar el socket en lugar del servicio continuo, systemd instancia el demonio bajo demanda ante peticiones de gestión (``virsh``, virt-manager, API RPC) y permite que se suspenda de forma limpia tras inactividad (``--timeout 120``), optimizando el uso de memoria:

.. code:: bash

   # Habilitar e iniciar socket del demonio monolítico (activa automáticamente libvirtd-ro y libvirtd-admin)
   systemctl enable --now libvirtd.socket

Opción B: Arquitectura modular split-daemon (recomendado en entornos de alta densidad o mínimos privilegios):
En la arquitectura modular, cada subsistema de virtualización corre en un proceso aislado. Systemd escucha en los sockets UNIX y levanta los servicios bajo demanda:

.. code:: bash

   # 1. Habilitar e iniciar sockets de registro y bloqueo
   systemctl enable --now virtlogd.socket virtlockd.socket

   # 2. Habilitar e iniciar sockets modulares de hipervisor, red y almacenamiento
   systemctl enable --now \
     virtqemud.socket virtqemud-ro.socket virtqemud-admin.socket \
     virtnetworkd.socket virtnetworkd-ro.socket virtnetworkd-admin.socket \
     virtstoraged.socket virtstoraged-ro.socket virtstoraged-admin.socket \
     virtnodedevd.socket virtnodedevd-ro.socket virtnodedevd-admin.socket \
     virtsecretd.socket virtsecretd-ro.socket virtsecretd-admin.socket

   # 3. Habilitar proxy de compatibilidad para clientes RPC locales y remotos
   systemctl enable --now virtproxyd.socket virtproxyd-ro.socket virtproxyd-admin.socket


Configuración de Red: Linux Bridge (br0) con NetworkManager
-----------------------------------------------------------
Para que las máquinas virtuales tengan conectividad de capa 2 (L2) directa en la red física del host (obteniendo direcciones IP del router/DHCP de la red corporativa/local), se configura un puente Linux (*Linux Bridge*) administrado por NetworkManager:

.. code:: bash

   # 1. Identificar la interfaz de red física conectada (ejemplo: eth0 o enp3s0)
   nmcli device status

   # 2. Crear el perfil de conexión del puente br0
   nmcli con add type bridge con-name br0 ifname br0

   # 3. Vincular la interfaz física de red como puerto esclavo del puente
   nmcli con add type bridge-slave con-name br0-port1 ifname eth0 master br0

   # 4. Configurar el puente para obtener dirección IP por DHCP (o estática si aplica)
   nmcli con mod br0 ipv4.method auto ipv6.method auto

   # 5. Desactivar STP (Spanning Tree Protocol) si es un puente local simple sin bucles
   nmcli con mod br0 bridge.stp no

   # 6. Activar la conexión del puente (asociará automáticamente el puerto esclavo)
   nmcli con up br0

Si se prefiere mantener las máquinas virtuales aisladas detrás de un esquema de traducción de direcciones de red (NAT) en el host, se puede utilizar la red predeterminada provista por libvirt:

.. code:: bash

   # Iniciar y configurar arranque automático de la red NAT predeterminada
   virsh net-start default
   virsh net-autostart default


Gestión del Pool de Almacenamiento Predeterminado
-------------------------------------------------
Libvirt organiza las imágenes de disco en *Storage Pools*. El almacenamiento predeterminado de tipo directorio se ubica en ``/var/lib/libvirt/images``:

.. code:: bash

   # Verificar si el pool default ya se encuentra registrado
   virsh pool-list --all

   # Si el pool no existe, definirlo, crearlo y activarlo
   virsh pool-define-as default dir --target /var/lib/libvirt/images
   virsh pool-build default
   virsh pool-start default
   virsh pool-autostart default

   # Refrescar el pool para indexar imágenes presentes en el directorio
   virsh pool-refresh default


Preparación de Metadatos Cloud-Init (user-data y meta-data)
-----------------------------------------------------------
La fuente de datos *NoCloud* de ``cloud-init`` lee dos archivos esenciales en el primer arranque:

1. ``user-data``: Configuración del sistema, usuarios, llaves SSH y paquetes.
2. ``meta-data``: Identificador único de la instancia y nombre del equipo.

Crear el archivo ``/var/lib/libvirt/images/meta-data``:

.. code:: yaml

   # Archivo: /var/lib/libvirt/images/meta-data
   instance-id: vm-app01-id
   local-hostname: vm-app01.evalinux.lan

Crear el archivo ``/var/lib/libvirt/images/user-data`` (sustituir la clave pública SSH por la del administrador):

.. code:: yaml

   #cloud-config
   # Archivo: /var/lib/libvirt/images/user-data
   users:
     - name: sysadmin
       gecos: Administrador del Sistema
       sudo: ALL=(ALL) NOPASSWD:ALL
       shell: /usr/bin/bash
       lock_passwd: true
       ssh_authorized_keys:
         - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForSysadminHostAuthToken sysadmin@evalinux.com

   package_update: true
   package_upgrade: false
   packages:
     - qemu-guest-agent
     - curl
     - tar
     - rsync
     - tmux

   growpart:
     mode: auto
     devices: ['/']
     ignore_growroot_failure: false

   power_state:
     mode: reboot
     message: Reiniciando tras inicialización de cloud-init
     condition: True

Generación del medio NoCloud:

Existen dos métodos para suministrar estos metadatos a la máquina virtual:

* **Método 1: Generación de imagen ISO NoCloud con cloud-localds o genisoimage**:

   .. code:: bash

      # Opción 1A: Con cloud-localds (requiere paquete cloud-utils)
      cloud-localds /var/lib/libvirt/images/vm-app01-seed.iso \
        /var/lib/libvirt/images/user-data \
        /var/lib/libvirt/images/meta-data

      # Opción 1B: Con genisoimage (etiqueta de volumen cidata obligatoria)
      genisoimage -output /var/lib/libvirt/images/vm-app01-seed.iso \
        -volid cidata -joliet -rock \
        /var/lib/libvirt/images/user-data \
        /var/lib/libvirt/images/meta-data

* **Método 2: Parámetro nativo --cloud-init de virt-install**:
  La utilidad ``virt-install`` en versiones modernas soporta el argumento ``--cloud-init``, encargándose de generar y montar el medio efímero automáticamente sin pasos intermedios.


Aprovisionamiento de la Máquina Virtual con virt-install
--------------------------------------------------------
Descargar una imagen base de nube oficial (por ejemplo, la imagen GenericCloud de CentOS Stream 10 o Fedora 44) y ubicarla en el pool de almacenamiento:

.. code:: bash

   # Descargar imagen oficial de CentOS Stream 10 GenericCloud
   curl -Lo /var/lib/libvirt/images/CentOS-Stream-GenericCloud-10.qcow2 \
     https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2

   # Crear un disco de copia en escritura (Copy-on-Write) de 20 GiB con respaldo en la imagen base
   qemu-img create -f qcow2 \
     -F qcow2 \
     -b /var/lib/libvirt/images/CentOS-Stream-GenericCloud-10.qcow2 \
     /var/lib/libvirt/images/vm-app01.qcow2 20G

Ejecutar el aprovisionamiento headless mediante ``virt-install``:

.. code:: bash

   virt-install \
     --name vm-app01 \
     --memory 4096 \
     --vcpus 2 \
     --disk path=/var/lib/libvirt/images/vm-app01.qcow2,size=20,format=qcow2 \
     --os-variant rhel10.0 \
     --network bridge=br0 \
     --graphics none \
     --console pty,target_type=serial \
     --cloud-init user-data=/var/lib/libvirt/images/user-data,meta-data=/var/lib/libvirt/images/meta-data \
     --noautoconsole

Desglose técnico de parámetros utilizados:

* ``--name vm-app01``: Asigna el identificador único del dominio ante libvirt.
* ``--memory 4096``: Asigna 4096 MiB de memoria RAM al huésped.
* ``--vcpus 2``: Define 2 vCPUs virtuales asignadas al proceso QEMU.
* ``--disk path=...,size=20,format=qcow2``: Conecta el disco QCOW2 aprovisionado como dispositivo de almacenamiento VirtIO.
* ``--os-variant rhel10.0``: Optimiza la arquitectura de hardware emulado (bus PCIe q35, temporizadores TSC/KVM, controladores VirtIO modernos) de acuerdo al perfil del sistema operativo objetivo (en Fedora 44 también se admite ``--osinfo fedora43`` o ``centos-stream10``).
* ``--network bridge=br0``: Conecta la interfaz virtual de red directamente al puente Linux del host. Si se utiliza la red NAT, se especifica ``--network network=default``.
* ``--graphics none``: Suprime la emulación de adaptadores gráficos y servidores VNC/SPICE, optimizando la instancia para modo headless y liberando memoria.
* ``--console pty,target_type=serial``: Configura una consola serial emulada conectada a un pseudo-terminal (PTY), permitiendo la administración directa vía texto interactivo.
* ``--cloud-init user-data=...,meta-data=...``: Inyecta los archivos de inicialización declarativa mediante una unidad NoCloud generada dinámicamente por libvirt.
* ``--noautoconsole``: Impide que ``virt-install`` tome el control de la terminal al invocar el comando, devolviendo el prompt inmediatamente mientras la máquina virtual inicia en segundo plano.


Verificación y Pruebas
======================
Procedimientos paso a paso para auditar y operar la máquina virtual aprovisionada:

#. **Listado y estado de dominios virtuales**:

   .. code:: bash

      # Listar todos los dominios activos e inactivos
      virsh list --all

#. **Inspección de recursos e información del dominio**:

   .. code:: bash

      # Consultar información detallada de vCPUs, memoria y estado de ejecución
      virsh dominfo vm-app01

#. **Acceso interactivo mediante la consola serial**:

   .. code:: bash

      # Conectar a la consola serial del huésped
      virsh console vm-app01

   .. note::

      Para desconectarse y salir de la consola serial de ``virsh`` regresando a la terminal del host, presionar la combinación de teclas: ``Ctrl`` + ``]`` (o ``Ctrl`` + ``5`` en algunas distribuciones de teclado).

#. **Detección de dirección IP y verificación de red**:

   .. code:: bash

      # Consultar direcciones IP asignadas mediante el agente de QEMU
      virsh domifaddr vm-app01 --source agent

      # O consultar la dirección IP a través de la tabla ARP del puente o red local
      virsh domifaddr vm-app01 --source arp

#. **Comprobación de acceso seguro vía SSH**:

   .. code:: bash

      # Conectar a la instancia aprovisionada utilizando la llave SSH configurada (ejemplo: 192.168.1.50)
      ssh -i ~/.ssh/id_ed25519 sysadmin@192.168.1.50

#. **Verificación interna del agente QEMU y estado de Cloud-Init**:

   .. code:: bash

      # Comprobar el canal de comunicación con qemu-guest-agent desde el host
      virsh qemu-agent-command vm-app01 '{"execute":"guest-ping"}'

      # En el interior del guest, confirmar que cloud-init completó sin errores
      cloud-init status --wait


Problemática
============

Habilitación de Virtualización Anidada (Nested Virtualization)
--------------------------------------------------------------
Al ejecutar hipervisores dentro de la máquina virtual (por ejemplo, para laboratorios de Kubernetes con Minikube/KubeVirt o pruebas de Podman con aislamiento por VM), se requiere activar la virtualización anidada en el kernel del host:

.. code:: bash

   # 1. Verificar si el host ya tiene activada la virtualización anidada
   # Para procesadores Intel:
   cat /sys/module/kvm_intel/parameters/nested
   # Para procesadores AMD:
   cat /sys/module/kvm_amd/parameters/nested
   # El valor esperado es 'Y' o '1'

Si el parámetro retorna ``N`` o ``0``, crear el archivo de configuración en ``/etc/modprobe.d/kvm.conf``:

.. code:: ini

   # Archivo: /etc/modprobe.d/kvm.conf
   # Para sistemas basados en Intel VT-x:
   options kvm_intel nested=1

   # Para sistemas basados en AMD-V:
   options kvm_amd nested=1

Recargar los módulos de KVM en el host sin reiniciar:

.. code:: bash

   # Para Intel:
   modprobe -r kvm_intel && modprobe kvm_intel

   # Para AMD:
   modprobe -r kvm_amd && modprobe kvm_amd

Para que el huésped pueda utilizar estas extensiones de hardware, la máquina virtual debe crearse o editarse para pasar las capacidades directas del procesador mediante el modelo ``host-passthrough``:

.. code:: bash

   # Configurar la VM para exponer la CPU del host de forma transparente
   virsh edit vm-app01
   # Asegurar que el elemento <cpu> contenga:
   # <cpu mode='host-passthrough' check='none'/>


Bloqueos de Acceso por SELinux en Almacenamiento no Estándar
------------------------------------------------------------
En CentOS Stream 10 y Fedora 44, SELinux opera en modo Enforcing con la política sVirt. Si las imágenes de disco se almacenan en rutas no estándar (como particiones montadas en ``/data/vms``, ``/srv/vms`` o discos secundarios), QEMU fallará con errores de tipo ``Permission denied`` al intentar abrir los archivos de imagen.

Diagnóstico de eventos denegados por SELinux:

.. code:: bash

   # Consultar denegaciones AVC recientes asociadas a procesos de virtualización
   ausearch -m avc -ts recent | grep svirt

Solución mediante la asignación persistente del tipo de contexto ``virt_image_t``:

.. code:: bash

   # Registrar la regla de contexto persistente en la política de SELinux
   semanage fcontext -a -t virt_image_t "/data/vms(/.*)?"

   # Aplicar inmediatamente los contextos en el sistema de archivos
   restorecon -Rv /data/vms


Bloqueo de Terminal o Pantalla en Blanco en la Consola Serial
-------------------------------------------------------------
Al ejecutar ``virsh console vm-app01``, la terminal puede quedar bloqueada en ``Connected to domain 'vm-app01'`` sin responder a pulsaciones de teclado ni mostrar el prompt de inicio de sesión (*login*).

Causa técnica:
El kernel del huésped no tiene configurada la consola serial como salida primaria o el servicio systemd ``serial-getty@ttyS0.service`` no ha sido activado dentro del sistema operativo invitado.

Solución:
Al instalar sistemas operativos desde árboles de red o medios de instalación interactivos con ``virt-install``, se deben pasar los parámetros de consola explícitos en el kernel:

.. code:: bash

   --extra-args "console=tty0 console=ttyS0,115200n8"

En imágenes cloud existentes o aprovisionadas, se puede habilitar la consola serial modificando los argumentos del kernel con ``grubby`` dentro del huésped:

.. code:: bash

   # En el interior del huésped:
   grubby --update-kernel=ALL --args="console=tty0 console=ttyS0,115200n8"

   # Habilitar e iniciar la escucha del terminal getty en el puerto serial
   systemctl enable --now serial-getty@ttyS0.service


Referencias
===========
* Documentación oficial de Red Hat Enterprise Linux 10 (Configuring and Managing Virtualization): https://docs.redhat.com/
* Referencia de esquemas XML de dominio de Libvirt: https://libvirt.org/formatdomain.html
* Documentación de arquitectura de demonios modulares de Libvirt: https://libvirt.org/daemons.html
* Manual de referencia de QEMU: https://www.qemu.org/docs/master/
* Documentación oficial de Cloud-Init (NoCloud Datasource): https://cloudinit.readthedocs.io/
