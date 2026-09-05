=================================================================
Monitoreo y Telemetría del Sistema con Prometheus y Node Exporter
=================================================================
----------------------------------------------------------------------
HowTo: Guía práctica y paso a paso para CentOS Stream 10 y/o Fedora 44
----------------------------------------------------------------------

Descripción
===========
Prometheus es un sistema de monitoreo y base de datos de series temporales (*Time-Series Database* o TSDB) de código abierto diseñado bajo una arquitectura basada en extracción (*pull-based scraping*) mediante HTTP. Su modelo de datos multidimensional organiza la información mediante nombres de métricas y pares clave/valor denominados etiquetas (*labels*), permitiendo una inspección granular y eficiente del estado de la infraestructura. Prometheus incorpora el lenguaje de consultas PromQL (*Prometheus Query Language*), optimizado para cómputos vectoriales, agregaciones en tiempo real y disparo de alertas operativas.

Node Exporter es el exportador oficial de telemetría de hardware y sistema operativo para entornos UNIX/Linux. Mantiene un punto de enlace HTTP donde expone contadores del núcleo Linux, estados de CPU, memoria virtual y física, operaciones de bloques de disco, rendimiento de interfaces de red y estado de unidades de servicio.

En **CentOS Stream 10** y **Fedora 44**, el despliegue de esta pila se implementa de forma nativa bajo ``systemd`` con políticas de aislamiento de privilegios mínimos (*sandboxing* defensivo) y compatibilidad total con SELinux en modo ``Enforcing``, garantizando una operación resiliente, desacoplada y apta para entornos de misión crítica.


Prerrequisitos
==============
* Instalación base de **CentOS Stream 10** y/o **Fedora 44** (ver: [[Instalando CentOS Stream 10 y Fedora 44|/centos/instalacion]]).
* Acceso como superusuario (cuenta root).
* SELinux activo y operando en modo ``Enforcing``.
* Acceso a repositorios oficiales y repositorio EPEL 10 (en CentOS Stream 10).
* Herramientas básicas de línea de comandos (``curl``, ``tar``, ``jq``).


Instalación
===========
La instalación puede realizarse mediante paquetes de distribución o mediante los binarios oficiales upstream. Para mantener coherencia con el estándar FHS (*Filesystem Hierarchy Standard*) y garantizar seguridad de privilegios mínimos, ambos métodos requieren usuarios del sistema dedicados y una estructura de directorios restringida.

Usuarios de Sistema Dedicados
-----------------------------
Se crean cuentas de servicio sin directorio de inicio ni intérprete de comandos interactivo (``/sbin/nologin``):

.. code:: bash

   # Crear usuario de sistema para Prometheus
   useradd --system --no-create-home --shell /sbin/nologin prometheus

   # Crear usuario de sistema para Node Exporter
   useradd --system --no-create-home --shell /sbin/nologin node_exporter

Estructura de Directorios y Permisos FHS
----------------------------------------
Se configuran las rutas de almacenamiento para la base de datos TSDB (``/var/lib/prometheus``) y la configuración del servicio (``/etc/prometheus``):

.. code:: bash

   # Crear jerarquía de directorios estándar
   mkdir -p /etc/prometheus
   mkdir -p /var/lib/prometheus
   mkdir -p /var/lib/node_exporter/textfile_collector

   # Asignar propiedad de directorios
   chown -R prometheus:prometheus /etc/prometheus
   chown -R prometheus:prometheus /var/lib/prometheus
   chown -R node_exporter:node_exporter /var/lib/node_exporter

   # Restringir permisos a modo estricto
   chmod 0750 /etc/prometheus
   chmod 0750 /var/lib/prometheus
   chmod 0750 /var/lib/node_exporter/textfile_collector

Instalación mediante Paquetes DNF
---------------------------------
En Fedora 44 y CentOS Stream 10 (con repositorio EPEL activo), se pueden instalar las herramientas empaquetadas:

.. code:: bash

   # En CentOS Stream 10, habilitar EPEL si no está presente
   dnf -y install epel-release

   # Instalar Node Exporter y utilidades
   dnf -y install golang-github-prometheus-node_exporter jq curl

Despliegue de Binarios Oficiales Upstream
-----------------------------------------
El despliegue de binarios oficiales upstream garantiza paridad exacta de versiones tanto en CentOS Stream 10 como en Fedora 44:

