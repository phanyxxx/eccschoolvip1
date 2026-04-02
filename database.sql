-- ============================================================
-- Student Management System Database
-- Simplified working version for MySQL 9.1.0
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Drop existing database if exists
DROP DATABASE IF EXISTS `student_management`;

-- Create new database
CREATE DATABASE `student_management` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- Use the database
USE `student_management`;

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE `users` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(60) NOT NULL,
    `password` VARCHAR(255) NOT NULL,
    `role` ENUM('admin','student','parent') NOT NULL DEFAULT 'student',
    `student_id` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: courses
-- ============================================================
CREATE TABLE `courses` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(120) NOT NULL,
    `score_type` ENUM('bacdub','grammar','grade6','beginner','alphabets','vocabulary') NOT NULL,
    `description` TEXT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: students
-- ============================================================
CREATE TABLE `students` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `student_code` VARCHAR(20) NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `gender` ENUM('Male','Female','Other') NOT NULL,
    `age` TINYINT UNSIGNED NOT NULL,
    `dob` DATE NOT NULL,
    `pob` VARCHAR(120) NOT NULL,
    `parent_name` VARCHAR(120) NOT NULL,
    `parent_phone` VARCHAR(30) NOT NULL,
    `course_id` INT UNSIGNED NOT NULL,
    `user_id` INT UNSIGNED DEFAULT NULL,
    `status` ENUM('active','inactive') NOT NULL DEFAULT 'active',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `student_code` (`student_code`),
    KEY `course_id` (`course_id`),
    KEY `user_id` (`user_id`),
    CONSTRAINT `students_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE,
    CONSTRAINT `students_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: scores
-- ============================================================
CREATE TABLE `scores` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `student_id` INT UNSIGNED NOT NULL,
    `week_label` VARCHAR(40) NOT NULL,
    `attendance` DECIMAL(5,2) DEFAULT NULL,
    `homework` DECIMAL(5,2) DEFAULT NULL,
    `worksheet` DECIMAL(5,2) DEFAULT NULL,
    `voice_message` DECIMAL(5,2) DEFAULT NULL,
    `monthly_test` DECIMAL(5,2) DEFAULT NULL,
    `notes` TEXT,
    `recorded_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `student_id` (`student_id`),
    KEY `recorded_by` (`recorded_by`),
    CONSTRAINT `scores_ibfk_1` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`) ON DELETE CASCADE,
    CONSTRAINT `scores_ibfk_2` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE: attendance_log
