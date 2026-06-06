-- ============================================================
-- Susin App — Support Tickets Database
-- Deploy on Hostinger (separate domain e.g. support.susingroup.com)
-- ============================================================

CREATE DATABASE IF NOT EXISTS u601352558_support
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE u601352558_support;

-- ------------------------------------------------------------
-- Support tickets (created from mobile app / web)
-- user_id = Central Users ID (integer stored as string)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS support_tickets (
    id CHAR(36) NOT NULL PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    user_email VARCHAR(255) NULL,
    user_name VARCHAR(255) NULL,
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    attachment VARCHAR(512) NULL,
    status ENUM('open', 'in-progress', 'resolved') NOT NULL DEFAULT 'open',
    priority ENUM('low', 'medium', 'high', 'urgent') NOT NULL DEFAULT 'medium',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Replies / comments on tickets
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticket_replies (
    id CHAR(36) NOT NULL PRIMARY KEY,
    ticket_id CHAR(36) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    user_name VARCHAR(255) NULL,
    message TEXT NOT NULL,
    attachment VARCHAR(512) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ticket_id (ticket_id),
    CONSTRAINT fk_ticket_replies_ticket
        FOREIGN KEY (ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Optional: seed admin view (no rows required)
-- ------------------------------------------------------------
-- INSERT INTO support_tickets (...) VALUES (...);
