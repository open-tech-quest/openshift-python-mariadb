-- Open Tech Quest - database layout
-- Executed by the MariaDB entrypoint (/docker-entrypoint-initdb.d) on first start,
-- i.e. whenever the data directory is empty. Runs inside $MARIADB_DATABASE.

CREATE TABLE IF NOT EXISTS challenge (
    id          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64)   NOT NULL COMMENT 'Challenge identifier, selected by the app via CHALLENGE_NAME',
    flag        VARCHAR(128)  NOT NULL COMMENT 'Challenge flag shown on the web page',
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_challenge_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
