=======================================================
Aprovisionamiento Desatendido con Kickstart e iPXE/HTTP
=======================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
El aprovisionamiento desatendido en distribuciones de la familia Red Hat se fundamenta en el marco de instalación Anaconda y en la especificación declarativa de archivos Kickstart (``ks.cfg``). Mediante Kickstart, los administradores de sistemas e ingenieros de infraestructura definen con exactitud la configuración del sistema operativo destino (particionado de discos, esquemas LVM, repositorios de paquetes, parámetros de red, cuentas de usuario, cortafuegos y políticas de SELinux), eliminando por completo la necesidad de interacción manual durante el despliegue.

En infraestructuras empresariales modernas basadas en **CentOS Stream 10** y **Fedora 44**, el arranque por red tradicional basado en TFTP introduce cuellos de botella severos debido a las limitaciones de transferencia de dicho protocolo ante imágenes modernas de kernel y ramdisk (cuyo tamaño supera frecuentemente los 100 MiB). La integración de **iPXE** permite encadenar el proceso de arranque desde DHCP hacia el protocolo HTTP/HTTPS de alto rendimiento, optimizando drásticamente los tiempos de transferencia de ``vmlinuz`` e ``initrd.img``.

Esta guía técnica detalla la arquitectura completa de despliegue automatizado: la sintaxis contemporánea de Kickstart compatible con Anaconda en CentOS Stream 10 y Fedora 44, la validación estática de directivas con ``ksvalidator``, la configuración del servidor web HTTP con SELinux y cortafuegos, el script de arranque iPXE para el encadenamiento del instalador, y el procedimiento de verificación mediante máquinas virtuales KVM y auditoría de bitácoras en ``/var/log/anaconda/``.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** para el servidor de aprovisionamiento (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Privilegios de superusuario en el sistema de gestión (acceso administrativo mediante ``sudo``).
* Políticas de SELinux en modo Enforcing activas en todos los nodos de la infraestructura.
* Servidor HTTP (Caddy o Nginx) accesible por la red de aprovisionamiento para alojar los archivos Kickstart e imágenes de arranque.
* Infraestructura de red local con servidor DHCP (ISC Kea o DHCPd) y servidor TFTP configurados para entregar el binario inicial de iPXE (``undionly.kpxe`` para BIOS o ``ipxe.efi``/``snponly.efi`` para UEFI).
* Conectividad a Internet o a réplicas locales de los repositorios BaseOS/AppStream para CentOS Stream 10 y Everything/Fedora para Fedora 44.


Instalación de Herramientas
===========================
Para crear, auditar y verificar archivos Kickstart, se requiere la suite ``pykickstart``, la cual provee la utilidad ``ksvalidator`` para análisis sintáctico estático contra esquemas específicos de versión. Adicionalmente, se instalan herramientas de virtualización y servidor web:

.. code:: bash

   # Instalar pykickstart y utilidades de red en el servidor de control
   dnf -y install pykickstart caddy curl openssl

   # Instalar utilidades de virtualización KVM para pruebas de despliegue
   dnf -y install qemu-kvm libvirt virt-install


Estructura del Archivo Kickstart (ks.cfg)
=========================================
Un archivo Kickstart se divide en tres bloques fundamentales: la **sección de comandos** (configuración del sistema, red, usuarios y almacenamiento), la **sección de paquetes** (definición de software a instalar o excluir) y la **sección de post-instalación** (scripts de personalización y endurecimiento ejecutados al finalizar la copia de archivos).


Sección de Comandos
-------------------
La sección de comandos declara los parámetros globales de la instalación. A continuación se presentan las directivas esenciales requeridas para un despliegue desatendido en CentOS Stream 10 y Fedora 44:

.. code:: kickstart

   # ==============================================================================
   # Definición de repositorios y orígenes de instalación
   # ==============================================================================
   # En CentOS Stream 10:
   url --url=https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/
   repo --name="AppStream" --baseurl=https://mirror.stream.centos.org/10-stream/AppStream/x86_64/os/

   # Alternativa en Fedora 44 (descomentar si el destino es Fedora):
   # url --url=https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/

   # Modo de instalación sin interfaz gráfica
   text

   # Parámetros regionales y de idioma
   lang es_MX.UTF-8
   keyboard latam
   timezone America/Mexico_City --utc

   # Configuración de red (asignación automática mediante DHCP en la interfaz activa)
   network --bootproto=dhcp --ipv6=auto --activate --onboot=yes

   # Perfil de autenticación del sistema (SSSD con creación automática de directorios personales)
   authselect select sssd with-mkhomedir --force

   # Desactivar acceso directo a root y crear cuenta de administración con privilegios sudo
   rootpw --lock
   user --name=sysadmin --groups=wheel --iscrypted --password=$6$fK8jL2vP9qW3zR1y$mZbkFk4oBv0YV3GZ7dK2Lw1e8j0fVbNmK9P0Q7W2e1Y.8HkL0Vp9Qw3Zr1YmZbkFk4oBv0YV3GZ7dK2Lw --sshkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKickstartAdminKey20260905sysadmin sysadmin@evalinux.com"

   # Seguridad: Cortafuegos activo con SSH permitido y SELinux en modo Enforcing
   firewall --enabled --service=ssh
   selinux --enforcing

   # ==============================================================================
   # Esquema de particionado de almacenamiento mediante LVM
   # ==============================================================================
   zerombr
   clearpart --all --initlabel

   # Creación de particiones obligatorias del sistema (incluye /boot/efi si es UEFI)
   reqpart --add-boot
   part /boot --fstype="xfs" --size=1024

   # Creación del volumen físico (PV) y grupo de volúmenes (VG)
   part pv.01 --fstype="lvmpv" --size=1 --grow
   volgroup vg_system pv.01

   # Asignación de volúmenes lógicos (LV) con tamaños adecuados para servidores
   logvol / --vgname=vg_system --size=15360 --fstype="xfs" --name=lv_root
   logvol /var --vgname=vg_system --size=10240 --fstype="xfs" --name=lv_var
   logvol /var/log --vgname=vg_system --size=5120 --fstype="xfs" --name=lv_log
   logvol /var/log/audit --vgname=vg_system --size=2048 --fstype="xfs" --name=lv_audit
   logvol /home --vgname=vg_system --size=5120 --fstype="xfs" --name=lv_home
   logvol swap --vgname=vg_system --size=4096 --fstype="swap" --name=lv_swap

   # Reiniciar y expulsar el medio de instalación al completar
   reboot --eject


Sección de Paquetes (%packages)
-------------------------------
La sección ``%packages`` especifica el software que formará parte de la instalación base. El uso de la bandera ``--excludedocs`` reduce el consumo de disco, mientras que el prefijo ``-`` permite excluir paquetes o grupos no deseados:

.. code:: kickstart

   %packages --excludedocs
   # Grupo esencial mínimo de instalación
   @core

   # Herramientas administrativas y de red
   NetworkManager
   curl
   openssh-server
   sudo
   rsync
   tmux
   vim-enhanced
   tar
   systemd-resolved

   # Paquetes y componentes gráficos o innecesarios a excluir
   -cockpit
   -firewalld-config-workstation
   -initial-setup
   -plymouth
   -iwl*firmware
   %end


Sección de Post-instalación (%post)
-----------------------------------
La sección ``%post`` ejecuta scripts dentro del entorno del nuevo sistema operativo antes de reiniciar. Es fundamental especificar la bandera ``--log=/root/ks-post.log`` para capturar cualquier fallo de ejecución:

.. code:: kickstart

   %post --log=/root/ks-post.log
   set -euxo pipefail

   echo "=== Iniciando personalización y endurecimiento post-instalación ==="

   # 1. Configuración de endurecimiento para el servicio OpenSSH
   cat << 'EOF' > /etc/ssh/sshd_config.d/01-hardening.conf
   PermitRootLogin no
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   X11Forwarding no
   MaxAuthTries 3
   ClientAliveInterval 300
   ClientAliveCountMax 2
   EOF
   chmod 0600 /etc/ssh/sshd_config.d/01-hardening.conf

   # 2. Configuración de permisos estrictos para el usuario administrador
   mkdir -p /home/sysadmin/.ssh
   chmod 0700 /home/sysadmin/.ssh
   chown -R sysadmin:sysadmin /home/sysadmin/.ssh

   # 3. Importación obligatoria de llaves GPG de repositorios oficiales
   rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY*

   # 4. Habilitación de servicios esenciales del sistema
   systemctl enable sshd.service
   systemctl enable systemd-timesyncd.service || systemctl enable chronyd.service

   # 5. Registro de finalización en bitácora
   echo "=== Aprovisionamiento Kickstart completado con éxito: $(date --iso-8601=seconds) ==="
   %end


Validación de Sintaxis con ksvalidator
======================================
Antes de publicar o desplegar cualquier archivo Kickstart, es obligatorio validar su consistencia sintáctica mediante ``ksvalidator``. La herramienta detecta parámetros obsoletos, faltantes o incompatibles con la versión de destino:

.. code:: bash

   # Validar archivo para CentOS Stream 10 (perfil RHEL10)
   ksvalidator -v RHEL10 /srv/www/kickstart/ks-centos10.cfg

   # Validar archivo para Fedora 44 (perfil F44)
   ksvalidator -v F44 /srv/www/kickstart/ks-fedora44.cfg

   # Validación genérica con la versión más reciente del sistema local
   ksvalidator /srv/www/kickstart/ks.cfg

Si el comando no produce ninguna salida en la consola y retorna código de salida ``0``, la sintaxis es válida y está lista para producción.


Servidor HTTP para Distribución de Kickstart
============================================
El servidor HTTP entrega los archivos Kickstart y, opcionalmente, los binarios del kernel e initrd. Se utiliza Caddy por su simplicidad y bajo consumo de recursos, o Nginx como estándar industrial.

Rutas del sistema de archivos estandarizadas:

.. code:: bash

   # Crear estructura de directorios bajo FHS (/srv/www/)
   mkdir -p /srv/www/kickstart

   # Copiar el archivo Kickstart validado
   cp ks-centos10.cfg /srv/www/kickstart/ks.cfg
   chmod 0644 /srv/www/kickstart/ks.cfg

Configuración de Caddy (``/etc/caddy/Caddyfile``):

.. code:: text

   :80 {
      root * /srv/www/kickstart
      file_server
      log {
         output file /var/log/caddy/kickstart_access.log
      }
   }


Habilitación e Inicio de Servicios
----------------------------------
Habilitar e iniciar atómicamente el servicio HTTP seleccionado:

.. code:: bash

   # Iniciar y habilitar Caddy
   systemctl enable --now caddy.service

   # En caso de utilizar Nginx en lugar de Caddy:
   # systemctl enable --now nginx.service


Configuración de Cortafuegos y Red
----------------------------------
Para cumplir con la postura estricta de seguridad SELinux Enforcing y habilitar el tráfico de red:

.. code:: bash

   # Asignar el contexto de SELinux para archivos servidos por HTTP
   semanage fcontext -a -t httpd_sys_content_t "/srv/www/kickstart(/.*)?"
   restorecon -Rv /srv/www/kickstart

   # Permitir tráfico HTTP en la zona activa de firewalld
   firewall-cmd --permanent --add-service=http
   firewall-cmd --reload


Cadena de Arranque iPXE
=======================
iPXE reemplaza el lento proceso de descarga TFTP tradicional cargando directamente el kernel Linux (``vmlinuz``) y la imagen ramdisk inicial (``initrd.img``) a través de conexiones TCP/HTTP.


Configuración del Script iPXE
-----------------------------
De acuerdo con las especificaciones del estándar iPXE (consultar `/home/renich/Documents/reference/ipxe.rst`), el script debe comenzar con la cabecera mágica ``#!ipxe`` y gestionar adecuadamente la negociación del enlace y la adquisición de la concesión DHCP:

.. code:: ipxe

   #!ipxe
   # ==============================================================================
   # Script de arranque iPXE para aprovisionamiento desatendido (Kickstart/HTTP)
   # ==============================================================================

   # Inicializar la interfaz de red física y esperar el enlace portador
   ifopen net0
   iflinkwait --timeout 5000 net0 || goto link_failed

   # Solicitar configuración de red por DHCP
   dhcp net0 || goto dhcp_failed

   # Definir orígenes de instalación y ubicación del Kickstart
   set mirror http://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os
   set ks_url http://kickstart.internal/ks.cfg

   # Cargar el kernel e initrd con parámetros de automatización de Anaconda
   echo Descargando kernel de instalacion de CentOS Stream 10...
   kernel ${mirror}/images/pxeboot/vmlinuz inst.ks=${ks_url} inst.stage2=${mirror} ip=dhcp quiet
   initrd ${mirror}/images/pxeboot/initrd.img

   echo Iniciando ejecucion del instalador Anaconda...
   boot || goto boot_failed

   :link_failed
   echo [ERROR] No se detecto enlace de red en la interfaz net0.
   shell

   :dhcp_failed
   echo [ERROR] No se pudo obtener concesion DHCP en net0.
   shell

   :boot_failed
   echo [ERROR] Fallo critico durante la ejecucion de boot.
   shell


Parámetros del Kernel para Anaconda
-----------------------------------
Los parámetros pasados en la línea de comando del kernel configuran la fase de inicialización de Dracut y Anaconda:

* ``inst.ks=http://kickstart.internal/ks.cfg``: Especifica la ubicación HTTP/HTTPS o NFS del archivo de configuración Kickstart.
* ``inst.stage2=http://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/``: Ubicación de la imagen del sistema de instalación (``install.img``). Al proporcionarlo explícitamente, se previene la búsqueda interactiva de medios por parte de Anaconda.
* ``ip=dhcp``: Ordena a Dracut configurar automáticamente la interfaz de red primaria mediante DHCP antes de intentar descargar el archivo Kickstart.
* ``quiet``: Reduce la verbosidad de mensajes del kernel durante el arranque de red.


Verificación y Pruebas
======================
Para comprobar la cadena completa de aprovisionamiento de forma segura y reproducible, se utiliza una máquina virtual KVM gestionada con ``virt-install``.


Despliegue de Prueba con virt-install en KVM
--------------------------------------------
El siguiente comando inicia una máquina virtual de prueba que recupera el kernel e initrd oficiales directamente del repositorio y aplica el archivo Kickstart alojado en el servidor HTTP local:

.. code:: bash

   virt-install \
      --name vm-kickstart-centos10 \
      --memory 4096 \
      --vcpus 2 \
      --disk size=25,bus=virtio,format=qcow2 \
      --network network=default,model=virtio \
      --os-variant centos-stream9 \
      --location https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/ \
      --extra-args "inst.ks=http://192.168.122.1/ks.cfg console=ttyS0,115200n8" \
      --graphics none \
      --noautoconsole

Para probar el arranque nativo a través de iPXE por red:

.. code:: bash

   virt-install \
      --name vm-ipxe-test \
      --memory 4096 \
      --vcpus 2 \
      --disk size=25,bus=virtio,format=qcow2 \
      --network network=default,model=virtio \
      --os-variant centos-stream9 \
      --pxe \
      --boot network,hd \
      --graphics none \
      --noautoconsole


Auditoría de Bitácoras del Instalador
-------------------------------------
Al completar la instalación (o si se produce una interrupción), las bitácoras generadas por Anaconda permiten verificar con precisión forense cada fase del despliegue:

#. **Bitácora de post-instalación**:

   .. code:: bash

      # Verificar la correcta ejecución del script %post
      cat /root/ks-post.log

#. **Bitácoras internas de Anaconda (en /var/log/anaconda/)**:

   * ``/var/log/anaconda/anaconda.log``: Registro cronológico de eventos generales y excepciones del instalador.
   * ``/var/log/anaconda/storage.log``: Detección detallada de dispositivos de almacenamiento, creación de tablas de particiones y volúmenes LVM.
   * ``/var/log/anaconda/program.log``: Salida de comandos ejecutados en el entorno chroot durante la instalación.
   * ``/var/log/anaconda/packaging.log``: Registro de transacciones de paquetes RPM procesadas por el motor DNF integrado.
   * ``/var/log/anaconda/journal.log``: Mensajes completos del systemd-journald durante la fase de instalación en RAM.


Problemática
============

Errores de particionado y detención interactiva de Anaconda
-----------------------------------------------------------
Si el archivo Kickstart omite directivas de almacenamiento o contiene definiciones de tamaño que exceden la capacidad física del disco, Anaconda detiene el flujo desatendido y presenta una consola interactiva solicitando intervención manual.

Para garantizar la desatención completa:

* Incluir siempre ``zerombr`` y ``clearpart --all --initlabel`` para reinicializar discos existentes.
* En plataformas UEFI modernas, incluir obligatoriamente ``reqpart --add-boot`` o declarar la partición EFI de forma explícita:

  .. code:: kickstart

     part /boot/efi --fstype="efi" --size=600 --fsoptions="umask=0077,shortname=winnt"


Discrepancias en nombres de interfaces de red
---------------------------------------------
Debido a la especificación de nombres predecibles (*Predictable Network Interface Names*), la interfaz activa puede nombrarse ``enp1s0``, ``ens3``, ``eno1`` o ``eth0`` según el tipo de hipervisor (KVM, VMware) o hardware bare-metal.

Si se asignan directivas como ``network --device=eth0`` y el sistema operativo asigna ``enp1s0``, la red fallará.

Para mitigar discrepancias:

* En la línea de comandos del kernel iPXE, declarar genéricamente ``ip=dhcp``.
* En Kickstart, omitir el parámetro ``--device`` específico o activar la interfaz primaria conectada:

  .. code:: kickstart

     network --bootproto=dhcp --ipv6=auto --activate --onboot=yes


Ambigüedad en identificadores de disco (/dev/sda vs /dev/nvme0n1)
-----------------------------------------------------------------
En servidores con múltiples controladores de almacenamiento (por ejemplo, unidades NVMe para el sistema operativo y discos SAS/SATA para almacenamiento masivo), el orden de enumeración del kernel de Linux no es determinista entre reinicios. Un archivo que asigne particiones a ``/dev/sda`` podría sobrescribir accidentalmente un arreglo de almacenamiento de datos o fallar si el disco del sistema es ``/dev/nvme0n1`` o ``/dev/vda`` (en KVM).

Solución: Especificar el disco mediante su ruta de bus persistente o filtrar los discos utilizables con ``ignoredisk``:

.. code:: kickstart

   # Ignorar todos los discos excepto el dispositivo del sistema
   ignoredisk --only-use=/dev/disk/by-path/pci-0000:00:1f.2-ata-1.0


Bloqueos por SELinux (Permission Denied)
----------------------------------------
Si el cliente de red recibe un código HTTP 403 Forbidden al intentar descargar ``ks.cfg`` desde el servidor web, el contexto de seguridad SELinux en el servidor de archivos está desajustado:

.. code:: bash

   # Inspeccionar denegaciones recientes en la bitácora de auditoría
   ausearch -m avc -ts recent

   # Corregir el contexto de forma permanente para el servidor web
   semanage fcontext -a -t httpd_sys_content_t "/srv/www/kickstart(/.*)?"
   restorecon -Rv /srv/www/kickstart


Falla de resolución de red o cortafuegos
----------------------------------------
Si el instalador se queda detenido intentando descargar el archivo Kickstart y genera un error de tiempo de espera (*timeout*):

#. Verificar que el puerto HTTP esté abierto en el servidor de aprovisionamiento:

   .. code:: bash

      firewall-cmd --list-all

#. Probar la descarga directa desde otro equipo o desde el shell de depuración de Anaconda (disponible presionando ``Ctrl+Alt+F2`` o ``Ctrl+Alt+F3``):

   .. code:: bash

      curl -I http://kickstart.internal/ks.cfg


Referencias
===========
* Red Hat Enterprise Linux 10: Performing an Advanced RHEL Installation: https://docs.redhat.com/es/documentation/red_hat_enterprise_linux/10/html/performing_an_advanced_rhel_10_installation/
* Fedora Documentation: Kickstart Syntax Reference: https://docs.fedoraproject.org/en-US/fedora/latest/install-guide/appendixes/Kickstart_Syntax_Reference/
* Documentación oficial de CentOS Stream: https://www.centos.org/centos-stream/
* Documentación upstream de Pykickstart: https://pykickstart.readthedocs.io/
* Documentación upstream del proyecto iPXE: https://ipxe.org/
* Referencia de arquitectura del instalador Anaconda: https://rhinstaller.github.io/anaconda/