.. code:: bash

   # Definir versiones de despliegue
   PROMETHEUS_VER="3.2.1"
   NODE_EXPORTER_VER="1.9.0"

   # Descargar e instalar Prometheus y promtool
   curl -sSL -o /tmp/prometheus.tar.gz "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VER}/prometheus-${PROMETHEUS_VER}.linux-amd64.tar.gz"
   tar -xzf /tmp/prometheus.tar.gz -C /tmp
   install -m 0755 /tmp/prometheus-${PROMETHEUS_VER}.linux-amd64/prometheus /usr/local/bin/prometheus
   install -m 0755 /tmp/prometheus-${PROMETHEUS_VER}.linux-amd64/promtool /usr/local/bin/promtool

   # Copiar bibliotecas de consola si se requieren
   cp -r /tmp/prometheus-${PROMETHEUS_VER}.linux-amd64/consoles /etc/prometheus/
   cp -r /tmp/prometheus-${PROMETHEUS_VER}.linux-amd64/console_libraries /etc/prometheus/
   chown -R prometheus:prometheus /etc/prometheus/consoles /etc/prometheus/console_libraries

   # Descargar e instalar Node Exporter
   curl -sSL -o /tmp/node_exporter.tar.gz "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VER}/node_exporter-${NODE_EXPORTER_VER}.linux-amd64.tar.gz"
   tar -xzf /tmp/node_exporter.tar.gz -C /tmp
   install -m 0755 /tmp/node_exporter-${NODE_EXPORTER_VER}.linux-amd64/node_exporter /usr/local/bin/node_exporter

   # Limpiar archivos temporales
   rm -rf /tmp/prometheus* /tmp/node_exporter*


Configuración
=============
A continuación se detallan los archivos de servicio de ``systemd`` aplicando sandboxing estricto conforme a la arquitectura de seguridad del sistema operativo, junto con la configuración de recolección métrica.

Configuración de Node Exporter
------------------------------
Node Exporter se supervisa mediante una unidad de servicio ``systemd`` reforzada. Se habilitan los recolectores de subsistemas de sistema operativo esenciales (``systemd``, ``filesystem``, ``cpu``, ``meminfo``, ``diskstats``) y se restringe la dirección de escucha a la interfaz local ``127.0.0.1:9100`` o a la dirección IP interna de una VPN (WireGuard).

Crear el archivo de unidad ``/etc/systemd/system/node_exporter.service``:

.. code:: ini

   [Unit]
   Description=Prometheus Node Exporter
   Documentation=https://github.com/prometheus/node_exporter
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=exec
   User=node_exporter
   Group=node_exporter
   ExecStart=/usr/local/bin/node_exporter \
      --web.listen-address=127.0.0.1:9100 \
      --collector.systemd \
      --collector.filesystem \
      --collector.cpu \
      --collector.meminfo \
      --collector.diskstats \
      --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
   Restart=always
   RestartSec=5s

   # Directivas de Aislamiento y Sandboxing (systemd hardening)
   NoNewPrivileges=yes
   ProtectSystem=strict
   ProtectHome=yes
   PrivateTmp=yes
   CapabilityBoundingSet=
   ProtectKernelTunables=yes
   ProtectKernelModules=yes
   ProtectControlGroups=yes
   MemoryDenyWriteExecute=yes
   LockPersonality=yes
   RestrictRealtime=yes

   [Install]
   WantedBy=multi-user.target

.. note::

   La directiva ``ProtectSystem=strict`` monta todo el sistema de archivos en modo de solo lectura para el servicio excepto ``/dev``, ``/proc`` y ``/sys``. Dado que Node Exporter requiere inspeccionar contadores del kernel en ``/proc`` y ``/sys``, esta combinación protege el sistema operativo sin interrumpir la extracción de métricas.

Configuración de Prometheus
---------------------------
El archivo principal de configuración de Prometheus define los intervalos globales de recolección (*scraping*) y los objetivos (*targets*) que serán consultados periódicamente.

Crear el archivo ``/etc/prometheus/prometheus.yml``:

.. code:: yaml

   # Archivo: /etc/prometheus/prometheus.yml
   global:
     scrape_interval: 15s
     evaluation_interval: 15s
     scrape_timeout: 10s

   scrape_configs:
     - job_name: "prometheus"
       static_configs:
         - targets: ["127.0.0.1:9090"]

     - job_name: "node_exporter"
       scrape_interval: 15s
       static_configs:
         - targets: ["127.0.0.1:9100"]

Validar la sintaxis del archivo de configuración antes de iniciar el servicio:

.. code:: bash

   promtool check config /etc/prometheus/prometheus.yml

Crear el archivo de unidad de servicio ``/etc/systemd/system/prometheus.service`` incorporando retención de datos y directivas de seguridad:

