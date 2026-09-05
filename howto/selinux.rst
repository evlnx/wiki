================================================================
SELinux en Modo Enforcing y Creación de Políticas Personalizadas
================================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
Security-Enhanced Linux (SELinux) es una arquitectura de control de acceso obligatorio (MAC, *Mandatory Access Control*) implementada en el núcleo Linux mediante el marco de módulos de seguridad LSM (*Linux Security Module*). A diferencia del esquema tradicional de control de acceso discrecional (DAC, *Discretionary Access Control*), donde los permisos se rigen exclusivamente por el propietario y grupo de un archivo (lectura, escritura y ejecución para usuario/grupo/otros), SELinux evalúa y restringe cada operación del sistema basándose en una política de seguridad integral y centralizada.

Bajo DAC, si un proceso ejecutado como superusuario (``root``) o un servicio comprometido sufre una vulnerabilidad de ejecución remota de código, el atacante hereda inmediatamente privilegios absolutos sobre el sistema. En contraste, bajo SELinux en modo **Enforcing**, todo sujeto (proceso) y todo objeto (archivo, directorio, socket de red, puerto TCP/UDP, tubería IPC o descriptor de archivo) posee asignado un contexto de seguridad inmutable. Incluso si un proceso se ejecuta con UID 0 (``root``), sus acciones quedan estrictamente confinadas al dominio correspondiente (por ejemplo, ``httpd_t`` para servidores web). Si el proceso intenta leer archivos de usuarios fuera de su contexto, enlazar un puerto no autorizado o interactuar con otros daemons, la operación es bloqueada a nivel de kernel y registrada en el subsistema de auditoría.

El modo **Enforcing** opera bajo el principio fundamental de **denegación por defecto** (*default-deny*): cualquier acceso, transición o llamada al sistema que no esté explícitamente permitida en la política activa es inmediatamente denegada. Esto garantiza:

* **Mitigación de vulnerabilidades de día cero (*zero-day*)**: Impide el movimiento lateral y la escalada de privilegios tras una intrusión en servicios expuestos a la red.
* **Aislamiento de procesos y contenedores**: Proporciona contención multinivel mediante Multi-Category Security (MCS) y dominios especializados.
* **Integridad del sistema y trazabilidad forense**: Cada intento no autorizado genera registros de auditoría no repudiables (eventos AVC).

En **CentOS Stream 10** y **Fedora 44**, SELinux incorpora la versión moderna del espacio de usuario (SELinux userspace 3.8 a 3.11). Se ha eliminado la capacidad de deshabilitar SELinux en caliente en tiempo de ejecución (la llamada ``security_disable(3)`` está obsoleta y deshabilitada en núcleos modernos); cualquier desactivación total requiere parámetros de arranque del kernel (``selinux=0``). Asimismo, la gestión de políticas se apoya de forma nativa en el lenguaje intermedio CIL (*Common Intermediate Language*), acelerando la compilación y validación atómica del almacén de políticas.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Privilegios de superusuario en el sistema (acceso administrativo mediante ``sudo``).
* Políticas base de SELinux instaladas y activas (paquete ``selinux-policy-targeted``).
* Conectividad a los repositorios oficiales de la distribución para la instalación de herramientas de auditoría y desarrollo.


Instalación
===========
Para auditar eventos de denegación, administrar contextos persistentes, inspeccionar atributos y compilar módulos de políticas personalizadas, instale los paquetes de soporte del espacio de usuario mediante ``dnf``:

.. code:: bash

   # Actualizar metadatos e instalar herramientas de administración y compilación
   sudo dnf -y install \
      policycoreutils \
      policycoreutils-python-utils \
      setroubleshoot-server \
      audit \
      selinux-policy-devel \
      setools-console

Los paquetes proporcionan los siguientes componentes críticos:

