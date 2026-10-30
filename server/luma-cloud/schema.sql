-- LUMA cloud save: database and tables (MariaDB 10.5+ / MySQL 8+).
-- Run once as the database administrator:  sudo mysql < schema.sql
-- Safe to run again after an update (only creates what is missing).
CREATE DATABASE IF NOT EXISTS luma CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE luma;

-- One row per player: every device starts as a guest; signing in with Apple, Google or
-- Facebook binds that identity to the player so the save can be restored on a new phone.
CREATE TABLE IF NOT EXISTS players (
  id          CHAR(32)     NOT NULL PRIMARY KEY,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Sign-in identities. Only the provider's stable user id is stored (no e-mail, no name).
CREATE TABLE IF NOT EXISTS identities (
  provider    VARCHAR(16)  NOT NULL,
  subject     VARCHAR(255) NOT NULL,
  player_id   CHAR(32)     NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (provider, subject),
  INDEX (player_id),
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Sign-in tokens (only their SHA-256 is stored).
CREATE TABLE IF NOT EXISTS sessions (
  token_hash  CHAR(64)     NOT NULL PRIMARY KEY,
  player_id   CHAR(32)     NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (player_id),
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Saved values per player (the game keeps its whole save under one key).
CREATE TABLE IF NOT EXISTS saves (
  player_id   CHAR(32)     NOT NULL,
  save_key    VARCHAR(64)  NOT NULL,
  value       LONGTEXT     NOT NULL,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (player_id, save_key),
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Earlier versions of a save (at most one per hour, the last 20 per player), so a save that
-- was overwritten by mistake can be put back. No foreign key: copies outlive a deleted player
-- only until the nightly clean-up in the README removes them.
CREATE TABLE IF NOT EXISTS save_backups (
  id          BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  player_id   CHAR(32)     NOT NULL,
  save_key    VARCHAR(64)  NOT NULL,
  value       LONGTEXT     NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (player_id, save_key, created_at)
) ENGINE=InnoDB;
