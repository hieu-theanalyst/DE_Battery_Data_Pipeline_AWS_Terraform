-- =====================================================================
-- RDS PostgreSQL: application / OLTP schema
-- Backs the upload web app: who's allowed to upload, and metadata about
-- each battery-test file that's been uploaded (before it moves into the
-- S3 -> Lambda -> Glue -> Redshift analytics pipeline).
-- =====================================================================

DROP TABLE IF EXISTS upload_users;
DROP TABLE IF EXISTS admin_users;

CREATE TABLE admin_users (
    id       VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,  -- store a hash (e.g. bcrypt), never plaintext
    role     INTEGER NOT NULL
);

CREATE TABLE upload_users (
    id              VARCHAR(255) PRIMARY KEY,
    filename        VARCHAR(255) NOT NULL,
    exportDate      DATE,
    testDate        DATE,
    testProtocol    TEXT,
    scap            INTEGER,
    cRate           FLOAT,
    comment         TEXT,
    fileURL         TEXT,
    procedure       TEXT,
    cathodeMass     FLOAT,
    activeMass      FLOAT,
    adjustmentrate  FLOAT,
    uploaderId      VARCHAR(255),
    CONSTRAINT fk_uploader
        FOREIGN KEY (uploaderId)
        REFERENCES admin_users (id)
        ON DELETE CASCADE
);

CREATE INDEX idx_upload_users_uploader ON upload_users (uploaderId);
