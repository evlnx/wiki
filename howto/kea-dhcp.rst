===========================================================
Servidor DHCP Moderno: Implementación y Migración a ISC Kea
===========================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
El Internet Systems Consortium (ISC) retiró oficialmente su servidor DHCP tradicional (``dhcpd``), el cual ha sido descontinuado y removido de los repositorios principales a partir de **CentOS Stream 10**, Red Hat Enterprise Linux 10 y **Fedora 44**. Su sucesor arquitectónico es **ISC Kea**, un motor DHCPv4/DHCPv6 modular, extensible y de ultra-alto rendimiento diseñado específicamente para satisfacer las demandas operativas de infraestructuras empresariales modernas y centros de datos.

A diferencia del demonio monolítico clásico, Kea implementa una arquitectura desacoplada basada en procesos independientes (``kea-dhcp4``, ``kea-dhcp6``, ``kea-dhcp-ddns`` y ``kea-ctrl-agent``) con características avanzadas:

* **Configuración declarativa en JSON extendido**: Permite estructuras jerárquicas legibles, inclusión de comentarios de línea (``#`` y ``//``), bloques multilínea e inclusión modular de archivos externos.
* **Procesamiento multi-hilo nativo**: Utiliza colas de paquetes sincronizadas y grupos de subprocesos de trabajo (worker threads) para procesar miles de solicitudes de arrendamiento por segundo.
* **Canal de control y API REST**: Gestión en vivo y reconfiguración sin pérdida de paquetes ni reinicio del servicio a través de sockets UNIX locales o agentes HTTP/REST.
* **Almacenamiento modular de arrendamientos**: Soporte nativo para almacenamiento en memoria ultra-rápido respaldado en disco mediante archivos CSV (Memfile), así como motores transaccionales relacionales empresariales como PostgreSQL y MySQL/MariaDB.
* **Extensibilidad mediante Hooks**: Integración modular con bibliotecas dinámicas para alta disponibilidad (HA con balanceo o failover activo/pasivo), asignación de parámetros por clases de clientes y resolución dinámica de nombres DNS (DDNS).
* **Conformidad de estándares IETF**: Soporte estricto para RFC 2131/2132 (DHCPv4), RFC 8415/RFC 9915 (DHCPv6) y RFC 2136/RFC 4703 (DDNS con registros DHCID).


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Acceso como superusuario (cuenta root).
* Políticas de control de acceso mandatorio **SELinux** en modo ``Enforcing`` activas.
* Al menos dos interfaces de red físicas o virtuales conectadas al servidor:
   * Interfaz de enlace ascendente (WAN/Internet) para gestión y salida general.
   * Interfaz de red local dedicada (LAN), por ejemplo ``eth1`` o ``enp2s0``, conectada al segmento broadcast donde se atenderán las solicitudes de los clientes.
* Dirección IPv4 estática asignada y activa en la interfaz LAN dentro de la subred a servir (por ejemplo: ``192.168.10.1/24``).


Instalación
===========
En CentOS Stream 10 y Fedora 44, el software de Kea y sus utilitarios de control están disponibles directamente desde los repositorios oficiales mediante el gestor de paquetes ``dnf``:

.. code-block:: bash

   # Instalar el servidor Kea DHCPv4/DHCPv6 y el agente de control REST
   dnf -y install kea kea-ctrl-agent

Los paquetes proporcionan los siguientes componentes principales en el árbol del sistema de archivos (FHS):

* ``/usr/sbin/kea-dhcp4``: Binario principal del motor DHCPv4.
* ``/usr/sbin/kea-ctrl-agent``: Demonio del agente de control REST API.
* ``/usr/sbin/kea-admin``: Herramienta administrativa para gestión e inicialización de esquemas de bases de datos.
* ``/etc/kea/``: Directorio estandarizado para los archivos de configuración JSON.
* ``/var/lib/kea/``: Directorio de persistencia para bases de datos de arrendamientos locales (Memfile CSV).
* ``/run/kea/``: Directorio volátil para sockets UNIX de comunicación inter-procesos (IPC).


Configuración
=============
La configuración de Kea se rige por un objeto JSON principal correspondiente al demonio que se desea ejecutar. Para el servicio IPv4, el archivo principal es ``/etc/kea/kea-dhcp4.conf`` y su objeto raíz debe denominarse estrictamente ``"Dhcp4"``.

Estructura y Archivo Principal (/etc/kea/kea-dhcp4.conf)
--------------------------------------------------------
Crea o edita el archivo de configuración con una topología de subred ``192.168.10.0/24``, interfaz de escucha ``eth1``, almacenamiento Memfile CSV y una reservación estática de ejemplo:

.. code-block:: json

   {
      "Dhcp4": {
         "interfaces-config": {
            "interfaces": [ "eth1" ],
            "dhcp-socket-type": "raw"
         },
         "control-sockets": [
            {
               "socket-type": "unix",
               "socket-name": "/run/kea/kea-dhcp4.sock"
            }
         ],
         "lease-database": {
            "type": "memfile",
            "persist": true,
            "name": "/var/lib/kea/kea-leases4.csv",
            "lfc-interval": 3600
         },
         "valid-lifetime": 86400,
         "renew-timer": 43200,
         "rebind-timer": 75600,
         "subnet4": [
            {
               "id": 1,
               "subnet": "192.168.10.0/24",
               "pools": [
                  {
                     "pool": "192.168.10.100 - 192.168.10.200"
                  }
               ],
               "option-data": [
                  {
                     "name": "routers",
                     "data": "192.168.10.1"
                  },
                  {
                     "name": "domain-name-servers",
                     "data": "192.168.10.1, 1.1.1.1"
                  },
                  {
                     "name": "domain-name",
                     "data": "evalinux.lan"
                  }
               ],
               "reservations": [
                  {
                     "hw-address": "52:54:00:12:34:56",
                     "ip-address": "192.168.10.10",
                     "hostname": "srv-app01"
                  }
               ]
            }
         ],
         "loggers": [
            {
               "name": "kea-dhcp4",
               "output_options": [
                  {
                     "output": "stdout"
                  }
               ],
               "severity": "INFO"
            }
         ]
      }
   }

Desglose de Parámetros de Configuración
---------------------------------------

* **interfaces-config**:
   * ``interfaces``: Lista de interfaces de red físicas o VLANs donde Kea escuchará tráfico DHCP.
   * ``dhcp-socket-type``: Establecido en ``raw``. Permite al servidor capturar y responder a paquetes broadcast emitidos por clientes antes de que estos tengan asignada una dirección IP válida en el enlace de red.
* **control-sockets**:
   * Define el socket UNIX local en ``/run/kea/kea-dhcp4.sock``. Permite al agente de control interactuar directamente con el motor DHCP mediante comandos en tiempo de ejecución.
* **lease-database**:
   * ``type``: ``memfile``. Modo predeterminado de alto rendimiento que mantiene los arrendamientos en memoria RAM y los persiste en formato CSV en disco.
   * ``persist``: ``true``. Garantiza que los arrendamientos no se pierdan tras un reinicio del servicio.
   * ``name``: Ruta al archivo CSV (``/var/lib/kea/kea-leases4.csv``).
   * ``lfc-interval``: Intervalo en segundos para la ejecución de la limpieza periódica de registros obsoletos o caducados (Lease File Cleanup).
* **Temporizadores globales**:
   * ``valid-lifetime``: Tiempo de vida total de la concesión en segundos (``86400`` = 24 horas).
   * ``renew-timer``: Temporizador T1 para que el cliente comience la renovación individual vía unicast (``43200`` = 12 horas).
   * ``rebind-timer``: Temporizador T2 para que el cliente intente reasociarse en broadcast si el servidor original no responde (``75600`` = 21 horas).
* **subnet4 y pools**:
   * ``id``: Identificador numérico único de la subred dentro del servidor.
   * ``subnet``: Prefijo de red en notación CIDR (``192.168.10.0/24``).
   * ``pools``: Rangos de direcciones dinámicas asignables a clientes genéricos (de ``192.168.10.100`` a ``192.168.10.200``).
   * ``option-data``: Opciones estándar distribuidas a los clientes: enrutador predeterminado (gateway), servidores DNS y nombre de dominio local.
* **reservations**:
   * Define concesiones estáticas basadas en la dirección MAC del cliente (``hw-address``), asegurando que un equipo reciba invariablemente la misma IP fija (``192.168.10.10``) y nombre de host (``srv-app01``) sin consumir el rango dinámico.

Alternativa de Persistencia Empresarial: PostgreSQL y MySQL
-----------------------------------------------------------
Para entornos de alta disponibilidad, clústeres activos/pasivos o sincronización centralizada, Kea permite sustituir el bloque ``lease-database`` por un motor SQL relacional:

.. code-block:: json

   {
      "Dhcp4": {
         "lease-database": {
            "type": "postgresql",
            "name": "keadb",
            "host": "127.0.0.1",
            "port": 5432,
            "user": "keauser",
            "password": "ClaveSeguraPostgreSQL",
            "ssl-mode": "prefer",
            "on-fail": "serve-retry-continue"
         }
      }
   }

Para inicializar las tablas requeridas por Kea en PostgreSQL o MySQL, se utiliza la utilidad ``kea-admin``:

.. code-block:: bash

   # Inicializar esquema relacional en PostgreSQL
   su - postgres -c "createuser -P keauser"
   su - postgres -c "createdb -O keauser keadb"
   kea-admin db-init pgsql -u keauser -p ClaveSeguraPostgreSQL -n keadb -h 127.0.0.1

Configuración del Agente de Control REST (/etc/kea/kea-ctrl-agent.conf)
-----------------------------------------------------------------------
El agente de control expone un endpoint HTTP para inspeccionar métricas, consultar arrendamientos activos y reconfigurar el servidor mediante comandos JSON. Configura ``/etc/kea/kea-ctrl-agent.conf``:

.. code-block:: json

   {
      "Control-agent": {
         "http-host": "127.0.0.1",
         "http-port": 8000,
         "control-sockets": {
            "dhcp4": {
               "socket-type": "unix",
               "socket-name": "/run/kea/kea-dhcp4.sock"
            }
         },
         "loggers": [
            {
               "name": "kea-ctrl-agent",
               "output_options": [
                  {
                     "output": "stdout"
                  }
               ],
               "severity": "INFO"
            }
         ]
      }
   }

Validación de Sintaxis y Estructura
-----------------------------------
Antes de intentar iniciar el servicio en producción, valida que la sintaxis JSON sea impecable y que las directivas cumplan con el esquema oficial de Kea utilizando la bandera ``-t``:

.. code-block:: bash

   # Validar configuración de DHCPv4
   kea-dhcp4 -t /etc/kea/kea-dhcp4.conf

   # Validar configuración del Agente de Control
   kea-ctrl-agent -t /etc/kea/kea-ctrl-agent.conf

Si la salida devuelve un estado exitoso (código de salida 0) y mensajes informativos sin advertencias de error, los archivos están listos para entrar en operación.

Habilitación e Inicio de Servicios
----------------------------------
En systemd, habilita e inicia de forma atómica tanto el motor DHCPv4 como el agente de control:

.. code-block:: bash

   # Habilitar e iniciar inmediatamente ambos demonios
   systemctl enable --now kea-dhcp4.service kea-ctrl-agent.service

Configuración de Cortafuegos y Red
----------------------------------
El protocolo DHCPv4 opera sobre UDP utilizando el puerto 67 en el servidor y el puerto 68 en los clientes. Configura ``firewalld`` para permitir el tráfico de servicio DHCP de manera permanente en la zona activa (habitualmente ``internal`` o ``FedoraWorkstation``/``public``):

.. code-block:: bash

   # Habilitar el servicio dhcp en firewalld de manera permanente
   firewall-cmd --permanent --add-service=dhcp

   # Aplicar los cambios inmediatamente en el cortafuegos
   firewall-cmd --reload

   # Verificar que el servicio esté activo en la zona de red
   firewall-cmd --list-services


Verificación y Pruebas
======================
Para confirmar que el servidor Kea está respondiendo correctamente a las solicitudes de la red, ejecuta los siguientes pasos de verificación técnica:

1. **Estado de los servicios**:

   Verifica que los procesos de Kea estén en ejecución activa (``active (running)``):

   .. code-block:: bash

      systemctl status kea-dhcp4.service kea-ctrl-agent.service

2. **Monitoreo de bitácoras en tiempo real**:

   Inspecciona los registros generados por ``kea-dhcp4`` mediante ``journalctl``. Observa la inicialización de sockets crudos (raw sockets) en ``eth1`` y la detección de la subred:

   .. code-block:: bash

      journalctl -u kea-dhcp4.service -e --no-pager

3. **Inspección de arrendamientos en archivo CSV**:

   Cuando un cliente solicite una IP, Kea registrará la asignación en ``/var/lib/kea/kea-leases4.csv``:

   .. code-block:: bash

      cat /var/lib/kea/kea-leases4.csv

   El encabezado del archivo muestra los campos estructurados:

   .. code-block:: text

      address,hwaddr,client_id,valid_lifetime,expire,subnet_id,fqdn_fwd,fqdn_rev,hostname,state,user_context

4. **Prueba de solicitud desde un equipo cliente**:

   Desde otra máquina conectada al mismo segmento LAN (por ejemplo, a través de ``eth0`` en el cliente), solicita una dirección IP dinámica:

   .. code-block:: bash

      # Solicitar arrendamiento con dhclient mostrando información detallada
      dhclient -v -d eth0

   Alternativamente, puedes verificar la capacidad de respuesta del servidor DHCP sin modificar la configuración de red del equipo utilizando la utilidad ``dhcping``:

   .. code-block:: bash

      # Probar conectividad con el servidor DHCP enviando un paquete de prueba
      dhcping -c 192.168.10.100 -s 192.168.10.1 -h 52:54:00:12:34:56

5. **Consulta de estado vía API REST con kea-ctrl-agent**:

   Envía una solicitud JSON mediante ``curl`` hacia el agente de control para obtener el estado del servidor DHCPv4 en caliente:

   .. code-block:: bash

      curl -X POST \
         -H "Content-Type: application/json" \
         -d '{"command": "status-get", "service": ["dhcp4"]}' \
         http://127.0.0.1:8000/

   La respuesta retornará un resultado con código ``0`` y el resumen de ejecución en vivo:

   .. code-block:: json

      [
         {
            "result": 0,
            "text": "Configuration: /etc/kea/kea-dhcp4.conf, reload time: ..., uptime: ...s, multi-threading: enabled"
         }
      ]


Problemática
============

Errores de sintaxis JSON y formato estricto
-------------------------------------------
Kea utiliza un analizador JSON estricto para ciertos tipos de datos. Los problemas más comunes incluyen:

* **Comas sobrantes o ausentes**: Aunque Kea soporta comas al final de listas en muchas versiones, las comas faltantes entre objetos causan fallos inmediatos al parsear el archivo.
* **Ceros a la izquierda en números**: Kea no tolera enteros con ceros a la izquierda (por ejemplo, escribir ``01`` en lugar de ``1`` en el parámetro ``"id": 1``).
* **Diagnóstico**: Ejecuta siempre ``kea-dhcp4 -t /etc/kea/kea-dhcp4.conf``. La salida indicará con precisión el número de línea y columna donde se localiza el error gramatical.

Interfaz de red sin dirección IP asignada al iniciar el servicio
----------------------------------------------------------------
Si ``kea-dhcp4`` se inicia y la interfaz especificada en ``interfaces-config`` (por ejemplo ``eth1``) no tiene asignada una dirección IP estática perteneciente al bloque de la subred (``192.168.10.0/24``), el servicio fallará con el error:

.. code-block:: text

   DHCP4_INIT_FAIL failed to initialize Kea server: failed to select subnet for interface eth1

Para solucionarlo de forma permanente en CentOS Stream 10 y Fedora 44, asigna la dirección estática mediante NetworkManager antes de iniciar Kea:

.. code-block:: bash

   # Asignar IP estática y activar la conexión en la interfaz LAN
   nmcli connection add type ethernet con-name eth1 ifname eth1 ipv4.method manual ipv4.addresses 192.168.10.1/24 ipv6.method disabled
   nmcli connection up eth1

Conflicto de puertos UDP 67 con servicios heredados (dhcpd o dnsmasq)
---------------------------------------------------------------------
Si en el servidor aún se encuentra instalado o ejecutándose el demonio clásico ``dhcpd`` o un resolvedor DNS como ``dnsmasq`` con DHCP habilitado, Kea no podrá enlazar los sockets crudos o sockets UDP en el puerto 67.

* **Identificar proceso en conflicto**:

  .. code-block:: bash

     ss -tulpn | grep ':67 '

* **Deshabilitar y detener el servicio conflictivo**:

  .. code-block:: bash

     systemctl disable --now dhcpd.service dnsmasq.service

Bloqueos por SELinux en rutas o bases de datos no estándar
----------------------------------------------------------
En modo ``Enforcing``, SELinux restringe el acceso de ``kea-dhcp4`` únicamente a rutas con contextos autorizados (como ``kea_conf_t`` para configuración en ``/etc/kea`` y ``kea_var_lib_t`` para arrendamientos en ``/var/lib/kea``).

Si configuras una ruta no estándar para el archivo de arrendamientos o almacenas datos en otro directorio:

.. code-block:: bash

   # Inspeccionar posibles denegaciones en auditoría
   ausearch -m avc -ts recent

   # Registrar y restaurar el contexto de tipo kea_var_lib_t en la ruta personalizada
   semanage fcontext -a -t kea_var_lib_t "/srv/kea(/.*)?"
   restorecon -Rv /srv/kea


Referencias
===========
* Documentación oficial de Red Hat Enterprise Linux 10: Configuring and Managing Networking/Migrating from ISC DHCP to Kea: https://docs.redhat.com/
* Manual de Referencia del Administrador de ISC Kea (Kea ARM): https://kea.readthedocs.io/en/latest/
* Base de Conocimientos de ISC (Knowledge Base): https://kb.isc.org/
* Repositorio oficial de ISC Kea en GitLab: https://gitlab.isc.org/isc-projects/kea
* Documentación oficial del Proyecto Fedora: https://docs.fedoraproject.org/
* Documentación oficial de CentOS Stream: https://www.centos.org/centos-stream/
