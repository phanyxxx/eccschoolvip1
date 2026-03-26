-- ============================================================
-- Student Management System - Database Schema
-- Version: 1.0
-- Encoding: UTF-8 (required for Khmer Unicode)
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Create database
CREATE DATABASE IF NOT EXISTS `student_management`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `student_management`;

-- ============================================================
-- Table: users (Admin / Student / Parent login accounts)
-- ============================================================
CREATE TABLE `users` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`   VARCHAR(60)  NOT NULL UNIQUE,
  `password`   VARCHAR(255) NOT NULL COMMENT 'bcrypt hash',
  `role`       ENUM('admin','student','parent') NOT NULL DEFAULT 'student',
  `student_id` INT UNSIGNED NULL COMMENT 'FK – students.id (null for admin)',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Table: courses
-- ============================================================
CREATE TABLE `courses` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(120) NOT NULL UNIQUE,
  `score_type`  ENUM('bacdub','grammar','grade6','beginner','alphabets','vocabulary') NOT NULL,
  `description` TEXT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Table: students
-- ============================================================
CREATE TABLE `students` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `student_code` VARCHAR(20)  NOT NULL UNIQUE COMMENT 'e.g. STU-0001',
  `name`         VARCHAR(120) NOT NULL,
  `gender`       ENUM('Male','Female','Other') NOT NULL,
  `age`          TINYINT UNSIGNED NOT NULL,
  `dob`          DATE NOT NULL,
  `pob`          VARCHAR(120) NOT NULL COMMENT 'Place of Birth',
  `parent_name`  VARCHAR(120) NOT NULL,
  `parent_phone` VARCHAR(30)  NOT NULL,
  `course_id`    INT UNSIGNED NOT NULL,
  `user_id`      INT UNSIGNED NULL COMMENT 'FK – users.id (login account)',
  `status`       ENUM('active','inactive') NOT NULL DEFAULT 'active',
  `created_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_students_course` FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_students_user`   FOREIGN KEY (`user_id`)   REFERENCES `users`(`id`)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Table: scores
-- Each row = one weekly / monthly score update per student
-- Fields used depend on the course's score_type
-- ============================================================
CREATE TABLE `scores` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `student_id`   INT UNSIGNED NOT NULL,
  `week_label`   VARCHAR(40)  NOT NULL COMMENT 'e.g. Week 1, Month 1',
  -- Individual components (NULL when not applicable for a score_type)
  `attendance`   DECIMAL(5,2) UNSIGNED NULL COMMENT 'Max 5',
  `homework`     DECIMAL(5,2) UNSIGNED NULL COMMENT 'Max 25 (bacdub only)',
  `worksheet`    DECIMAL(5,2) UNSIGNED NULL COMMENT 'Max 20',
  `voice_message`DECIMAL(5,2) UNSIGNED NULL COMMENT 'Max 20',
  `monthly_test` DECIMAL(5,2) UNSIGNED NULL COMMENT 'Max 25',
  `total_score`  DECIMAL(5,2) UNSIGNED GENERATED ALWAYS AS (
    COALESCE(`attendance`, 0) +
    COALESCE(`homework`, 0)   +
    COALESCE(`worksheet`, 0)  +
    COALESCE(`voice_message`, 0) +
    COALESCE(`monthly_test`, 0)
  ) STORED COMMENT 'Auto-calculated – max 50',
  `grade`        VARCHAR(2) GENERATED ALWAYS AS (
    CASE
      WHEN (COALESCE(`attendance`,0)+COALESCE(`homework`,0)+COALESCE(`worksheet`,0)+COALESCE(`voice_message`,0)+COALESCE(`monthly_test`,0)) >= 45 THEN 'A'
      WHEN (COALESCE(`attendance`,0)+COALESCE(`homework`,0)+COALESCE(`worksheet`,0)+COALESCE(`voice_message`,0)+COALESCE(`monthly_test`,0)) >= 40 THEN 'B'
      WHEN (COALESCE(`attendance`,0)+COALESCE(`homework`,0)+COALESCE(`worksheet`,0)+COALESCE(`voice_message`,0)+COALESCE(`monthly_test`,0)) >= 35 THEN 'C'
      WHEN (COALESCE(`attendance`,0)+COALESCE(`homework`,0)+COALESCE(`worksheet`,0)+COALESCE(`voice_message`,0)+COALESCE(`monthly_test`,0)) >= 25 THEN 'D'
      ELSE 'F'
    END
  ) STORED COMMENT 'Auto-calculated grade',
  `notes`        TEXT NULL,
  `recorded_by`  INT UNSIGNED NULL COMMENT 'FK – users.id (admin who entered)',
  `updated_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_scores_student` FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_scores_admin`   FOREIGN KEY (`recorded_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Table: attendance_log (daily attendance)
