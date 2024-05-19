-- phpMyAdmin SQL Dump
-- version 3.4.10.1
-- http://www.phpmyadmin.net
--
-- Server version: 5.7.43
-- PHP Version: 5.3.3

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `Private Airport`
--
CREATE DATABASE IF NOT EXISTS `Project` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `Project`;

-- --------------------------------------------------------

--
-- Table structure for table `address`
--

DROP TABLE IF EXISTS `address`;
CREATE TABLE `address` (
  `person_national_insurance_number` bigint(20) NOT NULL,
  `house_number` int(11) NOT NULL,
  `street` varchar(80) NOT NULL,
  `city` varchar(50) NOT NULL,
  `zip_code` varchar(50) NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='address table is made to achieve 1NF in the "Person" table';

--
-- RELATIONSHIPS FOR TABLE `address`:
--   `person_national_insurance_number`
--       `person` -> `national_insurance_number`
--   `person_national_insurance_number`
--       `person` -> `national_insurance_number`
--

-- --------------------------------------------------------

--
-- Table structure for table `airplane`
--

DROP TABLE IF EXISTS `airplane`;
CREATE TABLE `airplane` (
  `reg_number` int(11) NOT NULL,
  `plane_model` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `airplane`:
--   `plane_model`
--       `plane_type` -> `model`
--   `plane_model`
--       `plane_type` -> `model`
--

-- --------------------------------------------------------

--
-- Table structure for table `can_be_piloted_by`
--

DROP TABLE IF EXISTS `can_be_piloted_by`;
CREATE TABLE `can_be_piloted_by` (
  `plane_model` varchar(50) NOT NULL,
  `pilot_licence_number` int(11) NOT NULL COMMENT 'pilot''s license number used as a PK here because it is also a unique identifier'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `can_be_piloted_by`:
--   `pilot_licence_number`
--       `pilot` -> `licence_number`
--   `plane_model`
--       `plane_type` -> `model`
--

-- --------------------------------------------------------

--
-- Table structure for table `can_be_worked_on_by`
--

DROP TABLE IF EXISTS `can_be_worked_on_by`;
CREATE TABLE `can_be_worked_on_by` (
  `employee_national_insurance_number` bigint(20) NOT NULL,
  `plane_model` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `can_be_worked_on_by`:
--   `employee_national_insurance_number`
--       `employee` -> `national_insurance_number`
--   `plane_model`
--       `plane_type` -> `model`
--

-- --------------------------------------------------------

--
-- Table structure for table `employee`
--

DROP TABLE IF EXISTS `employee`;
CREATE TABLE `employee` (
  `national_insurance_number` bigint(20) NOT NULL,
  `salary` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `employee`:
--   `national_insurance_number`
--       `person` -> `national_insurance_number`
--

-- --------------------------------------------------------

--
-- Table structure for table `flight`
--

DROP TABLE IF EXISTS `flight`;
CREATE TABLE `flight` (
  `start_time` time NOT NULL,
  `start_date` date NOT NULL,
  `plane_reg_number` int(11) NOT NULL,
  `time_length` time NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `flight`:
--   `plane_reg_number`
--       `airplane` -> `reg_number`
--

--
-- Triggers `flight`
--
DROP TRIGGER IF EXISTS `prevent_overlapping_flights`;
DELIMITER $$
CREATE TRIGGER `prevent_overlapping_flights` BEFORE INSERT ON `flight` FOR EACH ROW BEGIN
    DECLARE conflict_count INT;
    
    SELECT COUNT(*) INTO conflict_count
    FROM flight
    WHERE plane_reg_number = NEW.plane_reg_number
      AND start_date = NEW.start_date
      AND (
            (start_time <= NEW.start_time AND start_time + time_length > NEW.start_time)
          OR (start_time >= NEW.start_time AND start_time < NEW.start_time + NEW.time_length)
      );
    
    IF conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Airplane already scheduled for a flight at that time';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `flight_piloted_by`
--

DROP TABLE IF EXISTS `flight_piloted_by`;
CREATE TABLE `flight_piloted_by` (
  `flight_start_time` time NOT NULL,
  `flight_start_date` date NOT NULL,
  `pilot_licence_number` int(11) NOT NULL COMMENT 'pilot''s license number used as a PK here because it is also a unique identifier'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `flight_piloted_by`:
--   `pilot_licence_number`
--       `pilot` -> `licence_number`
--   `flight_start_time`
--       `flight` -> `start_time`
--   `flight_start_date`
--       `flight` -> `start_date`
--

--
-- Triggers `flight_piloted_by`
--
DROP TRIGGER IF EXISTS `check_pilot_authorization`;
DELIMITER $$
CREATE TRIGGER `check_pilot_authorization` BEFORE INSERT ON `flight_piloted_by` FOR EACH ROW BEGIN
    DECLARE plane_model VARCHAR(255);
    
    SELECT plane_model INTO plane_model
    FROM flight
    WHERE start_time = NEW.flight_start_time
      AND start_date = NEW.flight_start_date;
    
    IF NOT EXISTS (
        SELECT 1
        FROM can_be_piloted_by
        WHERE pilot_licence_number = NEW.pilot_licence_number
          AND plane_model = plane_model
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pilot not authorized to fly this plane type';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `prevent_overlapping_pilot_flights`;
DELIMITER $$
CREATE TRIGGER `prevent_overlapping_pilot_flights` BEFORE INSERT ON `flight_piloted_by` FOR EACH ROW BEGIN
    DECLARE conflict_count INT;
    
    SELECT COUNT(*) INTO conflict_count
    FROM flight_piloted_by
    WHERE pilot_licence_number = NEW.pilot_licence_number
      AND (
            (flight_start_time <= NEW.flight_start_time AND flight_start_time + time_length > NEW.flight_start_time)
          OR (flight_start_time >= NEW.flight_start_time AND flight_start_time < NEW.flight_start_time + (SELECT time_length FROM flight WHERE start_time = NEW.flight_start_time AND start_date = NEW.flight_start_date))
      );
    
    IF conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pilot already scheduled to fly a plane at that time';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `hangar`
--

DROP TABLE IF EXISTS `hangar`;
CREATE TABLE `hangar` (
  `h_number` int(11) NOT NULL,
  `capacity` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `hangar`:
--

-- --------------------------------------------------------

--
-- Table structure for table `person`
--

DROP TABLE IF EXISTS `person`;
CREATE TABLE `person` (
  `national_insurance_number` bigint(20) NOT NULL,
  `name` varchar(80) NOT NULL,
  `phonenumber` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `person`:
--

-- --------------------------------------------------------

--
-- Table structure for table `pilot`
--

DROP TABLE IF EXISTS `pilot`;
CREATE TABLE `pilot` (
  `national_insurance_number` bigint(20) NOT NULL,
  `licence_number` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `pilot`:
--   `national_insurance_number`
--       `person` -> `national_insurance_number`
--

-- --------------------------------------------------------

--
-- Table structure for table `planes_owned_by_during_period`
--

DROP TABLE IF EXISTS `planes_owned_by_during_period`;
CREATE TABLE `planes_owned_by_during_period` (
  `plane_reg_number` int(11) NOT NULL,
  `person_national_insurance_number` bigint(20) NOT NULL,
  `purchase_date` date NOT NULL,
  `purchased_from` int(11) DEFAULT NULL COMMENT 'Use Person''s "national insurance number" to indicate buying from a person or leave this field NULL to indicate buying from a company. There are no foreign keys in this attribute',
  `sold_to` int(11) DEFAULT NULL COMMENT 'Use buyer (sold to) Person''s "national insurance number" to indicate selling to a person or leave this field NULL to indicate selling to a company. There are no foreign keys in this attribute',
  `ownership_date` date NOT NULL
) ;

--
-- RELATIONSHIPS FOR TABLE `planes_owned_by_during_period`:
--   `person_national_insurance_number`
--       `person` -> `national_insurance_number`
--   `plane_reg_number`
--       `airplane` -> `reg_number`
--

--
-- Triggers `planes_owned_by_during_period`
--
DROP TRIGGER IF EXISTS `prevent_overlapping_ownership`;
DELIMITER $$
CREATE TRIGGER `prevent_overlapping_ownership` BEFORE INSERT ON `planes_owned_by_during_period` FOR EACH ROW BEGIN
    DECLARE conflict_count INT;
    
    SELECT COUNT(*) INTO conflict_count
    FROM planes_owned_by_during_period
    WHERE plane_reg_number = NEW.plane_reg_number
      AND ((purchase_date <= NEW.purchase_date AND purchase_date > NEW.sold_to)
          OR (purchase_date < NEW.purchase_date AND sold_to >= NEW.purchase_date));
    
    IF conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Airplane already has an existing ownership for the given period';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `set_ownership_date`;
DELIMITER $$
CREATE TRIGGER `set_ownership_date` BEFORE INSERT ON `planes_owned_by_during_period` FOR EACH ROW BEGIN
    SET NEW.ownership_date = DATE_ADD(NEW.purchase_date, INTERVAL 1 DAY);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `plane_stored_in`
--

DROP TABLE IF EXISTS `plane_stored_in`;
CREATE TABLE `plane_stored_in` (
  `plane_reg_number` int(11) NOT NULL,
  `hangar_number` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='created to achieve 2NF so h_number depends on entire PK only';

--
-- RELATIONSHIPS FOR TABLE `plane_stored_in`:
--   `plane_reg_number`
--       `airplane` -> `reg_number`
--   `hangar_number`
--       `hangar` -> `h_number`
--

-- --------------------------------------------------------

--
-- Table structure for table `plane_type`
--

DROP TABLE IF EXISTS `plane_type`;
CREATE TABLE `plane_type` (
  `model` varchar(50) NOT NULL,
  `weight` float NOT NULL,
  `capacity` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `plane_type`:
--

-- --------------------------------------------------------

--
-- Table structure for table `service`
--

DROP TABLE IF EXISTS `service`;
CREATE TABLE `service` (
  `plane_reg_number` int(11) NOT NULL,
  `s_date` date NOT NULL,
  `hours` int(11) NOT NULL,
  `next_service_within` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `service`:
--   `plane_reg_number`
--       `airplane` -> `reg_number`
--

--
-- Triggers `service`
--
DROP TRIGGER IF EXISTS `populate_next_service_date`;
DELIMITER $$
CREATE TRIGGER `populate_next_service_date` BEFORE INSERT ON `service` FOR EACH ROW BEGIN
    SET NEW.next_service_within = DATE_ADD(NEW.s_date, INTERVAL 12 MONTH);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `service_performed_by`
--

DROP TABLE IF EXISTS `service_performed_by`;
CREATE TABLE `service_performed_by` (
  `employee_national_insurance_number` bigint(20) NOT NULL,
  `s_date` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONSHIPS FOR TABLE `service_performed_by`:
--   `employee_national_insurance_number`
--       `can_be_worked_on_by` -> `employee_national_insurance_number`
--   `employee_national_insurance_number`
--       `employee` -> `national_insurance_number`
--   `s_date`
--       `service` -> `s_date`
--

--
-- Triggers `service_performed_by`
--
DROP TRIGGER IF EXISTS `check_employee_authorization`;
DELIMITER $$
CREATE TRIGGER `check_employee_authorization` BEFORE INSERT ON `service_performed_by` FOR EACH ROW BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM can_be_worked_on_by cb
        JOIN airplane a ON cb.plane_model = a.plane_model
        WHERE cb.employee_national_insurance_number = NEW.employee_national_insurance_number
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Employee not authorized to service this plane';
    END IF;
END
$$
DELIMITER ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `address`
--
ALTER TABLE `address`
  ADD PRIMARY KEY (`id`),
  ADD KEY `FOREIGN KEY` (`person_national_insurance_number`);

--
-- Indexes for table `airplane`
--
ALTER TABLE `airplane`
  ADD PRIMARY KEY (`reg_number`),
  ADD KEY `plane_model` (`plane_model`);

--
-- Indexes for table `can_be_piloted_by`
--
ALTER TABLE `can_be_piloted_by`
  ADD PRIMARY KEY (`plane_model`,`pilot_licence_number`),
  ADD KEY `pilot_license_number` (`pilot_licence_number`);

--
-- Indexes for table `can_be_worked_on_by`
--
ALTER TABLE `can_be_worked_on_by`
  ADD PRIMARY KEY (`employee_national_insurance_number`,`plane_model`),
  ADD KEY `can_be_worked_on_by_ibfk_2` (`plane_model`);

--
-- Indexes for table `employee`
--
ALTER TABLE `employee`
  ADD PRIMARY KEY (`national_insurance_number`);

--
-- Indexes for table `flight`
--
ALTER TABLE `flight`
  ADD PRIMARY KEY (`start_time`,`start_date`),
  ADD KEY `plane_reg_number` (`plane_reg_number`);

--
-- Indexes for table `flight_piloted_by`
--
ALTER TABLE `flight_piloted_by`
  ADD PRIMARY KEY (`flight_start_time`,`flight_start_date`,`pilot_licence_number`),
  ADD KEY `pilot_licence_number` (`pilot_licence_number`);

--
-- Indexes for table `hangar`
--
ALTER TABLE `hangar`
  ADD PRIMARY KEY (`h_number`);

--
-- Indexes for table `person`
--
ALTER TABLE `person`
  ADD PRIMARY KEY (`national_insurance_number`);

--
-- Indexes for table `pilot`
--
ALTER TABLE `pilot`
  ADD PRIMARY KEY (`national_insurance_number`),
  ADD UNIQUE KEY `license_number` (`licence_number`);

--
-- Indexes for table `planes_owned_by_during_period`
--
ALTER TABLE `planes_owned_by_during_period`
  ADD PRIMARY KEY (`plane_reg_number`,`person_national_insurance_number`),
  ADD KEY `planes_owned_by_national_insurance_number` (`person_national_insurance_number`);

--
-- Indexes for table `plane_stored_in`
--
ALTER TABLE `plane_stored_in`
  ADD KEY `plane_reg_number` (`plane_reg_number`),
  ADD KEY `hangar_number` (`hangar_number`);

--
-- Indexes for table `plane_type`
--
ALTER TABLE `plane_type`
  ADD PRIMARY KEY (`model`);

--
-- Indexes for table `service`
--
ALTER TABLE `service`
  ADD PRIMARY KEY (`s_date`),
  ADD KEY `service_ibfk_1` (`plane_reg_number`);

--
-- Indexes for table `service_performed_by`
--
ALTER TABLE `service_performed_by`
  ADD PRIMARY KEY (`employee_national_insurance_number`,`s_date`),
  ADD KEY `s_date` (`s_date`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `address`
--
ALTER TABLE `address`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `address`
--
ALTER TABLE `address`
  ADD CONSTRAINT `FOREIGN KEY` FOREIGN KEY (`person_national_insurance_number`) REFERENCES `person` (`national_insurance_number`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Constraints for table `airplane`
--
ALTER TABLE `airplane`
  ADD CONSTRAINT `airplane_ibfk_1` FOREIGN KEY (`plane_model`) REFERENCES `plane_type` (`model`) ON UPDATE NO ACTION;

--
-- Constraints for table `can_be_piloted_by`
--
ALTER TABLE `can_be_piloted_by`
  ADD CONSTRAINT `can_be_piloted_by_ibfk_1` FOREIGN KEY (`pilot_licence_number`) REFERENCES `pilot` (`licence_number`) ON DELETE CASCADE ON UPDATE NO ACTION,
  ADD CONSTRAINT `can_be_piloted_by_ibfk_2` FOREIGN KEY (`plane_model`) REFERENCES `plane_type` (`model`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Constraints for table `can_be_worked_on_by`
--
ALTER TABLE `can_be_worked_on_by`
  ADD CONSTRAINT `can_be_worked_on_by_ibfk_1` FOREIGN KEY (`employee_national_insurance_number`) REFERENCES `employee` (`national_insurance_number`) ON UPDATE NO ACTION,
  ADD CONSTRAINT `can_be_worked_on_by_ibfk_2` FOREIGN KEY (`plane_model`) REFERENCES `plane_type` (`model`) ON UPDATE NO ACTION;

--
-- Constraints for table `employee`
--
ALTER TABLE `employee`
  ADD CONSTRAINT `employee_ibfk_1` FOREIGN KEY (`national_insurance_number`) REFERENCES `person` (`national_insurance_number`);

--
-- Constraints for table `flight`
--
ALTER TABLE `flight`
  ADD CONSTRAINT `flight_ibfk_1` FOREIGN KEY (`plane_reg_number`) REFERENCES `airplane` (`reg_number`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Constraints for table `flight_piloted_by`
--
ALTER TABLE `flight_piloted_by`
  ADD CONSTRAINT `flight_piloted_by_ibfk_1` FOREIGN KEY (`pilot_licence_number`) REFERENCES `pilot` (`licence_number`) ON DELETE CASCADE ON UPDATE NO ACTION,
  ADD CONSTRAINT `flight_piloted_by_ibfk_2` FOREIGN KEY (`flight_start_time`,`flight_start_date`) REFERENCES `flight` (`start_time`, `start_date`);

--
-- Constraints for table `pilot`
--
ALTER TABLE `pilot`
  ADD CONSTRAINT `pilot_ibfk_1` FOREIGN KEY (`national_insurance_number`) REFERENCES `person` (`national_insurance_number`);

--
-- Constraints for table `planes_owned_by_during_period`
--
ALTER TABLE `planes_owned_by_during_period`
  ADD CONSTRAINT `planes_owned_by_national_insurance_number` FOREIGN KEY (`person_national_insurance_number`) REFERENCES `person` (`national_insurance_number`) ON DELETE CASCADE ON UPDATE NO ACTION,
  ADD CONSTRAINT `planes_owned_by_reg_number` FOREIGN KEY (`plane_reg_number`) REFERENCES `airplane` (`reg_number`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Constraints for table `plane_stored_in`
--
ALTER TABLE `plane_stored_in`
  ADD CONSTRAINT `plane_stored_in_ibfk_1` FOREIGN KEY (`plane_reg_number`) REFERENCES `airplane` (`reg_number`) ON DELETE CASCADE,
  ADD CONSTRAINT `plane_stored_in_ibfk_2` FOREIGN KEY (`hangar_number`) REFERENCES `hangar` (`h_number`);

--
-- Constraints for table `service`
--
ALTER TABLE `service`
  ADD CONSTRAINT `service_ibfk_1` FOREIGN KEY (`plane_reg_number`) REFERENCES `airplane` (`reg_number`) ON UPDATE NO ACTION;

--
-- Constraints for table `service_performed_by`
--
ALTER TABLE `service_performed_by`
  ADD CONSTRAINT `fk_authorization` FOREIGN KEY (`employee_national_insurance_number`) REFERENCES `can_be_worked_on_by` (`employee_national_insurance_number`),
  ADD CONSTRAINT `service_performed_by_ibfk_1` FOREIGN KEY (`employee_national_insurance_number`) REFERENCES `employee` (`national_insurance_number`),
  ADD CONSTRAINT `service_performed_by_ibfk_2` FOREIGN KEY (`s_date`) REFERENCES `service` (`s_date`);


--
-- Metadata
--
USE `phpmyadmin`;

--
-- Metadata for table address
--

--
-- Metadata for table airplane
--

--
-- Metadata for table can_be_piloted_by
--

--
-- Metadata for table can_be_worked_on_by
--

--
-- Metadata for table employee
--

--
-- Metadata for table flight
--

--
-- Metadata for table flight_piloted_by
--

--
-- Metadata for table hangar
--

--
-- Metadata for table person
--

--
-- Metadata for table pilot
--

--
-- Metadata for table planes_owned_by_during_period
--

--
-- Metadata for table plane_stored_in
--

--
-- Metadata for table plane_type
--

--
-- Metadata for table service
--

--
-- Metadata for table service_performed_by
--

--
-- Metadata for database Project
--

--
-- Dumping data for table `pma__relation`
--

INSERT INTO `pma__relation` (`master_db`, `master_table`, `master_field`, `foreign_db`, `foreign_table`, `foreign_field`) VALUES
('Project', 'address', 'person_national_insurance_number', 'Project', 'person', 'national_insurance_number'),
('Project', 'airplane', 'plane_model', 'Project', 'plane_type', 'model');
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
