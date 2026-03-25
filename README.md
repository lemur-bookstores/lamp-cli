# LAMP Stack CLI Installer
### Ubuntu 22.04 LTS — AWS Lightsail

Instalador modular de LAMP con selección de fases, parámetros con nombre y prompts interactivos para los valores faltantes.

---

## Estructura del proyecto

```
lamp-cli/
├── install.sh               ← Orquestador principal (punto de entrada)
├── lib/
│   └── common.sh            ← Utilidades compartidas (colores, logging, ask_param)
└── phases/
    ├── 01_preflight.sh      ← Verificaciones previas (OS, RAM, DNS, puertos)
    ├── 02_system_prep.sh    ← Swap + apt update/upgrade
    ├── 03_lamp_install.sh   ← Apache, PHP, MariaDB, Certbot, VSFTPD
    ├── 04_vhost.sh          ← Virtual Host Apache
    ├── 05_database.sh       ← Hardening MariaDB + base de datos y usuario
    ├── 06_ssl.sh            ← Certificado Let's Encrypt (Certbot)
    ├── 07_php_tuning.sh     ← Optimización php.ini
    ├── 08_mariadb_tuning.sh ← Tuning InnoDB y parámetros de rendimiento
    └── 09_file_transfer.sh  ← FTPS (VSFTPD) o SFTP (subsistema SSH)
```

---

## Requisitos previos

| Requisito          | Detalle                                                  |
|--------------------|----------------------------------------------------------|
| OS                 | Ubuntu 22.04 LTS                                         |
| Privilegios        | `sudo` — la mayoría de las fases requieren permisos root |
| DNS (Phase 6)      | Los registros A deben apuntar al servidor antes del SSL  |
| Let's Encrypt (Phase 9 FTPS) | Phase 6 debe completarse antes de Phase 9 con `ftps` |

```bash
# Otorgar permisos de ejecución (una sola vez, en el servidor)
chmod +x install.sh phases/*.sh
```

---

## Referencia rápida de parámetros

| Parámetro          | Variable             | Defecto  | Descripción                              |
|--------------------|----------------------|----------|------------------------------------------|
| `--domain`         | `DOMAIN`             | —        | Dominio principal sin `www`              |
| `--admin-email`    | `ADMIN_EMAIL`        | —        | Email para alertas de expiración SSL     |
| `--db-name`        | `DB_NAME`            | —        | Nombre de la base de datos               |
| `--db-user`        | `DB_USER`            | —        | Usuario de la base de datos              |
| `--db-pass`        | `DB_PASS`            | —        | Contraseña (prompt oculto si se omite)   |
| `--php-version`    | `PHP_VERSION`        | `8.2`    | Versión de PHP a instalar                |
| `--swap-size`      | `SWAP_SIZE`          | `4G`     | Tamaño del archivo de swap               |
| `--ftp-mode`       | `FTP_MODE`           | `ftps`   | Modo de transferencia: `ftps` o `sftp`   |
| `--ftp-user`       | `FTP_USER`           | —        | Usuario FTP/SFTP                         |
| `--ftp-pass`       | `FTP_PASS`           | —        | Contraseña FTP/SFTP (prompt oculto)      |
| `--mariadb-ratio`  | `MARIADB_BUFFER_RATIO` | `60`   | % de RAM para InnoDB buffer pool (50–70) |
| `--phases`         | —                    | (menú)   | Fases a ejecutar, ej: `1,2,3` o `all`   |

> Cualquier parámetro omitido activa un **prompt interactivo**. Los parámetros de contraseña siempre usan entrada oculta con confirmación cuando se ingresan de forma interactiva.

---

## Casos de uso

---

### Caso 1 — Instalación completa (modo interactivo)

El instalador muestra un menú de fases y solicita cada valor que falte.

```bash
sudo ./install.sh
```

**Flujo de sesión de ejemplo:**

```
══════════════════════════════════════════════
  Selecciona las fases a ejecutar:

  [1] Pre-Flight Checks
  [2] System Preparation (swap, apt)
  [3] LAMP Stack Installation
  [4] Virtual Host Configuration
  [5] Database Security & Setup
  [6] SSL Certificate (Let's Encrypt)
  [7] PHP Performance Tuning
  [8] MariaDB Performance Tuning
  [9] File Transfer Service (FTP/SFTP)
  [a] Run ALL phases (1–9)
  [q] Quit

Enter phases (comma-separated, e.g. 1,2,3 or a): a

  Primary domain (no www): training.example.com
  Admin email (for cert expiry alerts): admin@example.com
  Database name: moodle_db
  Database username: moodleuser
  Database password: ████████
  Confirm Database password: ████████
  ...
```

---

### Caso 2 — Instalación completa con todos los parámetros en línea de comandos

Ideal para **scripts de aprovisionamiento automatizado** (CI/CD, user-data de Lightsail).

