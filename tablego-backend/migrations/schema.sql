-- TableGo Database Schema - Module 1: Utilisateur
-- Run this file first, then seeds/seed.sql

CREATE DATABASE IF NOT EXISTS tablego CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tablego;

-- USERS
CREATE TABLE IF NOT EXISTS users (
  id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email               VARCHAR(255) NOT NULL UNIQUE,
  password_hash       VARCHAR(255) NOT NULL,
  user_type           ENUM('client','restaurant') NOT NULL DEFAULT 'client',
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  reset_token         VARCHAR(255) NULL,
  reset_token_expires DATETIME NULL,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- CLIENT PROFILES
CREATE TABLE IF NOT EXISTS client_profiles (
  id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id             INT UNSIGNED NOT NULL UNIQUE,
  full_name           VARCHAR(255) NULL,
  phone               VARCHAR(30)  NULL,
  photo_url           VARCHAR(512) NULL,
  dietary_preferences JSON NULL,
  allergies           JSON NULL,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_cp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- RESTAURANT PROFILES
CREATE TABLE IF NOT EXISTS restaurant_profiles (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id       INT UNSIGNED NOT NULL UNIQUE,
  name          VARCHAR(255) NULL,
  address       VARCHAR(512) NULL,
  latitude      DECIMAL(10,8) NULL,
  longitude     DECIMAL(11,8) NULL,
  opening_hours JSON NULL,
  cuisine_type  VARCHAR(100) NULL,
  photos        JSON NULL,
  description   TEXT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_rp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- DISHES
CREATE TABLE IF NOT EXISTS dishes (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  restaurant_id INT UNSIGNED NOT NULL,
  name          VARCHAR(255) NOT NULL,
  description   TEXT NULL,
  price         DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  photo_url     VARCHAR(512) NULL,
  is_available  BOOLEAN NOT NULL DEFAULT TRUE,
  tags          JSON NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_dish_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant_profiles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- FAVORITE RESTAURANTS
CREATE TABLE IF NOT EXISTS favorite_restaurants (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id       INT UNSIGNED NOT NULL,
  restaurant_id INT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fav_resto (user_id, restaurant_id),
  CONSTRAINT fk_fr_user       FOREIGN KEY (user_id)       REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_fr_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant_profiles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- FAVORITE DISHES
CREATE TABLE IF NOT EXISTS favorite_dishes (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  dish_id    INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fav_dish (user_id, dish_id),
  CONSTRAINT fk_fd_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_fd_dish FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ORDER HISTORY (for recommendations)
CREATE TABLE IF NOT EXISTS order_history (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id       INT UNSIGNED NOT NULL,
  restaurant_id INT UNSIGNED NOT NULL,
  dish_id       INT UNSIGNED NULL,
  ordered_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_oh_user       FOREIGN KEY (user_id)       REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_oh_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurant_profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_oh_dish       FOREIGN KEY (dish_id)       REFERENCES dishes(id) ON DELETE SET NULL
) ENGINE=InnoDB;