* ``policycoreutils``: Binarios esenciales para la aplicación de etiquetas y control del sistema (``sestatus``, ``getenforce``, ``setenforce``, ``restorecon``, ``semodule``).
* ``policycoreutils-python-utils``: Herramientas avanzadas de administración de políticas y generación de reglas (``semanage``, ``audit2allow``, ``audit2why``).
* ``setroubleshoot-server``: Servidor de diagnóstico asistido y herramienta de análisis automatizado ``sealert``.
* ``audit``: Demonio del sistema de auditoría del kernel (``auditd``) y utilidades de consulta (``ausearch``, ``aureport``).
* ``selinux-policy-devel``: Entorno de macros M4, Makefiles y encabezados para la compilación de módulos Type Enforcement (``.te``).
* ``setools-console``: Herramientas de análisis e inspección de políticas activas en memoria (``seinfo``, ``sesearch``).


Configuración
=============

Verificación del Modo Operativo
-------------------------------
SELinux dispone de tres modos operativos:

* **Enforcing**: Modo predeterminado de producción. Las políticas de seguridad se aplican estrictamente; las operaciones no autorizadas se bloquean y se registran en la bitácora de auditoría.
* **Permissive**: Las políticas no bloquean las operaciones denegadas, pero cada infracción se registra como una advertencia AVC en la bitácora. Es idóneo para depuración y calibración sin degradar la disponibilidad del servicio.
* **Disabled**: La infraestructura de SELinux y los hooks LSM no cargan política alguna.

Para verificar el modo de operación activo en tiempo de ejecución:

.. code:: bash

   # Consultar el estado operativo inmediato
   getenforce

Para obtener un desglose completo de la configuración actual, versión de política y montajes:

.. code:: bash

   # Inspección detallada del estado de SELinux
   sestatus

El resultado refleja el modo actual, el modo configurado en disco y el perfil cargado:

.. code:: text

   SELinux status:                 enabled
   SELinuxfs mount:                /sys/fs/selinux
   SELinux root directory:         /etc/selinux
   Loaded policy name:             targeted
   Current mode:                   enforcing
   Mode from config file:          enforcing
   Policy MLS status:              enabled
   Policy deny_unknown status:     allowed
   Memory protection checking:     actual (secure)
   Max kernel policy version:      35

Si necesita alternar temporalmente al modo permisivo para pruebas de diagnóstico, ejecute:

.. code:: bash

   # Cambiar temporalmente a modo permisivo
   sudo setenforce 0

   # Restaurar de inmediato el modo Enforcing
   sudo setenforce 1

Para asegurar que el sistema siempre inicie en modo Enforcing de forma persistente, verifique el archivo ``/etc/selinux/config``:

.. code:: ini

   # Archivo: /etc/selinux/config
   SELINUX=enforcing
   SELINUXTYPE=targeted

.. note::

   En distribuciones modernas como CentOS Stream 10 y Fedora 44, nunca modifique ``SELINUX=disabled`` en ``/etc/selinux/config``. Si requiere desactivar totalmente SELinux a nivel de kernel, debe modificar los parámetros de arranque mediante ``grubby`` pasando el argumento ``selinux=0``.


Auditoría y Diagnóstico de Denegaciones AVC
-------------------------------------------
Cuando el kernel bloquea una acción no contemplada por la política, genera un mensaje AVC (*Access Vector Cache*) en ``/var/log/audit/audit.log`` (o en el diario de ``systemd-journald`` si ``auditd`` no estuviera activo).

Estructura de un registro AVC típico:

.. code:: text

   type=AVC msg=audit(1725300000.123:456): avc:  denied  { write } for  pid=1420 comm="httpd" name="uploads" dev="nvme0n1p3" ino=789012 scontext=system_u:system_r:httpd_t:s0 tcontext=unconfined_u:object_r:httpd_sys_content_t:s0 tclass=dir permissive=0

Desglose técnico de campos:

* ``type=AVC``: Identifica el registro como un evento del Access Vector Cache.
* ``msg=audit(1725300000.123:456)``: Marca de tiempo en segundos UNIX con milisegundos y número de secuencia del evento.
* ``denied { write }``: Permiso o vector de acceso que fue rechazado.
* ``pid=1420``: Identificador del proceso que originó la petición.
* ``comm="httpd"``: Nombre del ejecutable del proceso.
* ``name="uploads"``: Nombre del objeto (archivo, directorio o recurso) involucrado.
* ``scontext=system_u:system_r:httpd_t:s0``: Contexto de seguridad del sujeto (usuario:rol:tipo:nivel).
* ``tcontext=unconfined_u:object_r:httpd_sys_content_t:s0``: Contexto de seguridad del objeto de destino.
* ``tclass=dir``: Clase de seguridad del recurso (``dir``, ``file``, ``tcp_socket``, etc.).
* ``permissive=0``: Indica que la operación fue bloqueada (un valor de ``1`` indica que el sistema está en modo permisivo y la acción se consumó).

Para consultar denegaciones recientes con ``ausearch``:

.. code:: bash

   # Buscar denegaciones de los últimos 10 minutos
   sudo ausearch -m avc -ts recent

   # Consultar denegaciones del día de hoy traduciendo UIDs a nombres legibles (-i)
   sudo ausearch -m avc,user_avc,selinux_err -ts today -i

   # Filtrar denegaciones asociadas a un proceso específico
   sudo ausearch -m avc -c httpd -ts today

Para interpretar automáticamente la causa raíz de una denegación y conocer si puede resolverse mediante etiquetas o un booleano preexistente, canalice la salida a ``audit2why``:

.. code:: bash

   # Analizar causas raíz de denegaciones recientes
   sudo ausearch -m avc -ts recent | audit2why

Para obtener un informe forense integral generado por el motor de reglas de ``setroubleshoot``:

.. code:: bash

   # Generar reporte analítico de toda la bitácora de auditoría
   sudo sealert -a /var/log/audit/audit.log


Gestión de Contextos de Archivos Persistentes
---------------------------------------------
Cada elemento en el sistema de archivos posee un contexto de seguridad almacenado en los atributos extendidos del inodo (``security.selinux``) con el formato:

.. code:: text

   usuario:rol:tipo:nivel

El campo más crítico en la política ``targeted`` es el **tipo** (por ejemplo, ``httpd_sys_content_t``).

.. warning::

   Nunca utilice ``chcon`` para corregir problemas de permisos en producción. ``chcon`` únicamente altera el atributo extendido en el inodo pero no actualiza la base de datos de políticas del sistema. Ante cualquier reetiquetado del sistema (como una actualización de paquetes o ejecución de ``restorecon``), las modificaciones hechas con ``chcon`` se perderán.

Para establecer contextos persistentes que sobrevivan a cualquier reetiquetado, registre las reglas en la base de datos de SELinux con ``semanage fcontext`` y aplíquelas al sistema de archivos con ``restorecon``.

Por ejemplo, para alojar un sitio web o aplicación en la ruta no estándar ``/srv/www/custom``:

.. code:: bash

   # 1. Crear el árbol de directorios
   sudo mkdir -p /srv/www/custom/uploads

   # 2. Registrar regla persistente de solo lectura para el contenido web general
   sudo semanage fcontext -a -t httpd_sys_content_t "/srv/www/custom(/.*)?"

   # 3. Registrar regla persistente de lectura/escritura para el directorio de subidas
   sudo semanage fcontext -a -t httpd_sys_rw_content_t "/srv/www/custom/uploads(/.*)?"

   # 4. Simular la aplicación de etiquetas en modo de prueba (dry-run)
   restorecon -v -n -R /srv/www/custom

   # 5. Aplicar recursivamente los nuevos contextos a disco
   sudo restorecon -Rv /srv/www/custom

   # 6. Listar las reglas de contexto personalizadas registradas localmente
   sudo semanage fcontext -l -C

Para eliminar una regla personalizada registrada previamente:

.. code:: bash

   # Eliminar la definición persistente
   sudo semanage fcontext -d "/srv/www/custom(/.*)?"