```bash
sudo ./install.sh \
  --domain        training.example.com \
  --admin-email   admin@example.com \
  --db-name       moodle_db \
  --db-user       moodleuser \
  --db-pass       "S3cur3P@ssw0rd!" \
  --php-version   8.2 \
  --swap-size     4G \
  --ftp-mode      ftps \
  --ftp-user      ftpuser \
  --ftp-pass      "Ftp$ecure2024!" \
  --mariadb-ratio 60 \
  --phases        all
```

---

### Caso 3 — Solo verificaciones previas (diagnóstico del servidor)

Útil para confirmar que el servidor, el DNS y los puertos están listos **antes** de instalar nada.

```bash
sudo ./install.sh --domain training.example.com --phases 1
```

O directamente como script independiente:

```bash
sudo ./phases/01_preflight.sh --domain training.example.com
```

**Qué verifica:**
- Versión de OS y usuario actual
- RAM total y espacio en disco
- IP pública vs. resolución DNS del dominio
- Puertos 80, 443, 21, 22 en uso

---

### Caso 4 — Preparación del sistema (swap + actualizaciones)

Para servidores pequeños (≤ 1 GB RAM) donde `apt upgrade` puede terminar el proceso por OOM.

```bash
# Swap de 2 GB en instancia nano
sudo ./install.sh --swap-size 2G --phases 2

# Swap de 4 GB en instancia medium (recomendado para Moodle)
sudo ./install.sh --swap-size 4G --phases 2
```

O standalone:

```bash
sudo ./phases/02_system_prep.sh --swap-size 4G
```

---

### Caso 5 — Solo instalar el stack LAMP (sin configurar nada más)

```bash
# PHP 8.2 (por defecto)
sudo ./install.sh --phases 3

# PHP 8.3
sudo ./install.sh --php-version 8.3 --phases 3
```

O standalone:

```bash
sudo ./phases/03_lamp_install.sh --php-version 8.1
```

**Paquetes instalados:** Apache 2, MariaDB, PHP + extensiones (fpm, cli, mysql, zip, ldap, xml, gd, curl, tidy, mbstring, intl, soap, imagick), Certbot, VSFTPD.

---

### Caso 6 — Configurar un Virtual Host para un dominio

```bash
sudo ./install.sh \
  --domain      training.example.com \
  --php-version 8.2 \
  --phases      4
```

O standalone:

```bash
sudo ./phases/04_vhost.sh \
  --domain      training.example.com \
  --php-version 8.2
```

**Resultado:**
```
/var/www/vhosts/training.example.com/
├── httpdocs/        ← DocumentRoot (propietario: www-data)
└── logs/
    ├── access.log
    └── error.log
```

Config Apache generada en:
`/etc/apache2/sites-available/training.example.com.conf`

---

### Caso 7 — Instalar stack + Virtual Host + Base de datos (sin SSL aún)

Flujo típico para un ambiente de staging donde el DNS aún no apunta al servidor.

```bash
sudo ./install.sh \
  --domain      staging.example.com \
  --php-version 8.2 \
  --db-name     moodle_db \
  --db-user     moodleuser \
  --db-pass     "S3cur3P@ss!" \
  --phases      3,4,5
```

---

### Caso 8 — Emitir certificado SSL (una vez el DNS está listo)

```bash
sudo ./install.sh \
  --domain      training.example.com \
  --admin-email admin@example.com \
  --phases      6
```

O standalone:

```bash
sudo ./phases/06_ssl.sh \
  --domain      training.example.com \
  --admin-email admin@example.com
```

> El script verifica automáticamente que el DNS resuelva al IP del servidor antes de llamar a Certbot. Si no coincide, **aborta** con un mensaje de error claro en lugar de consumir el rate-limit de Let's Encrypt.

**Renovación automática:** cron cada 12 horas — configurado automáticamente.

---

### Caso 9 — Optimizar PHP para Moodle / LMS

Con los valores recomendados por defecto:

```bash
sudo ./install.sh --php-version 8.2 --phases 7
```

Con valores personalizados:

```bash
sudo ./phases/07_php_tuning.sh
# Prompts:
#   PHP version: 8.2
#   max_input_vars  [5000]: 6000
#   max_execution_time [250]: 300
#   post_max_size [50M]: 100M
#   upload_max_filesize [50M]: 100M
#   max_input_time [250]: 300
```

| Directiva            | Valor por defecto | Mínimo recomendado Moodle |
|----------------------|-------------------|---------------------------|
| `max_input_vars`     | 5000              | 5000                      |
| `max_execution_time` | 250               | 160                       |
| `post_max_size`      | 50M               | 50M                       |
| `upload_max_filesize`| 50M               | 50M                       |
| `max_input_time`     | 250               | 120                       |

---

### Caso 10 — Tuning de MariaDB según la RAM del servidor

El script calcula automáticamente `innodb_buffer_pool_size` en función de la RAM real del servidor.

