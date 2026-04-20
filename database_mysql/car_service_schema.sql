-- Schema-only file generated from car_service_db.sql
-- Includes tables, indexes, primary keys, and foreign keys

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS=0;

DROP TABLE IF EXISTS `appointments`;
CREATE TABLE `appointments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `scheduled_at` datetime NOT NULL,
  `status` varchar(20) NOT NULL,
  `contact_customer_id` int DEFAULT NULL,
  `work_order_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_appointments_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_appointments_contact_customer_id` FOREIGN KEY (`contact_customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_appointments_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  KEY `idx_appointments_vehicle_scheduled` (`vehicle_id`,`scheduled_at`),
  CONSTRAINT `chk_appointments_status_domain` CHECK ((`status` in ('planned','confirmed','done','missed'))),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `assembly_kits`;
CREATE TABLE `assembly_kits` (
  `id` int NOT NULL AUTO_INCREMENT,
  `kit_name` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3071 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `audit_logs`;
CREATE TABLE `audit_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `action` varchar(255) DEFAULT NULL,
  `logged_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_audit_logs_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `backorders`;
CREATE TABLE `backorders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int NOT NULL,
  `customer_id` int NOT NULL,
  `qty` int NOT NULL DEFAULT 1,
  `status` varchar(20) NOT NULL DEFAULT 'open',
  `warehouse_id` int DEFAULT NULL,
  `reason_code` varchar(50) DEFAULT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_backorders_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_backorders_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  KEY `idx_backorders_created_at` (`created_at`),
  CONSTRAINT `fk_backorders_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_backorders_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_backorders_qty_positive` CHECK ((`qty` > 0)),
  CONSTRAINT `chk_backorders_status_domain` CHECK ((`status` in ('open','fulfilled','cancelled'))),
  KEY `idx_backorders_part_id` (`part_id`),
  KEY `idx_backorders_customer_id` (`customer_id`),
  KEY `idx_backorders_warehouse_id` (`warehouse_id`),
  KEY `idx_backorders_status` (`status`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `barcode_logs`;
CREATE TABLE `barcode_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int DEFAULT NULL,
  `last_scan` datetime DEFAULT NULL,
  `scanned_by_employee_id` int DEFAULT NULL,
  `scan_type` varchar(30) NOT NULL DEFAULT 'generic',
  `occurred_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_barcode_logs_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  KEY `idx_barcode_logs_occurred_at` (`occurred_at`),
  CONSTRAINT `fk_barcode_logs_scanned_by_employee_id` FOREIGN KEY (`scanned_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_barcode_logs_scan_type_domain` CHECK ((`scan_type` in ('inbound','outbound','inventory_count','generic'))),
  KEY `idx_barcode_logs_part_id` (`part_id`),
  KEY `idx_barcode_logs_scanned_by_employee_id` (`scanned_by_employee_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `battery_tests`;
CREATE TABLE `battery_tests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `voltage` decimal(5,2) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_battery_tests_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_battery_tests_voltage_non_negative` CHECK ((`voltage` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `blacklist`;
CREATE TABLE `blacklist` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `reason` text,
  CONSTRAINT `fk_blacklist_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `body_types`;
CREATE TABLE `body_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  UNIQUE KEY `uk_body_types_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `brake_checks`;
CREATE TABLE `brake_checks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `pad_wear` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_brake_checks_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_brake_checks_work_order_id` (`work_order_id`),
  CONSTRAINT `chk_brake_checks_pad_wear_range` CHECK ((`pad_wear` between 0 and 100)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `candidates`;
CREATE TABLE `candidates` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `position_id` int NOT NULL,
  CONSTRAINT `fk_candidates_position_id` FOREIGN KEY (`position_id`) REFERENCES `roles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `car_brands`;
CREATE TABLE `car_brands` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  UNIQUE KEY `uk_car_brands_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=191 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `car_colors`;
CREATE TABLE `car_colors` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  UNIQUE KEY `uk_car_colors_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `car_generations`;
CREATE TABLE `car_generations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `model_id` int NOT NULL,
  `year_start` int DEFAULT NULL,
  CONSTRAINT `fk_car_generations_model_id` FOREIGN KEY (`model_id`) REFERENCES `car_models` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_car_generations_model_year_start` (`model_id`,`year_start`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6143 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `car_models`;
CREATE TABLE `car_models` (
  `id` int NOT NULL AUTO_INCREMENT,
  `brand_id` int NOT NULL,
  `name` varchar(50) NOT NULL,
  CONSTRAINT `fk_car_models_brand_id` FOREIGN KEY (`brand_id`) REFERENCES `car_brands` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_car_models_brand_name` (`brand_id`,`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1535 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `car_rentals`;
CREATE TABLE `car_rentals` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `courtesy_car_id` int NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_car_rentals_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_car_rentals_courtesy_car_id` FOREIGN KEY (`courtesy_car_id`) REFERENCES `courtesy_cars` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `certifications`;
CREATE TABLE `certifications` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `training_id` int NOT NULL,
  CONSTRAINT `fk_certifications_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_certifications_training_id` FOREIGN KEY (`training_id`) REFERENCES `trainings` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_certifications_employee_training` (`employee_id`,`training_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `checklist_items`;
CREATE TABLE `checklist_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `list_id` int NOT NULL,
  `task_name` varchar(100) NOT NULL,
  CONSTRAINT `fk_checklist_items_list_id` FOREIGN KEY (`list_id`) REFERENCES `job_checklists` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_checklist_items_list_task` (`list_id`,`task_name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10239 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `checklist_results`;
CREATE TABLE `checklist_results` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `item_id` int NOT NULL,
  `is_ok` tinyint(1) DEFAULT NULL,
  CONSTRAINT `fk_checklist_results_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_checklist_results_item_id` FOREIGN KEY (`item_id`) REFERENCES `checklist_items` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `client_signatures`;
CREATE TABLE `client_signatures` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `signature_path` text,
  CONSTRAINT `fk_client_signatures_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_client_signatures_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `consumables`;
CREATE TABLE `consumables` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `unit` varchar(10) DEFAULT NULL,
  `category_id` int DEFAULT NULL,
  CONSTRAINT `fk_consumables_category_id` FOREIGN KEY (`category_id`) REFERENCES `part_categories` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=767 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `courtesy_cars`;
CREATE TABLE `courtesy_cars` (
  `id` int NOT NULL AUTO_INCREMENT,
  `model_id` int NOT NULL,
  `is_available` tinyint(1) DEFAULT NULL,
  CONSTRAINT `fk_courtesy_cars_model_id` FOREIGN KEY (`model_id`) REFERENCES `car_models` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=133118 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `customer_addresses`;
CREATE TABLE `customer_addresses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `city` varchar(50) DEFAULT NULL,
  `address` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_customer_addresses_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  KEY `idx_customer_addresses_customer_id` (`customer_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `customer_groups`;
CREATE TABLE `customer_groups` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `discount` decimal(5,2) NOT NULL DEFAULT 0.00,
  UNIQUE KEY `uk_customer_groups_name` (`name`),
  CONSTRAINT `chk_customer_groups_discount_non_negative` CHECK ((`discount` >= 0)),
  CONSTRAINT `chk_customer_groups_discount_max` CHECK ((`discount` <= 100)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `customer_notes`;
CREATE TABLE `customer_notes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `note` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_customer_notes_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  KEY `idx_customer_notes_customer_id` (`customer_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `customers`;
CREATE TABLE `customers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `group_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_customers_group_id` FOREIGN KEY (`group_id`) REFERENCES `customer_groups` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_customers_email` (`email`),
  KEY `idx_customers_group_id` (`group_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `damage_reports`;
CREATE TABLE `damage_reports` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `details` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_damage_reports_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `delivery_logs`;
CREATE TABLE `delivery_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `po_id` int NOT NULL,
  `arrival_time` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_delivery_logs_po_id` FOREIGN KEY (`po_id`) REFERENCES `purchase_orders` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `diagnostics`;
CREATE TABLE `diagnostics` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `fault_codes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_diagnostics_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_diagnostics_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `ecu_firmware`;
CREATE TABLE `ecu_firmware` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `version` varchar(50) DEFAULT NULL,
  CONSTRAINT `fk_ecu_firmware_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `emissions_tests`;
CREATE TABLE `emissions_tests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `co2_level` decimal(10,2) DEFAULT NULL,
  CONSTRAINT `fk_emissions_tests_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_emissions_tests_co2_non_negative` CHECK ((`co2_level` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `chat_channels`;
CREATE TABLE `chat_channels` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_chat_channels_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_chat_channels_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `chat_threads`;
CREATE TABLE `chat_threads` (
  `id` int NOT NULL AUTO_INCREMENT,
  `channel_id` int NOT NULL,
  `subject` varchar(200) DEFAULT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_chat_threads_channel_id` FOREIGN KEY (`channel_id`) REFERENCES `chat_channels` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_chat_threads_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  UNIQUE KEY `uk_chat_threads_channel_subject` (`channel_id`,`subject`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `employee_chats`;
CREATE TABLE `employee_chats` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sender_id` int NOT NULL,
  `message` text,
  `recipient_id` int DEFAULT NULL,
  `thread_id` int DEFAULT NULL,
  `sent_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `read_at` datetime DEFAULT NULL,
  `message_type` enum('direct','thread','system') NOT NULL DEFAULT 'system',
  CONSTRAINT `fk_employee_chats_sender_id` FOREIGN KEY (`sender_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_employee_chats_recipient_id` FOREIGN KEY (`recipient_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_employee_chats_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `chat_threads` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_employee_chats_message_mode` CHECK (((`message_type` = 'direct' AND `recipient_id` IS NOT NULL AND `thread_id` IS NULL) OR (`message_type` = 'thread' AND `recipient_id` IS NULL AND `thread_id` IS NOT NULL) OR (`message_type` = 'system' AND `recipient_id` IS NULL AND `thread_id` IS NULL))),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `employees`;
CREATE TABLE `employees` (
  `id` int NOT NULL AUTO_INCREMENT,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `role_id` int DEFAULT NULL,
  CONSTRAINT `fk_employees_role_id` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=163838 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `engines`;
CREATE TABLE `engines` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `volume` decimal(3,1) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_engines_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_engines_vehicle_id` (`vehicle_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `equivalents`;
CREATE TABLE `equivalents` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id_1` int DEFAULT NULL,
  `part_id_2` int DEFAULT NULL,
  CONSTRAINT `fk_equivalents_part_id_1` FOREIGN KEY (`part_id_1`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_equivalents_part_id_2` FOREIGN KEY (`part_id_2`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_equivalents_pair` (`part_id_1`,`part_id_2`),
  CONSTRAINT `chk_equivalents_canonical` CHECK ((`part_id_1` < `part_id_2`)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `estimate_requests`;
CREATE TABLE `estimate_requests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `description` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_estimate_requests_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `expenses`;
CREATE TABLE `expenses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `amount` decimal(12,2) DEFAULT NULL,
  `category` varchar(50) DEFAULT NULL,
  `organization_id` int DEFAULT NULL,
  CONSTRAINT `fk_expenses_organization_id` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_expenses_amount_non_negative` CHECK ((`amount` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `feedback`;
CREATE TABLE `feedback` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `rating` int NOT NULL,
  `comment` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_feedback_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_feedback_rating_range` CHECK ((`rating` between 1 and 5)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `fluid_checks`;
CREATE TABLE `fluid_checks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `oil_status` varchar(20) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_fluid_checks_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_fluid_checks_oil_status_domain` CHECK ((`oil_status` in ('ok','low','replace','critical'))),
  UNIQUE KEY `uk_fluid_checks_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `fuel_types`;
CREATE TABLE `fuel_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  UNIQUE KEY `uk_fuel_types_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `glass_repairs`;
CREATE TABLE `glass_repairs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `glass_type` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_glass_repairs_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `incidents`;
CREATE TABLE `incidents` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `description` text,
  CONSTRAINT `fk_incidents_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `inspection_logs`;
CREATE TABLE `inspection_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `inspection_date` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_inspection_logs_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `insurance_policies`;
CREATE TABLE `insurance_policies` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `provider` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_insurance_policies_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `interviews`;
CREATE TABLE `interviews` (
  `id` int NOT NULL AUTO_INCREMENT,
  `candidate_id` int DEFAULT NULL,
  `interview_time` datetime DEFAULT NULL,
  CONSTRAINT `fk_interviews_candidate_id` FOREIGN KEY (`candidate_id`) REFERENCES `candidates` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `inventory`;
CREATE TABLE `inventory` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int NOT NULL,
  `warehouse_id` int NOT NULL,
  `quantity` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_inventory_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_inventory_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_inventory_part_warehouse` (`part_id`,`warehouse_id`),
  KEY `idx_inventory_warehouse_id` (`warehouse_id`),
  CONSTRAINT `chk_inventory_quantity_non_negative` CHECK ((`quantity` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `inventory_audits`;
CREATE TABLE `inventory_audits` (
  `id` int NOT NULL AUTO_INCREMENT,
  `audit_date` date DEFAULT NULL,
  `auditor_name` varchar(100) DEFAULT NULL,
  `warehouse_id` int DEFAULT NULL,
  `auditor_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_inventory_audits_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_inventory_audits_auditor_id` FOREIGN KEY (`auditor_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_inventory_audits_auditor_source` CHECK (((`auditor_id` IS NOT NULL) <> (`auditor_name` IS NOT NULL))),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `invoices`;
CREATE TABLE `invoices` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `invoice_num` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_invoices_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_invoices_invoice_num` (`invoice_num`),
  UNIQUE KEY `uk_invoices_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `job_checklists`;
CREATE TABLE `job_checklists` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  UNIQUE KEY `uk_job_checklists_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=639 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `job_types`;
CREATE TABLE `job_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `standard_hours` decimal(5,2) DEFAULT NULL,
  UNIQUE KEY `uk_job_types_name` (`name`),
  CONSTRAINT `chk_job_types_standard_hours_non_negative` CHECK ((`standard_hours` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=767 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `kit_parts`;
CREATE TABLE `kit_parts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `kit_id` int NOT NULL,
  `part_id` int NOT NULL,
  CONSTRAINT `fk_kit_parts_kit_id` FOREIGN KEY (`kit_id`) REFERENCES `assembly_kits` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_kit_parts_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_kit_parts_kit_part` (`kit_id`,`part_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `loyalty_cards`;
CREATE TABLE `loyalty_cards` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `points` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_loyalty_cards_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_loyalty_cards_customer_id` (`customer_id`),
  CONSTRAINT `chk_loyalty_cards_points_non_negative` CHECK ((`points` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `marketing_consents`;
CREATE TABLE `marketing_consents` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `email_ok` tinyint(1) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_marketing_consents_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_marketing_consents_customer_id` (`customer_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `order_jobs`;
CREATE TABLE `order_jobs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `job_type_id` int NOT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  CONSTRAINT `fk_order_jobs_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_order_jobs_job_type_id` FOREIGN KEY (`job_type_id`) REFERENCES `job_types` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_order_jobs_work_order_job_type` (`work_order_id`,`job_type_id`),
  KEY `idx_order_jobs_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `order_status_logs`;
CREATE TABLE `order_status_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `old_status` varchar(20) DEFAULT NULL,
  `new_status` varchar(20) DEFAULT NULL,
  CONSTRAINT `fk_order_status_logs_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE CASCADE,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `organizations`;
CREATE TABLE `organizations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `tax_id` varchar(50) DEFAULT NULL,
  UNIQUE KEY `uk_organizations_tax_id` (`tax_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2047 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `paint_jobs`;
CREATE TABLE `paint_jobs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `paint_code` varchar(20) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_paint_jobs_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `part_categories`;
CREATE TABLE `part_categories` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  UNIQUE KEY `uk_part_categories_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=383 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `part_prices`;
CREATE TABLE `part_prices` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int NOT NULL,
  `retail_price` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_part_prices_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_part_prices_retail_price_non_negative` CHECK ((`retail_price` >= 0)),
  UNIQUE KEY `uk_part_prices_part_id` (`part_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `part_returns`;
CREATE TABLE `part_returns` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int NOT NULL,
  `reason` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `qty` int NOT NULL DEFAULT 1,
  `returned_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `warehouse_id` int DEFAULT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  CONSTRAINT `fk_part_returns_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_part_returns_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_part_returns_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_part_returns_qty_positive` CHECK ((`qty` > 0)),
  KEY `idx_part_returns_part_id` (`part_id`),
  KEY `idx_part_returns_returned_at` (`returned_at`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `parts`;
CREATE TABLE `parts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sku` varchar(50) NOT NULL,
  `name` varchar(200) NOT NULL,
  `brand` varchar(50) DEFAULT NULL,
  `category_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_parts_category_id` FOREIGN KEY (`category_id`) REFERENCES `part_categories` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_parts_sku` (`sku`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `parts_in_repair`;
CREATE TABLE `parts_in_repair` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `part_id` int NOT NULL,
  `qty` int DEFAULT NULL,
  CONSTRAINT `fk_parts_in_repair_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_parts_in_repair_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_parts_in_repair_work_order_part` (`work_order_id`,`part_id`),
  KEY `idx_parts_in_repair_work_order_id` (`work_order_id`),
  CONSTRAINT `chk_parts_in_repair_qty_positive` CHECK ((`qty` > 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `payments`;
CREATE TABLE `payments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `invoice_id` int NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `method` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_payments_invoice_id` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`id`) ON DELETE RESTRICT,
  KEY `idx_payments_invoice_id` (`invoice_id`),
  CONSTRAINT `chk_payments_amount_non_negative` CHECK ((`amount` >= 0)),
  CONSTRAINT `chk_payments_method_domain` CHECK ((`method` in ('cash','card','online','transfer'))),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `payroll`;
CREATE TABLE `payroll` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `pay_date` date NOT NULL,
  `pay_period_start` date DEFAULT NULL,
  `pay_period_end` date DEFAULT NULL,
  CONSTRAINT `fk_payroll_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_payroll_amount_non_negative` CHECK ((`amount` >= 0)),
  UNIQUE KEY `uk_payroll_employee_pay_date` (`employee_id`,`pay_date`),
  CONSTRAINT `chk_payroll_period_order` CHECK (((`pay_period_start` IS NULL OR `pay_period_end` IS NULL) OR (`pay_period_start` <= `pay_period_end`))),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `performance`;
CREATE TABLE `performance` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `score` int DEFAULT NULL,
  `review_period` varchar(30) DEFAULT NULL,
  `reviewed_at` date DEFAULT NULL,
  CONSTRAINT `fk_performance_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_performance_score_range` CHECK ((`score` between 0 and 100)),
  UNIQUE KEY `uk_performance_employee_review_period` (`employee_id`,`review_period`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `po_items`;
CREATE TABLE `po_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `po_id` int NOT NULL,
  `part_id` int NOT NULL,
  `qty` int NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_po_items_po_id` FOREIGN KEY (`po_id`) REFERENCES `purchase_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_po_items_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_po_items_po_part` (`po_id`,`part_id`),
  CONSTRAINT `chk_po_items_qty_positive` CHECK ((`qty` > 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `purchase_orders`;
CREATE TABLE `purchase_orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int NOT NULL,
  `order_date` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_purchase_orders_supplier_id` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE RESTRICT,
  KEY `idx_purchase_orders_supplier_id` (`supplier_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `quality_controls`;
CREATE TABLE `quality_controls` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `passed` tinyint(1) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_quality_controls_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_quality_controls_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `referrals`;
CREATE TABLE `referrals` (
  `id` int NOT NULL AUTO_INCREMENT,
  `referrer_id` int NOT NULL,
  `referee_id` int NOT NULL,
  CONSTRAINT `fk_referrals_referrer_id` FOREIGN KEY (`referrer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_referrals_referee_id` FOREIGN KEY (`referee_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_referrals_referrer_referee` (`referrer_id`,`referee_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `roadside_assistance`;
CREATE TABLE `roadside_assistance` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `call_time` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_roadside_assistance_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `roles`;
CREATE TABLE `roles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(50) NOT NULL,
  UNIQUE KEY `uk_roles_title` (`title`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `schedules`;
CREATE TABLE `schedules` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `shift_start` time DEFAULT NULL,
  `shift_end` time DEFAULT NULL,
  `shift_date` date DEFAULT NULL,
  CONSTRAINT `fk_schedules_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  KEY `idx_schedules_employee_shift_date` (`employee_id`,`shift_date`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `scrap_heap`;
CREATE TABLE `scrap_heap` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int NOT NULL,
  `weight` decimal(10,2) DEFAULT NULL,
  `warehouse_id` int DEFAULT NULL,
  `reason_code` varchar(50) DEFAULT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_scrap_heap_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_scrap_heap_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_scrap_heap_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_scrap_heap_weight_non_negative` CHECK ((`weight` >= 0)),
  KEY `idx_scrap_heap_created_at` (`created_at`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `service_reminders`;
CREATE TABLE `service_reminders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `next_due` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `reminder_type` varchar(50) NOT NULL DEFAULT 'general',
  CONSTRAINT `fk_service_reminders_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  KEY `idx_service_reminders_customer_type_due` (`customer_id`,`reminder_type`,`next_due`),
  UNIQUE KEY `uk_service_reminders_customer_type_due` (`customer_id`,`reminder_type`,`next_due`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `settings`;
CREATE TABLE `settings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(50) NOT NULL,
  `setting_value` text,
  `organization_id` int DEFAULT NULL,
  CONSTRAINT `fk_settings_organization_id` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_settings_org_setting_key` (`organization_id`,`setting_key`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `shelf_locations`;
CREATE TABLE `shelf_locations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `warehouse_id` int NOT NULL,
  `shelf_code` varchar(20) NOT NULL,
  CONSTRAINT `fk_shelf_locations_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_shelf_locations_warehouse_shelf` (`warehouse_id`,`shelf_code`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `specialties`;
CREATE TABLE `specialties` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `specialty` varchar(50) NOT NULL,
  CONSTRAINT `fk_specialties_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_specialties_employee_specialty` (`employee_id`,`specialty`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `stock_adjustments`;
CREATE TABLE `stock_adjustments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `part_id` int NOT NULL,
  `change_qty` int NOT NULL,
  `warehouse_id` int DEFAULT NULL,
  `reason_code` varchar(50) DEFAULT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_stock_adjustments_part_id` FOREIGN KEY (`part_id`) REFERENCES `parts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_stock_adjustments_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_stock_adjustments_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_stock_adjustments_change_qty_non_zero` CHECK ((`change_qty` IS NOT NULL)),
  KEY `idx_stock_adjustments_created_at` (`created_at`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `subcontract_work`;
CREATE TABLE `subcontract_work` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `partner_name` varchar(100) DEFAULT NULL,
  `partner_id` int DEFAULT NULL,
  CONSTRAINT `fk_subcontract_work_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_subcontract_work_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `organizations` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_subcontract_work_partner_source` CHECK (((`partner_id` IS NOT NULL) <> (`partner_name` IS NOT NULL))),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `supplier_ratings`;
CREATE TABLE `supplier_ratings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int NOT NULL,
  `rating` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `rated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `rated_by_employee_id` int DEFAULT NULL,
  CONSTRAINT `fk_supplier_ratings_supplier_id` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_supplier_ratings_rating_range` CHECK ((`rating` between 1 and 5)),
  KEY `idx_supplier_ratings_supplier_rated_at` (`supplier_id`,`rated_at`),
  CONSTRAINT `fk_supplier_ratings_rated_by_employee_id` FOREIGN KEY (`rated_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `suppliers`;
CREATE TABLE `suppliers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  KEY `idx_suppliers_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16383 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `suspension_checks`;
CREATE TABLE `suspension_checks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `notes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_suspension_checks_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_suspension_checks_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `technical_bulletins`;
CREATE TABLE `technical_bulletins` (
  `id` int NOT NULL AUTO_INCREMENT,
  `model_id` int NOT NULL,
  `issue` text,
  CONSTRAINT `fk_technical_bulletins_model_id` FOREIGN KEY (`model_id`) REFERENCES `car_models` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `time_off`;
CREATE TABLE `time_off` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  CONSTRAINT `fk_time_off_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_time_off_date_order` CHECK ((`start_date` <= `end_date`)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `tire_service`;
CREATE TABLE `tire_service` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `tire_pressure` varchar(10) DEFAULT NULL,
  CONSTRAINT `fk_tire_service_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `tire_sets`;
CREATE TABLE `tire_sets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `season` varchar(10) DEFAULT NULL,
  CONSTRAINT `fk_tire_sets_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_tire_sets_season_domain` CHECK ((`season` in ('summer','winter','all'))),
  UNIQUE KEY `uk_tire_sets_vehicle_season` (`vehicle_id`,`season`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `tire_storage`;
CREATE TABLE `tire_storage` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `location_code` varchar(20) DEFAULT NULL,
  CONSTRAINT `fk_tire_storage_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `tool_loans`;
CREATE TABLE `tool_loans` (
  `id` int NOT NULL AUTO_INCREMENT,
  `tool_id` int NOT NULL,
  `employee_id` int NOT NULL,
  `loan_date` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_tool_loans_tool_id` FOREIGN KEY (`tool_id`) REFERENCES `tools` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_tool_loans_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `tools`;
CREATE TABLE `tools` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `serial_number` varchar(50) NOT NULL,
  UNIQUE KEY `uk_tools_serial_number` (`serial_number`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=32767 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `trainings`;
CREATE TABLE `trainings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `course_name` varchar(100) NOT NULL,
  `provider` varchar(100) DEFAULT NULL,
  UNIQUE KEY `uk_trainings_course_provider` (`course_name`,`provider`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=767 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `transmissions`;
CREATE TABLE `transmissions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  UNIQUE KEY `uk_transmissions_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `uniforms`;
CREATE TABLE `uniforms` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `issue_date` date DEFAULT NULL,
  CONSTRAINT `fk_uniforms_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `valet_logs`;
CREATE TABLE `valet_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `location` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_valet_logs_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `vehicle_photos`;
CREATE TABLE `vehicle_photos` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `url` text,
  CONSTRAINT `fk_vehicle_photos_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  KEY `idx_vehicle_photos_vehicle_id` (`vehicle_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `vehicle_specs`;
CREATE TABLE `vehicle_specs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `weight` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_vehicle_specs_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_vehicle_specs_vehicle_id` (`vehicle_id`),
  CONSTRAINT `chk_vehicle_specs_weight_non_negative` CHECK ((`weight` >= 0)),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `vehicles`;
CREATE TABLE `vehicles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `vin` char(17) NOT NULL,
  `plate` varchar(15) DEFAULT NULL,
  `car` varchar(45) DEFAULT NULL COMMENT 'Legacy display field; canonical catalog reference is generation_id',
  `brand_id` int DEFAULT NULL COMMENT 'Optional denormalized brand cache; derive from generation_id when set',
  `body_type_id` int DEFAULT NULL,
  `color_id` int DEFAULT NULL,
  `fuel_type_id` int DEFAULT NULL,
  `transmission_id` int DEFAULT NULL,
  `generation_id` int DEFAULT NULL COMMENT 'Canonical catalog link to car_generations',
  `model_year` smallint DEFAULT NULL,
  `odometer` int DEFAULT NULL,
  `notes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_vehicles_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_vehicles_body_type_id` FOREIGN KEY (`body_type_id`) REFERENCES `body_types` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_vehicles_color_id` FOREIGN KEY (`color_id`) REFERENCES `car_colors` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_vehicles_fuel_type_id` FOREIGN KEY (`fuel_type_id`) REFERENCES `fuel_types` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_vehicles_transmission_id` FOREIGN KEY (`transmission_id`) REFERENCES `transmissions` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_vehicles_generation_id` FOREIGN KEY (`generation_id`) REFERENCES `car_generations` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_vehicles_vin` (`vin`),
  KEY `idx_vehicles_customer_id` (`customer_id`),
  KEY `idx_vehicles_generation_id` (`generation_id`),
  CONSTRAINT `fk_vehicles_brand_id` FOREIGN KEY (`brand_id`) REFERENCES `car_brands` (`id`) ON DELETE RESTRICT,
  KEY `idx_vehicles_plate` (`plate`),
  CONSTRAINT `chk_vehicles_odometer_non_negative` CHECK ((`odometer` >= 0)),
  CONSTRAINT `chk_vehicles_catalog_reference` CHECK (((`generation_id` IS NOT NULL) OR (`brand_id` IS NOT NULL) OR (`car` IS NOT NULL))),
  PRIMARY KEY (`id`),
  KEY `idx_vehicles_brand_id` (`brand_id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `warehouses`;
CREATE TABLE `warehouses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `location` text,
  KEY `idx_warehouses_name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=191 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `warranty_claims`;
CREATE TABLE `warranty_claims` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `description` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_warranty_claims_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `wheel_alignments`;
CREATE TABLE `wheel_alignments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `work_order_id` int NOT NULL,
  `alignment_data` json DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_wheel_alignments_work_order_id` FOREIGN KEY (`work_order_id`) REFERENCES `work_orders` (`id`) ON DELETE RESTRICT,
  UNIQUE KEY `uk_wheel_alignments_work_order_id` (`work_order_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `work_hours`;
CREATE TABLE `work_hours` (
  `id` int NOT NULL AUTO_INCREMENT,
  `employee_id` int NOT NULL,
  `clock_in` datetime NOT NULL,
  `clock_out` datetime NOT NULL,
  CONSTRAINT `fk_work_hours_employee_id` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_work_hours_time_order` CHECK ((`clock_out` >= `clock_in`)),
  KEY `idx_work_hours_clock_in` (`clock_in`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `work_orders`;
CREATE TABLE `work_orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vehicle_id` int NOT NULL,
  `assigned_mechanic_id` int DEFAULT NULL,
  `status` varchar(20) NOT NULL,
  `total_cost` decimal(12,2) DEFAULT NULL,
  `opened_at` datetime DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL,
  `odometer` int DEFAULT NULL,
  `complaint` text,
  `diagnosis_summary` text,
  `customer_approval_status` varchar(30) DEFAULT NULL,
  `created_by_employee_id` int DEFAULT NULL,
  `service_advisor_id` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_work_orders_vehicle_id` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_work_orders_assigned_mechanic_id` FOREIGN KEY (`assigned_mechanic_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_work_orders_created_by_employee_id` FOREIGN KEY (`created_by_employee_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_work_orders_service_advisor_id` FOREIGN KEY (`service_advisor_id`) REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  KEY `idx_work_orders_vehicle_status` (`vehicle_id`,`status`),
  KEY `idx_work_orders_employee_status` (`assigned_mechanic_id`,`status`),
  CONSTRAINT `chk_work_orders_total_cost_non_negative` CHECK ((`total_cost` >= 0)),
  CONSTRAINT `chk_work_orders_odometer_non_negative` CHECK ((`odometer` >= 0)),
  CONSTRAINT `chk_work_orders_status_domain` CHECK ((`status` in ('new','in_progress','waiting_parts','completed','cancelled'))),
  CONSTRAINT `chk_work_orders_customer_approval_status_domain` CHECK (((`customer_approval_status` IS NULL) OR (`customer_approval_status` in ('pending','approved','rejected')))),
  CONSTRAINT `chk_work_orders_close_after_open` CHECK (((`opened_at` IS NULL OR `closed_at` IS NULL) OR (`closed_at` >= `opened_at`))),
  KEY `idx_work_orders_service_advisor_id` (`service_advisor_id`),
  KEY `idx_work_orders_created_by_employee_id` (`created_by_employee_id`),
  KEY `idx_work_orders_opened_at` (`opened_at`),
  KEY `idx_work_orders_status` (`status`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=262141 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS=1;