-- ============================================================
CREATE TABLE `attendance_log` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `student_id` INT UNSIGNED NOT NULL,
  `date`       DATE NOT NULL,
  `status`     ENUM('present','absent','late','excused') NOT NULL DEFAULT 'present',
  `notes`      VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_student_date` (`student_id`, `date`),
  CONSTRAINT `fk_att_student` FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- SEED DATA
-- ============================================================

-- Admin user  (password = admin123)
INSERT INTO `users` (`username`, `password`, `role`) VALUES
('admin', '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin');

-- Courses
INSERT INTO `courses` (`name`, `score_type`, `description`) VALUES
('ត្រៀមប្រឡងបាក់ឌុប',        'bacdub',     'Baccalaureate exam preparation – Homework (25) + Monthly Test (25)'),
('វេយ្យាករណ៍អង់គ្លេស',        'grammar',    'English Grammar – Attendance (5) + Worksheet (20) + Monthly Test (25)'),
('អង់គ្លេសថ្នាក់ទី៦',         'grade6',     'Grade 6 English – Attendance (5) + Voice Message (20) + Monthly Test (25)'),
('Beginner សម្រាប់កុមារ',    'beginner',   'Beginner for Children – Attendance (5) + Voice Message (20) + Monthly Test (25)'),
('The English Alphabets',    'alphabets',  'Alphabet course – Attendance (5) + Voice Message (20) + Monthly Test (25)'),
('The Vocabulary',           'vocabulary', 'Vocabulary – Attendance (5) + Worksheet (20) + Monthly Test (25)');

-- Sample students
INSERT INTO `students` (`student_code`,`name`,`gender`,`age`,`dob`,`pob`,`parent_name`,`parent_phone`,`course_id`) VALUES
('STU-0001','Sophea Chan','Female',17,'2007-03-15','Phnom Penh','Chan Makara','012-345-678',1),
('STU-0002','Rathana Kim','Male',16,'2008-07-22','Siem Reap','Kim Sokha','011-234-567',2),
('STU-0003','Bopha Lim','Female',12,'2012-01-10','Battambang','Lim Chantha','010-987-654',4),
('STU-0004','Piseth Mao','Male',14,'2010-09-05','Kampong Cham','Mao Rithy','093-111-222',3),
('STU-0005','Sreymom Heng','Female',11,'2013-05-18','Takeo','Heng Vanna','096-333-444',5),
('STU-0006','Virak Phan','Male',15,'2009-11-30','Kandal','Phan Sophat','085-555-666',6);

-- Sample scores
INSERT INTO `scores` (`student_id`,`week_label`,`homework`,`monthly_test`,`attendance`,`worksheet`,`voice_message`,`recorded_by`) VALUES
(1,'Month 1',22,24,NULL,NULL,NULL,1),
(1,'Month 2',20,23,NULL,NULL,NULL,1),
(2,'Month 1',NULL,22,5,18,NULL,1),
(2,'Month 2',NULL,24,4,19,NULL,1),
(3,'Month 1',NULL,20,5,NULL,17,1),
(4,'Month 1',NULL,21,4,NULL,18,1),
(5,'Month 1',NULL,23,5,NULL,19,1),
(6,'Month 1',NULL,20,4,17,NULL,1);

-- ============================================================
-- Useful views
-- ============================================================
CREATE OR REPLACE VIEW `v_student_latest_score` AS
  SELECT
    s.id,
    s.student_code,
    s.name,
    s.gender,
    s.age,
    c.name      AS course,
    sc.total_score,
    sc.grade,
    sc.week_label,
    sc.updated_at AS score_updated_at
  FROM students s
  JOIN courses c  ON c.id = s.course_id
  LEFT JOIN scores sc ON sc.id = (
    SELECT id FROM scores WHERE student_id = s.id ORDER BY created_at DESC LIMIT 1
  );

SET FOREIGN_KEY_CHECKS = 1;

-- End of schema
