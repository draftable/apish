# Changelog

All notable changes to the Apish project components will be documented in this file.

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