```bash
# 60% de la RAM (recomendado para servidor dedicado a base de datos)
sudo ./install.sh --mariadb-ratio 60 --phases 8

# 50% (recomendado si Apache/PHP conviven en el mismo servidor)
sudo ./install.sh --mariadb-ratio 50 --phases 8
```

**Ejemplo de cálculo en instancia de 2 GB RAM:**

| Variable                   | Cálculo           | Resultado |
|----------------------------|-------------------|-----------|
| `RAM_TOTAL_MB`             | `free -m`         | 2048 MB   |
| `MARIADB_BUFFER_RATIO`     | configurado       | 60%       |
| `innodb_buffer_pool_size`  | 2048 × 60 / 100   | **1228 MB** |

---

### Caso 11 — Servicio de transferencia de archivos: FTPS (VSFTPD + TLS)

Requiere que la fase 6 (SSL) haya completado. Usa el certificado de Let's Encrypt.

```bash
sudo ./install.sh \
  --domain   training.example.com \
  --ftp-mode ftps \
  --ftp-user ftpuser \
  --ftp-pass "Ftp$ecure!" \
  --phases   9
```

**Conexión:** Puerto 21, Explicit TLS (FileZilla, WinSCP).  
**Puertos pasivos:** 49152–65535 TCP (deben abrirse en el firewall de Lightsail).

---

### Caso 12 — Servicio de transferencia de archivos: SFTP (subsistema SSH)

Más seguro — no requiere servicio adicional ni certificado TLS. Usa el puerto 22 existente.

```bash
sudo ./install.sh \
  --domain   training.example.com \
  --ftp-mode sftp \
  --ftp-user sftpuser \
  --ftp-pass "Sftp$ecure!" \
  --phases   9
```

**Conexión:** Puerto 22, protocolo SFTP (FileZilla, WinSCP, Cyberduck).  
El usuario queda **enjaulado (chroot)** en `/var/www/vhosts/<domain>`.

---

### Caso 13 — Reinstalar o reconfigurar una sola fase sin tocar las demás

Ejemplo: el certificado SSL expiró o hubo un error, y solo se necesita re-emitir:

```bash
sudo ./phases/06_ssl.sh \
  --domain      training.example.com \
  --admin-email admin@example.com
```

Ejemplo: cambiar la contraseña de la base de datos:

```bash
sudo ./phases/05_database.sh \
  --db-name moodle_db \
  --db-user moodleuser \
  --db-pass "NuevaContraseña2025!"
```

---

### Caso 14 — Servidor con poca RAM (512 MB / 1 GB)

Configuración conservadora para instancias nano o micro de Lightsail.

```bash
sudo ./install.sh \
  --swap-size     4G \
  --php-version   8.2 \
  --mariadb-ratio 50 \
  --phases        2,3,4,5,6,7,8
```

> El swap se configura en la fase 2, **antes** que el apt upgrade, para evitar OOM kills.

---

### Caso 15 — Múltiples dominios en el mismo servidor

Ejecutar la fase 4 varias veces, una por dominio:

```bash
# Primer dominio
sudo ./phases/04_vhost.sh --domain sitio-a.com --php-version 8.2

# Segundo dominio
sudo ./phases/04_vhost.sh --domain sitio-b.com --php-version 8.2

# SSL para cada dominio
sudo ./phases/06_ssl.sh --domain sitio-a.com --admin-email admin@sitio-a.com
sudo ./phases/06_ssl.sh --domain sitio-b.com --admin-email admin@sitio-b.com
```

Cada vhost tiene su propia estructura:
```
/var/www/vhosts/
├── sitio-a.com/httpdocs/
└── sitio-b.com/httpdocs/
```

---

## Confirmación JSON por fase

Cada fase emite un bloque JSON al finalizar, útil para pipelines automatizados o auditoría:

```json
{
  "phase": "4_vhost",
  "status": "success",
  "site": {
    "domain": "training.example.com",
    "root_path": "/var/www/vhosts/training.example.com/httpdocs",
    "php_version": "8.2",
    "config_path": "/etc/apache2/sites-available/training.example.com.conf",
    "config_syntax_test": "Syntax OK",
    "apache_status": "active",
    "http_check": "200"
  }
}
```

> Las contraseñas nunca aparecen en el JSON — se muestran como `"(hidden)"`.

---

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| Phase 6 falla: DNS mismatch | DNS no apunta al servidor | Actualizar registro A y esperar propagación |
| Phase 9 FTPS falla: cert not found | Phase 6 no se ejecutó | Ejecutar `./phases/06_ssl.sh` primero |
| `php.ini` no refleja cambios | FPM no se reinició | `sudo systemctl restart php8.2-fpm` |
| MariaDB no inicia tras Phase 8 | `innodb_log_file_size` incompatible | Revisar `/var/log/mysql/error.log` |
| Conexión FTP rechazada (modo pasivo) | Puerto pasivo cerrado | Abrir 49152–65535 TCP en Lightsail firewall |
| `ask_param` no solicita un campo | Variable ya exportada en el shell | `unset VARIABLE` y volver a ejecutar |