.. code:: ini

   [Unit]
   Description=Prometheus Time Series Database and Monitoring Server
   Documentation=https://prometheus.io/docs/introduction/overview/
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=exec
   User=prometheus
   Group=prometheus
   ExecStart=/usr/local/bin/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/var/lib/prometheus \
      --storage.tsdb.retention.time=30d \
      --storage.tsdb.retention.size=50GB \
      --web.listen-address=127.0.0.1:9090 \
      --web.enable-lifecycle
   ExecReload=/usr/bin/kill -HUP $MAINPID
   Restart=always
   RestartSec=5s
   LimitNOFILE=65536
   LimitNPROC=4096

   # Directivas de Aislamiento y Sandboxing (systemd hardening)
   NoNewPrivileges=yes
   ProtectSystem=strict
   ReadWritePaths=/var/lib/prometheus
   ProtectHome=yes
   PrivateTmp=yes
   CapabilityBoundingSet=
   ProtectKernelTunables=yes
   ProtectKernelModules=yes
   ProtectControlGroups=yes
   MemoryDenyWriteExecute=yes
   LockPersonality=yes
   RestrictRealtime=yes

   [Install]
   WantedBy=multi-user.target

.. note::

   Bajo ``ProtectSystem=strict``, todo el árbol de directorios es de solo lectura. La directiva ``ReadWritePaths=/var/lib/prometheus`` habilita explícitamente permisos de escritura en el directorio de la base de datos TSDB para el usuario ``prometheus``.

Habilitación e Inicio de Servicios
----------------------------------
Una vez instalados los ejecutables y declaradas las unidades de servicio, se notifica a ``systemd`` para procesar los cambios e iniciar los procesos:

.. code:: bash

   # Recargar configuración del gestor de servicios
   systemctl daemon-reload

   # Habilitar e iniciar inmediatamente Node Exporter y Prometheus
   systemctl enable --now node_exporter.service prometheus.service

   # Verificar estado de ejecución
   systemctl status node_exporter.service prometheus.service --no-pager

Configuración de Cortafuegos y Red
----------------------------------
En un despliegue donde Prometheus y Node Exporter residen en el mismo host, la vinculación a ``127.0.0.1`` no requiere apertura de puertos externos en ``firewalld``, preservando la superficie de ataque en cero.

En infraestructuras distribuidas donde los nodos monitoreados envían telemetría hacia un servidor central mediante una red privada o túnel WireGuard (interfaz ``wg0``), el puerto ``9100/tcp`` debe autorizarse exclusivamente en la zona de red interna o mediante reglas enriquecidas (*rich rules*):

.. code:: bash

   # Asignar la interfaz VPN a la zona internal
   firewall-cmd --permanent --zone=internal --add-interface=wg0

   # Opción A: Permitir el puerto 9100/tcp en toda la zona internal
   firewall-cmd --permanent --zone=internal --add-port=9100/tcp

   # Opción B: Restringir acceso al puerto 9100/tcp exclusivamente a la IP de Prometheus (10.100.0.10)
   firewall-cmd --permanent --zone=internal --add-rich-rule='rule family="ipv4" source address="10.100.0.10/32" port port="9100" protocol="tcp" accept'

   # Aplicar cambios en el cortafuegos
   firewall-cmd --reload


Verificación y Pruebas
======================
Para certificar el correcto aprovisionamiento y flujo de telemetría, se ejecutan las siguientes comprobaciones operativas:

#. **Validación de bitácoras y estado activo**:

   .. code:: bash

      systemctl is-active node_exporter.service prometheus.service
      journalctl -u node_exporter.service -n 20 --no-pager
      journalctl -u prometheus.service -n 20 --no-pager

#. **Inspección directa del punto de métricas de Node Exporter**:

   .. code:: bash

      curl -s http://127.0.0.1:9100/metrics | head -n 30

#. **Verificación de objetivos de recolección en Prometheus**:

   .. code:: bash

      curl -s http://127.0.0.1:9090/api/v1/targets | jq .

   La salida debe reflejar ambos objetivos (``prometheus`` y ``node_exporter``) con el estado ``"health": "up"``.

#. **Consultas de telemetría mediante PromQL**:

   Ejecutar consulta de verificación de disponibilidad general (debe retornar valor ``1`` para cada instancia activa):

   .. code:: bash

      curl -s -G --data-urlencode "query=up" http://127.0.0.1:9090/api/v1/query | jq .

   Consultar el uso de CPU en modo ocioso (*idle*) para verificar el cálculo de tasas:

   .. code:: bash

      curl -s -G --data-urlencode 'query=rate(node_cpu_seconds_total{mode="idle"}[5m])' http://127.0.0.1:9090/api/v1/query | jq .

   Consultar el porcentaje de memoria RAM utilizada en el sistema:

   .. code:: bash

      curl -s -G --data-urlencode 'query=(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100' http://127.0.0.1:9090/api/v1/query | jq .

   Consultar espacio libre en el sistema de archivos raíz:

   .. code:: bash

      curl -s -G --data-urlencode 'query=node_filesystem_free_bytes{mountpoint="/"}' http://127.0.0.1:9090/api/v1/query | jq .