Control Persistente de Boleanos
-------------------------------
Los booleanos de SELinux son conmutadores de configuración binarios (*on*/*off*) integrados en la política que permiten modificar el comportamiento y las concesiones de acceso en tiempo de ejecución sin necesidad de recompilar políticas.

Para consultar el estado de los booleanos:

.. code:: bash

   # Consultar el estado de un booleano específico
   getsebool httpd_can_network_connect

   # Listar todos los booleanos relacionados con servicios web
   getsebool -a | grep -E '^httpd_'

   # Consultar la descripción técnica y propósito de un booleano
   semanage boolean -l | grep httpd_can_network_connect

Para activar un booleano de forma persistente a través de reinicios del sistema, emplee la bandera ``-P`` de ``setsebool``:

.. code:: bash

   # Permitir que el servidor web establezca conexiones salientes por red (ej. proxy inverso)
   sudo setsebool -P httpd_can_network_connect on

   # Permitir que el servidor web se conecte a servidores de bases de datos por red
   sudo setsebool -P httpd_can_network_connect_db on

Para auditar qué booleanos han sido modificados localmente respecto a los valores predeterminados de la distribución:

.. code:: bash

   # Listar modificaciones locales de booleanos
   sudo semanage boolean -l -C

Para restablecer un booleano a su valor predeterminado original:

.. code:: bash

   # Restaurar valor predeterminado del sistema
   sudo semanage boolean -d httpd_can_network_connect


Creación y Compilación de Módulos de Políticas Personalizadas
-------------------------------------------------------------
Cuando un servicio legítimo o aplicación personalizada requiere accesos que no están cubiertos por los booleanos existentes ni por los tipos estándar de archivos, es necesario crear e instalar un módulo de política personalizado.

Existen tres métodos de trabajo para compilar e instalar módulos:

Flujo 1: Escritura manual de Type Enforcement (``.te``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Este método garantiza un control granular y auditabilidad del código de la política.

#. Redactar el archivo fuente de la política Type Enforcement ``/root/customapp.te`` declarando el módulo, tipos requeridos y reglas de autorización:

   .. code:: text

      module customapp 1.0;

      require {
         type httpd_t;
         type var_log_t;
         class file { open read getattr };
      }

      # Permitir que el proceso web lea archivos de bitacora del sistema
      allow httpd_t var_log_t:file { open read getattr };

#. Compilar el archivo fuente a un módulo binario intermedio (``.mod``) utilizando ``checkmodule``:

   .. code:: bash

      checkmodule -M -m -o /root/customapp.mod /root/customapp.te

   * ``-M``: Habilita el soporte para Multi-Level Security (MLS).
   * ``-m``: Especifica la generación de un módulo de política en lugar de una política base completa.

#. Empaquetar el módulo binario en un paquete de política instalable (``.pp``) mediante ``semodule_package``:

   .. code:: bash

      semodule_package -o /root/customapp.pp -m /root/customapp.mod

#. Instalar el paquete en el almacén de políticas activo del sistema:

   .. code:: bash

      sudo semodule -i /root/customapp.pp

Flujo 2: Generación asistida mediante audit2allow
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Cuando se han capturado eventos de denegación legítimos en la bitácora de auditoría tras ejecutar la aplicación:

.. code:: bash

   # Filtrar los bloqueos recientes del proceso y compilar un paquete de politica
   sudo ausearch -m avc -c customapp -ts recent | audit2allow -M customapp_fix

   # Instalar el paquete generado
   sudo semodule -i customapp_fix.pp

.. caution::

   Inspeccione siempre el archivo ``customapp_fix.te`` generado antes de compilarlo. Nunca genere reglas ciegamente desde la totalidad de la bitácora de auditoría (evite ``audit2allow -a -M``), ya que podría autorizar vectores de ataque si el sistema sufrió intrusiones previas.

Flujo 3: Módulos en formato CIL nativo (Estándar Fedora 44 y CentOS Stream 10)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
SELinux userspace compila internamente todas las políticas a CIL (*Common Intermediate Language*). Puede generar, auditar e instalar políticas CIL directamente sin pasar por herramientas M4 intermedias:

.. code:: bash

   # 1. Generar módulo CIL directamente desde los bloqueos del proceso
   sudo ausearch -m avc -c customapp -ts recent | audit2allow -C > /root/customapp.cil

   # 2. Inspeccionar el contenido en sintaxis de S-expressions
   cat /root/customapp.cil

   # 3. Validar el modulo contra las reglas 'neverallow' del sistema con secilcheck
   secilcheck /sys/fs/selinux/policy /root/customapp.cil

   # 4. Instalar el modulo CIL con prioridad 400 en el almacen de politicas
   sudo semodule -X 400 -i /root/customapp.cil


Habilitación e Inicio de Servicios
----------------------------------
Para garantizar la recolección continua de eventos de seguridad y el diagnóstico automático de denegaciones, los servicios del subsistema de auditoría y diagnóstico deben estar activos y habilitados.

.. code:: bash

   # Habilitar e iniciar inmediatamente el demonio de auditoria del kernel
   sudo systemctl enable --now auditd.service

   # Habilitar e iniciar el servicio de diagnostico automatizado setroubleshoot
   sudo systemctl enable --now setroubleshootd.service

.. note::

   ``auditd.service`` es un servicio de infraestructura crítica del kernel gestionado de forma especializada por ``systemd``. Si realiza cambios en las reglas de auditoría en ``/etc/audit/rules.d/``, nunca ejecute ``systemctl restart auditd``; utilice en su lugar ``sudo augenrules --load`` o ``sudo service auditd restart``.

Si el entorno requiere monitoreo y restauración dinámica de contextos de archivos ante modificaciones en rutas críticas del sistema (como ``/etc/resolv.conf`` o claves de usuario), habilite opcionalmente el demonio ``restorecond``:

.. code:: bash

   # Habilitar e iniciar el demonio de monitoreo continuo de etiquetas
   sudo systemctl enable --now restorecond.service


Verificación y Pruebas
======================

Inspección de Módulos Activos
-----------------------------
Para verificar qué módulos de políticas están cargados en el almacén del kernel, su prioridad y su suma criptográfica SHA256:

.. code:: bash

   # Listar modulos instalados localmente con prioridad y estado
   sudo semodule -lfull | grep 400

   # Verificar un modulo especifico incluyendo su suma de verificacion SHA256
   sudo semodule -lfull -m | grep customapp

Para extraer la representación CIL de un módulo previamente instalado en el sistema:

.. code:: bash

   # Extraer la definicion CIL activa de un modulo
   semodule -E customapp -c


Pruebas de Acceso en Modo Permissive vs Enforcing
-------------------------------------------------
Una de las mejores prácticas para depurar aplicaciones sin comprometer la seguridad global del servidor consiste en colocar **únicamente el dominio problemático** en modo permisivo, manteniendo todo el resto del sistema en modo Enforcing estricto.

#. Colocar el dominio de la aplicación en modo permisivo:

   .. code:: bash

      sudo semanage permissive -a httpd_t

#. Verificar que el dominio figure en la lista de dominios permisivos:

   .. code:: bash

      sudo semanage permissive -l

#. Ejecutar las operaciones de la aplicación o pruebas de estrés. En este estado, el kernel permitirá el acceso y registrará cada violación en la bitácora de auditoría con la bandera ``permissive=1``:

   .. code:: bash

      sudo ausearch -m avc -c httpd -ts recent

#. Una vez analizadas las denegaciones y aplicadas las soluciones correspondientes (etiquetas, booleanos o módulos CIL), retire el dominio del modo permisivo para retornar a la confinación estricta:

   .. code:: bash

      sudo semanage permissive -d httpd_t

#. Realizar la prueba funcional final con el dominio en modo Enforcing y verificar que la operación se complete satisfactoriamente sin generar nuevos registros AVC:

   .. code:: bash

      sudo ausearch -m avc -c httpd -ts recent


Validación del Reetiquetado de Archivos
---------------------------------------
Para comprobar que los contextos de archivos y directorios coinciden con las especificaciones de la política:

.. code:: bash

   # 1. Comprobar etiquetas en el sistema de archivos
   ls -laZ /srv/www/custom

   # 2. Ejecutar prueba de consistencia con restorecon (modo dry-run informativo)
   restorecon -v -n -R /srv/www/custom

Si el comando no genera ninguna salida, los contextos de los archivos en disco concuerdan de forma exacta con las políticas persistentes registradas en el sistema.


Problemática
============

Reetiquetado Completo del Sistema de Archivos
---------------------------------------------
Si un sistema fue instalado o ejecutado previamente con SELinux desactivado (``selinux=0``), o si se restauraron respaldos de archivos que no preservaron los atributos extendidos ``security.selinux``, gran parte de los archivos del sistema de archivos carecerán de etiquetas válidas. Al reactivar el modo Enforcing, los servicios fallarán en cascada durante el arranque debido a contextos desconocidos (``unlabeled_t``).

Para solucionar esta condición, se debe programar un reetiquetado completo del sistema de archivos (*autorelabel*):

.. code:: bash

   # Metodo estandar: Crear el archivo testigo autorelabel en la raiz del sistema
   sudo touch /.autorelabel

   # Reiniciar el sistema para ejecutar el proceso en el arranque temprano
   sudo reboot

Durante el proceso de arranque, la unidad ``selinux-autorelabel.service`` de ``systemd`` intercepta la inicialización, monta los sistemas de archivos, ejecuta ``setfiles`` recorriendo recursivamente todo el almacenamiento para restaurar las etiquetas correctas de acuerdo con la política targeted, elimina el archivo ``/.autorelabel`` y reinicia automáticamente la máquina.

Alternativamente, en CentOS Stream 10 y Fedora 44 puede utilizar la herramienta ``fixfiles``:

.. code:: bash

   # Programar el reetiquetado forzado para el siguiente reinicio
   sudo fixfiles -F onboot
   sudo reboot


Problemas de Enlace de Puertos de Red
-------------------------------------
Por omisión, los servicios de red confinados bajo SELinux únicamente tienen autorización para abrir y escuchar en los puertos TCP/UDP definidos en la política base para su dominio (por ejemplo, ``httpd_t`` solo puede enlazar los puertos etiquetados bajo ``http_port_t``, tales como 80, 443, 8080, 8443).

Si configura un servidor web (Apache, Nginx, o un proxy inverso) para escuchar en un puerto no estándar como TCP 8085, el servicio fallará al iniciar con el siguiente error en las bitácoras:

.. code:: text

   [emerg] 1234#1234: bind() to 0.0.0.0:8085 failed (13: Permission denied)

Al consultar la auditoría, encontrará una denegación AVC indicando el vector ``name_bind``:

.. code:: bash

   # Inspeccionar la denegacion de puerto
   sudo ausearch -m avc -ts recent | grep name_bind

El registro mostrará que ``httpd_t`` intentó enlazar a un puerto no autorizado para su clase:

.. code:: text

   type=AVC msg=audit(...): avc: denied { name_bind } for pid=1234 comm="nginx" src=8085 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

Para resolver esta incidencia sin relajar la seguridad global:

.. code:: bash

   # 1. Comprobar que puertos estan asignados al tipo http_port_t
   semanage port -l | grep http_port_t

   # 2. Asignar el puerto TCP 8085 al tipo http_port_t de forma persistente
   sudo semanage port -a -t http_port_t -p tcp 8085

   # 3. Si el puerto ya existia bajo otro tipo, modificar la asignacion con la bandera -m
   # sudo semanage port -m -t http_port_t -p tcp 8085

   # 4. Listar las modificaciones locales de puertos
   sudo semanage port -l -C

   # 5. Iniciar el servicio web
   sudo systemctl restart nginx.service


Trampas Comunes de Denegaciones AVC
-----------------------------------

Mover archivos con mv versus copiar con cp
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Una de las trampas más frecuentes al administrar sistemas ocurre al preparar archivos en un directorio temporal (como ``/tmp`` con tipo ``tmp_t`` o el directorio del usuario con tipo ``user_home_t``) y trasladarlos con el comando ``mv`` al directorio productivo (como ``/var/www/html``).

El comando ``mv`` **preserva el inodo original y sus atributos extendidos**, manteniendo la etiqueta de origen (``user_home_t``). Como consecuencia, el servidor web no podrá leer el archivo y responderá con un error HTTP 403 Forbidden, aun cuando los permisos DAC sean ``chmod 644``.

En contraste, el comando ``cp`` crea un inodo nuevo en el destino y **hereda automáticamente el contexto de seguridad del directorio receptor** (``httpd_sys_content_t``).

Para corregir los archivos trasladados con ``mv``:

.. code:: bash

   # Restaurar el contexto correcto segun la politica activa
   sudo restorecon -Rv /var/www/html

Reglas dontaudit que silencian bloqueos
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Para evitar saturar la bitácora de auditoría con eventos irrelevantes que no afectan el funcionamiento normal de las aplicaciones, la política de SELinux incluye directivas ``dontaudit``. Estas directivas impiden que ciertas denegaciones se registren en ``/var/log/audit/audit.log``.

Si un servicio falla y sospecha de SELinux pero ``ausearch -m avc -ts recent`` no reporta ningún evento, desactive temporalmente la supresión de auditoría:

.. code:: bash

   # 1. Desactivar las reglas dontaudit para exponer todos los bloqueos
   sudo semanage dontaudit off

   # 2. Reproducir la accion fallida en el servicio
   # 3. Buscar los bloqueos que anteriormente estaban ocultos
   sudo ausearch -m avc -ts recent

   # 4. Reactivar inmediatamente las reglas dontaudit
   sudo semanage dontaudit on

Interacción de permisos DAC y MAC
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
SELinux no reemplaza los permisos tradicionales de Linux (*Discretionary Access Control*), sino que actúa como una capa adicional de protección. El núcleo evalúa primero los permisos DAC (usuario, grupo y modo de permisos del sistema de archivos o ACLs). Si las reglas DAC rechazan la petición (por ejemplo, si el archivo tiene permisos ``chmod 000`` o el usuario del proceso no tiene acceso de lectura), el núcleo interrumpe la operación de inmediato y **nunca consulta al subsistema SELinux**.

Por lo tanto, ante un error de ``Permission denied`` donde no exista registro alguno en ``ausearch`` incluso con ``dontaudit off``, revise minuciosamente la propiedad y permisos estándar de usuario/grupo mediante ``ls -la``.

Uso indiscriminado de audit2allow
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
La herramienta ``audit2allow`` es un generador sintáctico que traduce directamente registros de denegación en sentencias ``allow``. No posee criterio para discernir si un acceso es legítimo o representa una intrusión en curso.

Si un servidor web atacado intenta leer ``/etc/shadow`` o ejecutar utilidades administrativas y el administrador ejecuta ``audit2allow -a -M compromiso``, se creará una política que legalizará la intrusión. Antes de autorizar una denegación con un módulo personalizado, verifique siempre:

#. Si el recurso tiene asignada la etiqueta de tipo adecuada.
#. Si existe un booleano preexistente diseñado específicamente para ese caso de uso.
#. Si la aplicación realmente requiere ese acceso para su propósito operativo legítimo.


Referencias
===========
* Documentación oficial de Red Hat Enterprise Linux 10: *Managing SELinux*: https://docs.redhat.com/
* Guía de usuario de Fedora: *SELinux Getting Started*: https://docs.fedoraproject.org/en-US/quick-docs/selinux-getting-started/
* Proyecto Oficial SELinux: https://selinuxproject.github.io/
* Documentación técnica *The SELinux Notebook*: https://selinuxproject.github.io/notebook/
* Repositorio del espacio de usuario de SELinux: https://github.com/SELinuxProject/selinux
* Páginas de manual de GNU/Linux: ``semanage(8)``, ``restorecon(8)``, ``audit2allow(1)``, ``audit2why(1)``, ``checkmodule(8)``, ``semodule(8)``, ``sestatus(8)``.