-- ============================================================
CREATE TABLE `attendance_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `student_id` INT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `status` ENUM('present','absent','late','excused') NOT NULL DEFAULT 'present',
    `notes` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `student_date` (`student_id`,`date`),
    CONSTRAINT `attendance_log_ibfk_1` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ADD GENERATED COLUMNS
-- ============================================================

ALTER TABLE `scores` 
ADD COLUMN `total_score` DECIMAL(6,2) 
GENERATED ALWAYS AS (
    COALESCE(`attendance`, 0) + 
    COALESCE(`homework`, 0) + 
    COALESCE(`worksheet`, 0) + 
    COALESCE(`voice_message`, 0) + 
    COALESCE(`monthly_test`, 0)
) STORED;

ALTER TABLE `scores` 
ADD COLUMN `grade` VARCHAR(2) 
GENERATED ALWAYS AS (
    CASE
        WHEN (COALESCE(`attendance`, 0) + COALESCE(`homework`, 0) + COALESCE(`worksheet`, 0) + 
              COALESCE(`voice_message`, 0) + COALESCE(`monthly_test`, 0)) >= 45 THEN 'A'
        WHEN (COALESCE(`attendance`, 0) + COALESCE(`homework`, 0) + COALESCE(`worksheet`, 0) + 
              COALESCE(`voice_message`, 0) + COALESCE(`monthly_test`, 0)) >= 40 THEN 'B'
        WHEN (COALESCE(`attendance`, 0) + COALESCE(`homework`, 0) + COALESCE(`worksheet`, 0) + 
              COALESCE(`voice_message`, 0) + COALESCE(`monthly_test`, 0)) >= 35 THEN 'C'
        WHEN (COALESCE(`attendance`, 0) + COALESCE(`homework`, 0) + COALESCE(`worksheet`, 0) + 
              COALESCE(`voice_message`, 0) + COALESCE(`monthly_test`, 0)) >= 25 THEN 'D'
        ELSE 'F'
    END
) STORED;

-- ============================================================
-- INSERT SAMPLE DATA
-- ============================================================

-- FIX #1: All hashes below are bcrypt for 'admin123'.
-- Previously the file used Laravel's well-known hash for the
-- string "password", making every documented credential fail.
-- Re-generate with: password_hash('admin123', PASSWORD_BCRYPT)

-- Insert admin user (password: admin123)
INSERT INTO `users` (`username`, `password`, `role`) VALUES
('admin', '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'admin');

-- Insert courses
INSERT INTO `courses` (`name`, `score_type`, `description`) VALUES
('Pre Baccalaureate', 'bacdub', 'Preparation course for Baccalaureate exam'),
('English Grammar', 'grammar', 'Comprehensive English grammar course'),
('Grade 6 English', 'grade6', 'English for Grade 6 students'),
('Beginner for Kids', 'beginner', 'English basics for young learners'),
('English Alphabets', 'alphabets', 'Learn English alphabets and basic phonics'),
('Vocabulary Building', 'vocabulary', 'Expand English vocabulary');

-- Insert students
INSERT INTO `students` (`student_code`, `name`, `gender`, `age`, `dob`, `pob`, `parent_name`, `parent_phone`, `course_id`, `status`) VALUES
('STU-0001', 'Sophea Chan', 'Female', 17, '2007-03-15', 'Phnom Penh', 'Chan Makara', '012345678', 1, 'active'),
('STU-0002', 'Rathana Kim', 'Male', 16, '2008-07-22', 'Siem Reap', 'Kim Sokha', '011234567', 2, 'active'),
('STU-0003', 'Bopha Lim', 'Female', 12, '2012-01-10', 'Battambang', 'Lim Chantha', '010987654', 3, 'active'),
('STU-0004', 'Dara Chea', 'Male', 15, '2009-05-18', 'Phnom Penh', 'Chea Vannak', '098765432', 4, 'active'),
('STU-0005', 'Maly Heng', 'Female', 10, '2014-08-25', 'Kampong Cham', 'Heng Sokun', '097123456', 5, 'active');

-- Insert student users (password: admin123)
INSERT INTO `users` (`username`, `password`, `role`, `student_id`) VALUES
('sophea',  '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'student', 1),
('rathana', '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'student', 2),
('bopha',   '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'student', 3),
('dara',    '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'student', 4),
('maly',    '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'student', 5);

-- Insert parent user (password: admin123)
INSERT INTO `users` (`username`, `password`, `role`, `student_id`) VALUES
('parent1', '$2y$10$4zDvn/ecwUDqc.JhXLegVu9jiHDIdG2GNHwixsH6q668JLCFTrUgu', 'parent', 1);

-- Update students with user_id references
UPDATE `students` SET `user_id` = 2 WHERE `id` = 1;
UPDATE `students` SET `user_id` = 3 WHERE `id` = 2;
UPDATE `students` SET `user_id` = 4 WHERE `id` = 3;
UPDATE `students` SET `user_id` = 5 WHERE `id` = 4;
UPDATE `students` SET `user_id` = 6 WHERE `id` = 5;

-- Insert sample scores
INSERT INTO `scores` (`student_id`, `week_label`, `attendance`, `homework`, `worksheet`, `voice_message`, `monthly_test`, `notes`, `recorded_by`) VALUES
(1, 'Week 1', NULL, 22, NULL, NULL, 24, 'Good performance', 1),
(1, 'Week 2', NULL, 20, NULL, NULL, 23, 'Consistent improvement', 1),
(1, 'Week 3', NULL, 24, NULL, NULL, 25, 'Excellent work!', 1),
(2, 'Week 1', 5, NULL, 18, NULL, 22, 'Good attendance', 1),
(2, 'Week 2', 5, NULL, 19, NULL, 23, 'Great progress', 1),
(3, 'Week 1', 5, NULL, NULL, 18, 20, 'Good voice recording', 1),
(3, 'Week 2', 4, NULL, NULL, 19, 21, 'Improved', 1),
(4, 'Week 1', 5, NULL, 15, NULL, 18, 'Needs improvement', 1),
(5, 'Week 1', 5, NULL, NULL, 20, 22, 'Excellent', 1);

-- Insert sample attendance records
INSERT INTO `attendance_log` (`student_id`, `date`, `status`, `notes`) VALUES
(1, CURDATE(), 'present', NULL),
(2, CURDATE(), 'present', NULL),
(3, CURDATE(), 'late', 'Traffic jam'),
(4, CURDATE(), 'present', NULL),
(5, CURDATE(), 'absent', 'Sick leave');

-- ============================================================
-- CREATE ADDITIONAL INDEXES
-- ============================================================

CREATE INDEX idx_students_course_status ON students(course_id, status);
CREATE INDEX idx_students_name ON students(name);
CREATE INDEX idx_scores_student_created ON scores(student_id, created_at DESC);
CREATE INDEX idx_scores_week_label ON scores(week_label);
CREATE INDEX idx_attendance_date ON attendance_log(date);
CREATE INDEX idx_users_role ON users(role);

-- ============================================================
-- CREATE VIEWS
-- ============================================================

CREATE VIEW `v_student_latest_score` AS
SELECT 
    s.id,
    s.student_code,
    s.name,
    s.gender,
    s.age,
    c.name AS course_name,
    c.score_type,
    sc.total_score,
    sc.grade,
    sc.created_at AS latest_score_date
FROM students s
JOIN courses c ON c.id = s.course_id
LEFT JOIN scores sc ON sc.id = (
    SELECT id FROM scores 
    WHERE student_id = s.id 
    ORDER BY created_at DESC 
    LIMIT 1
)
WHERE s.status = 'active';

CREATE VIEW `v_course_statistics` AS
SELECT 
    c.id,
    c.name,
    c.score_type,
    COUNT(DISTINCT s.id) AS total_students,
    ROUND(AVG(sc.total_score), 2) AS average_score,
    COUNT(CASE WHEN sc.grade = 'A' THEN 1 END) AS grade_a_count,
    COUNT(CASE WHEN sc.grade = 'B' THEN 1 END) AS grade_b_count,
    COUNT(CASE WHEN sc.grade = 'C' THEN 1 END) AS grade_c_count,
    COUNT(CASE WHEN sc.grade = 'D' THEN 1 END) AS grade_d_count,
    COUNT(CASE WHEN sc.grade = 'F' THEN 1 END) AS grade_f_count
FROM courses c
LEFT JOIN students s ON s.course_id = c.id AND s.status = 'active'
LEFT JOIN scores sc ON sc.id = (
    SELECT id FROM scores 
    WHERE student_id = s.id 
    ORDER BY created_at DESC 
    LIMIT 1
)
GROUP BY c.id, c.name, c.score_type;

CREATE VIEW `v_attendance_summary` AS
SELECT 
    s.id AS student_id,
    s.name AS student_name,
    s.student_code,
    COUNT(CASE WHEN al.status = 'present' THEN 1 END) AS present_days,
    COUNT(CASE WHEN al.status = 'absent' THEN 1 END) AS absent_days,
    COUNT(CASE WHEN al.status = 'late' THEN 1 END) AS late_days,
    COUNT(CASE WHEN al.status = 'excused' THEN 1 END) AS excused_days,
    COUNT(*) AS total_days,
    ROUND(COUNT(CASE WHEN al.status = 'present' THEN 1 END) * 100.0 / COUNT(*), 2) AS attendance_percentage
FROM students s
LEFT JOIN attendance_log al ON al.student_id = s.id
WHERE s.status = 'active'
GROUP BY s.id, s.name, s.student_code;

CREATE VIEW `v_recent_scores` AS
SELECT 
    sc.id,
    s.name AS student_name,
    s.student_code,
    c.name AS course_name,
    sc.week_label,
    sc.total_score,
    sc.grade,
    sc.created_at,
    u.username AS recorded_by_name
FROM scores sc
JOIN students s ON s.id = sc.student_id
JOIN courses c ON c.id = s.course_id
LEFT JOIN users u ON u.id = sc.recorded_by
WHERE sc.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY sc.created_at DESC;

-- ============================================================
-- FINALIZE
-- ============================================================

SET FOREIGN_KEY_CHECKS = 1;

SELECT '========================================' AS '';
SELECT '✅ Database Setup Complete!' AS status;
SELECT '========================================' AS '';
SELECT '📊 Database Statistics:' AS '';
SELECT CONCAT('👥 Users: ', COUNT(*)) FROM users;
SELECT CONCAT('📚 Courses: ', COUNT(*)) FROM courses;
SELECT CONCAT('👨‍🎓 Students: ', COUNT(*)) FROM students;
SELECT CONCAT('📝 Scores: ', COUNT(*)) FROM scores;
SELECT CONCAT('📅 Attendance Records: ', COUNT(*)) FROM attendance_log;
SELECT '========================================' AS '';
SELECT '🔑 Test Accounts (all password: admin123):' AS '';
SELECT 'Admin:    admin / admin123' AS '';
SELECT 'Student:  sophea / admin123' AS '';
SELECT 'Parent:   parent1 / admin123' AS '';
SELECT '========================================' AS '';