Problemática
============

Agotamiento de Espacio en Disco por Retención TSDB
--------------------------------------------------
Prometheus escribe datos continuos en segmentos WAL (*Write-Ahead Log*) y bloques compactados de dos horas en ``/var/lib/prometheus``. Si un entorno sufre una alta tasa de rotación de etiquetas (*high churn rate*) o cardinalidad desmedida, el almacenamiento puede colapsar antes de alcanzar el tiempo de retención por defecto.

* **Diagnóstico**: Inspeccionar el tamaño del directorio de datos y la tasa de crecimiento:

  .. code:: bash

     du -sh /var/lib/prometheus
     df -h /var/lib/prometheus

* **Solución**: Limitar el tamaño máximo de la base de datos TSDB en ``/etc/systemd/system/prometheus.service`` incorporando la bandera ``--storage.tsdb.retention.size=50GB`` (o un límite acorde a la capacidad del volumen). Asimismo, es una buena práctica de ingeniería alojar ``/var/lib/prometheus`` en un volumen LVM o punto de montaje independiente para evitar el colapso del sistema de archivos raíz del sistema operativo.

Denegaciones de SELinux en Rutas Personalizadas
-----------------------------------------------
Al migrar el directorio de datos (por ejemplo, hacia un volumen NVMe secundario montado en ``/data/prometheus``), SELinux bloquea los accesos de lectura/escritura si los contextos no coinciden con las etiquetas esperadas.

* **Diagnóstico**: Localizar bloqueos AVC en la bitácora de auditoría del sistema:

  .. code:: bash

     ausearch -m avc -ts recent
     # Confirmar diagnóstico de políticas con audit2why
     ausearch -m avc -ts recent | audit2why

* **Solución**: Asignar permanentemente el contexto ``var_lib_t`` a la ruta personalizada y restaurar las etiquetas:

  .. code:: bash

     semanage fcontext -a -t var_lib_t "/data/prometheus(/.*)?"
     restorecon -Rv /data/prometheus

Alto Consumo de CPU por el Recolector textfile
----------------------------------------------
El recolector ``textfile`` lee y parsea todos los archivos con extensión ``.prom`` ubicados en ``/var/lib/node_exporter/textfile_collector`` en cada ciclo de recolección. Si scripts personalizados o tareas de cron escriben archivos de varios megabytes o realizan escrituras no atómicas mientras Node Exporter lee el archivo, se producen picos de consumo de CPU y lecturas de datos corruptos.

* **Diagnóstico**: Identificar tiempos de recolección elevados en las métricas internas de Node Exporter:

  .. code:: bash

     curl -s http://127.0.0.1:9100/metrics | grep node_scrape_collector_duration_seconds | grep textfile

* **Solución**: Garantizar escrituras atómicas en los scripts generadores mediante archivos temporales y reemplazo atómico con ``mv`` o la utilidad ``sponge``:

  .. code:: bash

     # Ejemplo de escritura atómica en scripts de telemetría personalizada
     TMPFILE=$(mktemp /var/lib/node_exporter/textfile_collector/custom_metric.prom.XXXXXX)
     echo 'custom_backup_status{job="nightly"} 1' > "$TMPFILE"
     chmod 0644 "$TMPFILE"
     mv -f "$TMPFILE" /var/lib/node_exporter/textfile_collector/custom_metric.prom

Exposición de Métricas sin Autenticación ni Cifrado
---------------------------------------------------
Por omisión, tanto Prometheus como Node Exporter publican sus métricas en texto plano sin autenticación. En redes compartidas o accesibles externamente, esto expone la arquitectura interna, nombres de usuarios, particiones, direcciones MAC y versiones del kernel.

* **Diagnóstico**: Comprobar si los puertos escuchan en interfaces públicas no deseadas:

  .. code:: bash

     ss -tulpn | grep -E ':(9090|9100)'

* **Solución**: Garantizar que el parámetro ``--web.listen-address`` esté configurado estrictamente en ``127.0.0.1`` o en la IP de la interfaz VPN privada. Para entornos donde se requiera tránsito sobre redes no confiables, habilitar autenticación básica y cifrado TLS mediante el parámetro ``--web.config.file=/etc/prometheus/web-config.yml``.


Referencias
===========
* Red Hat Enterprise Linux 10: *Monitoring and Managing System Performance*: https://docs.redhat.com/
* Documentación oficial de Prometheus: https://prometheus.io/docs/
* Repositorio y documentación de Node Exporter: https://github.com/prometheus/node_exporter
* Documentación oficial de Fedora Project: https://docs.fedoraproject.org/
* Documentación oficial de CentOS Stream: https://www.centos.org/centos-stream/
