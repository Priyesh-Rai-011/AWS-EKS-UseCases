CREATE TABLE IF NOT EXISTS users (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(100)        NOT NULL,
    email      VARCHAR(150) UNIQUE NOT NULL,
    password   VARCHAR(255)        NOT NULL,
    verified   BOOLEAN             NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP           NOT NULL DEFAULT NOW()
);

INSERT INTO users (name, email, password, verified) VALUES
    ('Alice',   'alice@test.com',   'password123', TRUE),
    ('Bob',     'bob@test.com',     'password123', TRUE),
    ('Charlie', 'charlie@test.com', 'password123', TRUE);
