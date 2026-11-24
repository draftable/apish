# Changelog

All notable changes to the Apish project components will be documented in this file.

---
## 2026-11-24

### apish-web:3.0.11
- Fix "too many clients" database outages: connections now close at the end of every request
    - **Note:** `DB_CONN_MAX_AGE` is no longer used and can be removed from your configuration.
- Fix uploads over 2.5 MB failing with HTTP 400 when API request logging is enabled for a credential
- Fix nginx vulnerabilities, including CVE-2026-123007 and CVE-2026-118899 (nginx 1.24.0-2ubuntu7.19 → 1.24.0-2ubuntu7.21)
- Upgrade Celery 5.4 → 5.7 and gevent 25.9 → 26.9

### docker-compose.yml
- Update RabbitMQ 4.2 → 4.3
    - **Note:** requires apish-web 3.0.11 or later. Earlier versions declare queues that RabbitMQ 4.3 rejects.
- Set a fixed RabbitMQ hostname so broker state survives container recreation
    - **Note:** RabbitMQ starts with an empty broker on the first start after this update, and messages still queued are lost. Let running comparisons finish before you upgrade.
    - **Note:** like PostgreSQL, RabbitMQ now keeps its user and password across restarts. To change `AMQP_PASSWORD` later, first run `docker compose exec rabbitmq rabbitmqctl change_password <user> <new-password>`.

---
## 2026-11-23

### apish-compare:3.0.5
- Fix plain text (.txt) comparisons and combined PDF exports failing with a missing libHarfBuzzSharp library

### apish-converter:3.0.7
- Fix Java vulnerabilities, including CVE-2026-114938 (OpenJDK) and critical and high CVEs in Spring, Tomcat and Jackson
    - OpenJDK 21.0.13 → 21.0.13.1, now Ubuntu's package so vulnerability scanners can see it
    - Spring Boot 3.4.10 → 4.1.2, Tomcat 10.1.46 → 11.0.27, jodconverter 4.4.7 → 5.1.1

### apish-load-balancer:3.0.5
- Fix vulnerabilities in nginx and OS packages, including CVE-2026-123007 and CVE-2026-118899 (nginx 1.31.8 → 1.31.9)

---
## 2026-11-16

### apish-web:3.0.10
- Fix vulnerabilities in OS packages and dependencies, including CVE-2026-111497 (brotli) and CVE-2026-109518 (apt)
    - Django 5.2.14 → 5.2.17
    - Django REST framework 3.14.0 → 3.18.3
    - aiohttp, Pillow, PyJWT, urllib3, requests, tornado
- Harden MFA: limit code attempts per account and restrict activation tokens to MFA setup
- Compress and cache static assets for faster page loads
- Add comparison viewer 3.7.57

### apish-compare:3.0.4
- Fix vulnerabilities in OS packages and the .NET runtime, including CVE-2026-111497 (brotli)
- Render PDF export cover pages and plain text (.txt) inputs with a new engine, replacing wkhtmltopdf
- Update the Draftable logo on PDF export cover pages

### apish-converter:3.0.6
- Fix vulnerabilities in OS packages, including CVE-2026-111497 (brotli)

### apish-load-balancer:3.0.4
- Fix vulnerabilities in OS packages, including CVE-2026-111497 (brotli)
- Update base image to Alpine 3.24

---
## 2026-09-03

### apish-converter:3.0.5
- Fix path traversal in custom font installation
- Disable and lock LibreOffice macro execution
- Restrict service user write access to its logs and custom fonts
- Fix font sync removing installed fonts on transfer or Redis failure

### apish-web:3.0.9
- Reject unsafe filenames on custom font upload
- Escape font filenames in status messages
- Fix font management page refreshing indefinitely after a sync error

### docker-compose.yml
- Bind published ports to localhost: converter (8080), Redis (6379), PostgreSQL (5432) and RabbitMQ (5672). Web on 80/443 unchanged.
    - **Note:** access from other hosts will stop working. Access within the stack is unaffected.
- `REDIS_PASSWORD` is now strongly recommended: write access to Redis grants write access to the converter's font directory
- Fix Celery beat health check reporting healthy while beat was dead
- Relax Celery health check thresholds to avoid spurious unhealthy status
- Update PostgreSQL to 16.15


---
## 2026-07-01

### apish-web:3.0.8
- Updated the comparison viewer:
  - Upgraded PDF.js dependency to resolve issues with PDF rendering, specifically around annotation boxes.
  - Restored missing button styles for consistent user interface appearance.

---
## 2026-06-24

### apish-converter:3.0.4
- Dropping gosu dependency

---
## 2026-06-11

### apish-compare:3.0.3
- Fix for TLS enabled AMQP connection

### apish-converter:3.0.3
- Fix for TLS enabled Redis connection


---
## 2026-05-21

### apish-web:3.0.7
- Improve license handling:
    - Cache license data locally for deployments using non-persistent Redis.
    - Re-activate automatically when the license is updated on Draftable.
- Update dependencies to address security vulnerabilities.

### apish-load-balancer:3.0.3
- Restore iframe support for embedding the comparison UI.

---
## 2026-03-04

### apish-web:3.0.6
- Fix vulnerabilities CVE-2026-1207, CVE-2026-1287, CVE-2026-26007, CVE-2025-68973
    - Django 5.2.10 → 5.2.11
    - cryptography 46.0.3 → 46.0.5
    - Upgrade gpgv

### apish-compare:3.0.2
- Resolve issue with false positive changes in tables


---
## 2026-01-27

### apish-converter:3.0.2
- Increase maximum file size limit for document conversion input files

### docker-compose.yml
- Don't expose RabbitMQ management UI by default
- Upgrade RabbitMQ to version 4.2
    - **Note:** Upgrading will result in loss of existing queue data. Suggested upgrade procedure:
        1. Stop Web container
        2. Wait until all running comparisons complete
        3. Stop all APISH services
        4. Replace docker-compose.yml and start all services


---
## 2026-01-08

### apish-web:3.0.5
- Fix security vulnerability CVE-2025-69223
- Compatibility with Podman

### apish-load-balancer:3.0.2, docker-compose.yml
- Compatibility with Podman

### apish-compare:3.0.1
- Improve logging and error handling 

---
## 2025-12-02

### apish-web:3.0.4, docker-compose.yml
- Support for configuring S3 storage

### docker-compose.yml
- Redis improved data persistence options

---
## 2025-11-26

### apish-web:3.0.3, apish-converter:3.0.1, docker-compose.yml
- Added a script and instructions for migrating from V2 APISH container
- Support for installing custom fonts

### docker-compose.yml
- Update Redis to v8.2

---
## 2025-11-13

### apish-web:3.0.2
- Fix error 500 when accessing user account after modification

### apish-load-balancer:3.0.1
- Fix support for large input files

---
## 2025-11-06

### apish-web:3.0.1
- Fix django vulnerability CVE-2025-64459

### docker-compose.yml
- Add support for configuring REDIS_PASSWORD

---
## 2025-09-30

- Initial release of V3 API Self Hosted solution
