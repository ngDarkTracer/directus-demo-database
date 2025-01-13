FROM postgres:16.4
# Installer l'extension pg_cron
RUN apt-get update && apt-get install -y postgresql-contrib
# Copie et Execute les scripts d'initialisation de la bd au démarrage du docker
COPY ./init-db/init.sql /docker-entrypoint-initdb.d/