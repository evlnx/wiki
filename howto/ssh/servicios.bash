#!/usr/bin/bash
# Habilitación e inicio de OpenSSH y apertura en cortafuegos
set -euo pipefail
IFS=$'\n\t'

# Habilitar e iniciar sshd inmediatamente
systemctl enable --now sshd.service

# Permitir servicio SSH en firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload
