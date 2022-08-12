--
-- PacketFence SQL schema upgrade from 11.0 to 11.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 11;
SET @MINOR_VERSION = 3;


SET @PREV_MAJOR_VERSION = 11;
SET @PREV_MINOR_VERSION = 2;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8;

DROP PROCEDURE IF EXISTS ValidateVersion;
--
-- Updating to current version
--
DELIMITER //
CREATE PROCEDURE ValidateVersion()
BEGIN
    DECLARE PREVIOUS_VERSION int(11);
    DECLARE PREVIOUS_VERSION_STRING varchar(11);
    DECLARE _message varchar(255);
    SELECT id, version INTO PREVIOUS_VERSION, PREVIOUS_VERSION_STRING FROM pf_version ORDER BY id DESC LIMIT 1;

      IF PREVIOUS_VERSION != @PREV_VERSION_INT THEN
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'
              SET MESSAGE_TEXT = _message;
      END IF;
END
//

DELIMITER ;

ALTER DATABASE
    CHARACTER SET = 'utf8mb4'
    COLLATE = 'utf8mb4_bin';

\! echo "Checking PacketFence schema version...";
call ValidateVersion;

\! /usr/local/pf/db/upgrade-tenant-11.2-12.0.pl;
SOURCE /usr/local/pf/db/upgrade-tenant-11.2-12.0.sql;

DROP PROCEDURE IF EXISTS ValidateVersion;

ALTER TABLE security_event
   DROP CONSTRAINT security_event_tenant_id,
   DROP CONSTRAINT `tenant_id_mac_fkey_node`,
   DROP tenant_id;

ALTER TABLE ip4log
    DROP CONSTRAINT `ip4log_tenant_id`,
    DROP PRIMARY KEY,
    RENAME INDEX ip4log_tenant_id_mac_end_time TO ip4log_mac_end_time,
    ADD PRIMARY KEY (`ip`),
    DROP tenant_id;

ALTER TABLE ip4log_history
   DROP tenant_id;

ALTER TABLE ip4log_archive
   DROP tenant_id;

ALTER TABLE ip6log
   DROP CONSTRAINT `ip6log_tenant_id`,
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`ip`),
   DROP tenant_id;

ALTER TABLE ip6log_history
   DROP tenant_id;

ALTER TABLE ip6log_archive
   DROP tenant_id;

ALTER TABLE locationlog
   DROP CONSTRAINT `locationlog_tenant_id`,
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`mac`),
   DROP tenant_id;

ALTER TABLE locationlog_history
   DROP tenant_id;

ALTER TABLE password
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`pid`),
   DROP tenant_id;

ALTER TABLE bandwidth_accounting
   RENAME INDEX bandwidth_accounting_tenant_id_mac_last_updated TO bandwidth_accounting_mac_last_updated,
   DROP tenant_id
;

ALTER TABLE radius_nas
   DROP tenant_id;

ALTER TABLE radacct
   DROP tenant_id;

ALTER TABLE radacct_log
   DROP tenant_id;

ALTER TABLE radreply
   RENAME INDEX `tenant_id` TO `username`,
   DROP tenant_id;

ALTER TABLE scan
   DROP tenant_id;

ALTER TABLE activation
   DROP tenant_id;

ALTER TABLE radius_audit_log
   DROP tenant_id;

ALTER TABLE auth_log
   DROP tenant_id;

ALTER TABLE user_preference
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`pid`, `id`),
   DROP tenant_id;

ALTER TABLE dns_audit_log
   DROP tenant_id;

ALTER TABLE admin_api_audit_log
   DROP tenant_id;

ALTER TABLE bandwidth_accounting_history
   RENAME INDEX bandwidth_accounting_tenant_id_mac TO bandwidth_accounting_mac,
   DROP tenant_id;

ALTER TABLE node
   DROP CONSTRAINT `0_57`,
   DROP CONSTRAINT `node_tenant_id`,
   DROP CONSTRAINT `node_category_key`,
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`mac`),
   DROP tenant_id
;

ALTER TABLE person
   DROP CONSTRAINT `person_tenant_id`,
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`pid`),
   DROP tenant_id;

DROP TABLE tenant;

\! echo "altering sms_carrier"
ALTER TABLE sms_carrier
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

INSERT INTO sms_carrier
    (name, email_pattern, created)
  VALUES
      ('RingRing', '%s@smsemail.be', now());

--
-- Trigger to archive dhcp_option82 entries to the history table after an update
--

DROP TRIGGER IF EXISTS dhcp_option82_after_update_trigger;
DELIMITER /
CREATE TRIGGER dhcp_option82_after_update_trigger AFTER UPDATE ON dhcp_option82
FOR EACH ROW
BEGIN
    INSERT INTO dhcp_option82_history
           (
            created_at,
            mac,
            option82_switch,
            switch_id,
            port,
            vlan,
            circuit_id_string,
            module,
            host
           )
    VALUES
           (
            OLD.created_at,
            OLD.mac,
            OLD.option82_switch,
            OLD.switch_id,
            OLD.port,
            OLD.vlan,
            OLD.circuit_id_string,
            OLD.module,
            OLD.host
           );
END /
DELIMITER ;

--
-- Trigger to insert old record from 'ip4log' in 'ip4log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip4log_insert_in_ip4log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip4log_insert_in_ip4log_history_before_update_trigger BEFORE UPDATE ON ip4log
FOR EACH ROW
BEGIN
  INSERT INTO ip4log_history SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Trigger to insert old record from 'ip6log' in 'ip6log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip6log_insert_in_ip6log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip6log_insert_in_ip6log_history_before_update_trigger BEFORE UPDATE ON ip6log
FOR EACH ROW
BEGIN
  INSERT INTO ip6log_history SET ip = OLD.ip, mac = OLD.mac, type = OLD.type, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

DELIMITER /
CREATE OR REPLACE TRIGGER locationlog_insert_in_history_after_insert AFTER UPDATE on locationlog
FOR EACH ROW
BEGIN
    IF OLD.session_id <=> NEW.session_id THEN
        INSERT INTO locationlog_history
        SET
            mac = OLD.mac,
            switch = OLD.switch,
            port = OLD.port,
            vlan = OLD.vlan,
            role = OLD.role,
            connection_type = OLD.connection_type,
            connection_sub_type = OLD.connection_sub_type,
            dot1x_username = OLD.dot1x_username,
            ssid = OLD.ssid,
            start_time = OLD.start_time,
            end_time = CASE
            WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
            WHEN OLD.end_time > NOW() THEN NOW()
            ELSE OLD.end_time
            END,
            switch_ip = OLD.switch_ip,
            switch_mac = OLD.switch_mac,
            stripped_user_name = OLD.stripped_user_name,
            realm = OLD.realm,
            session_id = OLD.session_id,
            ifDesc = OLD.ifDesc,
            voip = OLD.voip
        ;
  END IF;
END /
DELIMITER ;

-- Adding RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS `acct_start`;
DELIMITER /
CREATE PROCEDURE `acct_start` (
    IN `p_acctsessionid` varchar(64),
    IN `p_acctuniqueid` varchar(32),
    IN `p_username` varchar(64),
    IN `p_realm` varchar(64),
    IN `p_nasipaddress` varchar(15),
    IN `p_nasportid` varchar(32),
    IN `p_nasporttype` varchar(32),
    IN `p_acctstarttime` datetime,
    IN `p_acctupdatetime` datetime,
    IN `p_acctstoptime` datetime,
    IN `p_acctsessiontime` int(12) unsigned,
    IN `p_acctauthentic` varchar(32),
    IN `p_connectinfo_start` varchar(50),
    IN `p_connectinfo_stop` varchar(50),
    IN `p_acctinputoctets` bigint(20) unsigned,
    IN `p_acctoutputoctets` bigint(20) unsigned,
    IN `p_calledstationid` varchar(50),
    IN `p_callingstationid` varchar(50),
    IN `p_acctterminatecause` varchar(32),
    IN `p_servicetype` varchar(32),
    IN `p_framedprotocol` varchar(32),
    IN `p_framedipaddress` varchar(15),
    IN `p_acctstatustype` varchar(25),
    IN `p_nasidentifier` varchar(64),
    IN `p_calledstationssid` varchar(64)
)
BEGIN

# We make sure there are no left over sessions for which we never received a "stop"
DECLARE `Previous_Session_Time` int(12) unsigned;
SELECT `acctsessiontime`
INTO `Previous_Session_Time`
FROM `radacct`
WHERE `acctuniqueid` = `p_acctuniqueid`
AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

IF (`Previous_Session_Time` IS NOT NULL) THEN
    UPDATE `radacct` SET
      `acctstoptime` = `p_acctstarttime`,
      `acctterminatecause` = 'UNKNOWN'
      WHERE `acctuniqueid` = `p_acctuniqueid`
      AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
END IF;

INSERT INTO `radacct`
           (
            `acctsessionid`,      `acctuniqueid`,       `username`,
            `realm`,              `nasipaddress`,       `nasportid`,
            `nasporttype`,        `acctstarttime`,      `acctupdatetime`,
            `acctstoptime`,       `acctsessiontime`,    `acctauthentic`,
            `connectinfo_start`,  `connectinfo_stop`,   `acctinputoctets`,
            `acctoutputoctets`,   `calledstationid`,    `callingstationid`,
            `acctterminatecause`, `servicetype`,        `framedprotocol`,
            `framedipaddress`,    `nasidentifier`,      `calledstationssid`
           )
VALUES
    (
    `p_acctsessionid`, `p_acctuniqueid`, `p_username`,
    `p_realm`, `p_nasipaddress`, `p_nasportid`,
    `p_nasporttype`, `p_acctstarttime`, `p_acctupdatetime`,
    `p_acctstoptime`, `p_acctsessiontime`, `p_acctauthentic`,
    `p_connectinfo_start`, `p_connectinfo_stop`, `p_acctinputoctets`,
    `p_acctoutputoctets`, `p_calledstationid`, `p_callingstationid`,
    `p_acctterminatecause`, `p_servicetype`, `p_framedprotocol`,
    `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`
    );



  INSERT INTO `radacct_log`
   (`acctsessionid`, `username`, `nasipaddress`,
    `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
  VALUES
   (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
    `p_acctstarttime`, `p_acctstatustype`, `p_acctinputoctets`, `p_acctoutputoctets`, `p_acctsessiontime`, `p_acctuniqueid`);
END /
DELIMITER ;

-- Adding RADIUS Stop Stored Procedure

DROP PROCEDURE IF EXISTS `acct_stop`;
DELIMITER /
CREATE PROCEDURE `acct_stop` (
  IN `p_timestamp` datetime,
  IN `p_framedipaddress` varchar(15),
  IN `p_acctsessiontime` int(12) unsigned,
  IN `p_acctinputoctets` bigint(20) unsigned,
  IN `p_acctoutputoctets` bigint(20) unsigned,
  IN `p_acctuniqueid` varchar(32),
  IN `p_acctsessionid` varchar(64),
  IN `p_username` varchar(64),
  IN `p_realm` varchar(64),
  IN `p_nasipaddress` varchar(15),
  IN `p_nasportid` varchar(32),
  IN `p_nasporttype` varchar(32),
  IN `p_acctauthentic` varchar(32),
  IN `p_connectinfo_stop` varchar(50),
  IN `p_calledstationid` varchar(50),
  IN `p_callingstationid` varchar(50),
  IN `p_servicetype` varchar(32),
  IN `p_framedprotocol` varchar(32),
  IN `p_acctterminatecause` varchar(12),
  IN `p_acctstatustype` varchar(25),
  IN `p_nasidentifier` varchar(64),
  IN `p_calledstationssid` varchar(64)
)
BEGIN
  DECLARE `Previous_Input_Octets` bigint(20) unsigned;
  DECLARE `Previous_Output_Octets` bigint(20) unsigned;
  DECLARE `Previous_Session_Time` int(12) unsigned;

  # Collect traffic previous values in the radacct table
  SELECT `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`
    INTO `Previous_Input_Octets`, `Previous_Output_Octets`, `Previous_Session_Time`
    FROM `radacct`
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

  # Set values to 0 when no previous records
  IF (`Previous_Session_Time` IS NOT NULL) THEN
    # Update record with new traffic
    UPDATE `radacct` SET
      `acctstoptime` = `p_timestamp`,
      `acctsessiontime` = `p_acctsessiontime`,
      `acctinputoctets` = `p_acctinputoctets`,
      `acctoutputoctets` = `p_acctoutputoctets`,
      `acctterminatecause` = `p_acctterminatecause`,
      `connectinfo_stop` = `p_connectinfo_stop`
      WHERE `acctuniqueid` = `p_acctuniqueid`
      AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);

    # Create new record in the log table
    INSERT INTO `radacct_log`
     (`acctsessionid`, `username`, `nasipaddress`,
      `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
    VALUES
     (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
     `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
     (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`);
  END IF;
END /
DELIMITER ;

-- Adding RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS `acct_update`;
DELIMITER /
CREATE PROCEDURE `acct_update`(
  IN `p_timestamp` datetime,
  IN `p_framedipaddress` varchar(15),
  IN `p_acctsessiontime` int(12) unsigned,
  IN `p_acctinputoctets` bigint(20) unsigned,
  IN `p_acctoutputoctets` bigint(20) unsigned,
  IN `p_acctuniqueid` varchar(32),
  IN `p_acctsessionid` varchar(64),
  IN `p_username` varchar(64),
  IN `p_realm` varchar(64),
  IN `p_nasipaddress` varchar(15),
  IN `p_nasportid` varchar(32),
  IN `p_nasporttype` varchar(32),
  IN `p_acctauthentic` varchar(32),
  IN `p_connectinfo_start` varchar(50),
  IN `p_calledstationid` varchar(50),
  IN `p_callingstationid` varchar(50),
  IN `p_servicetype` varchar(32),
  IN `p_framedprotocol` varchar(32),
  IN `p_acctstatustype` varchar(25),
  IN `p_nasidentifier` varchar(64),
  IN `p_calledstationssid` varchar(64)
)
BEGIN
  DECLARE `Previous_Input_Octets` bigint(20) unsigned;
  DECLARE `Previous_Output_Octets` bigint(20) unsigned;
  DECLARE `Previous_Session_Time` int(12) unsigned;
  DECLARE `Previous_AcctUpdate_Time` datetime;

  DECLARE `Opened_Sessions` int(12) unsigned;
  DECLARE `Latest_acctstarttime` datetime;
  DECLARE `cnt` int(12) unsigned;
  DECLARE `countmac` int(12) unsigned;
  SELECT count(`acctuniqueid`), max(`acctstarttime`)
  INTO `Opened_Sessions`, `Latest_acctstarttime`
  FROM `radacct`
  WHERE `acctuniqueid` = `p_acctuniqueid`
  AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);

  IF (`Opened_Sessions` > 1) THEN
      UPDATE `radacct` SET
        `acctstoptime` = NOW(),
        `acctterminatecause` = 'UNKNOWN'
        WHERE `acctuniqueid` = `p_acctuniqueid`
        AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
  END IF;
  # Detect if we receive in the same time a stop before the interim update
  SELECT COUNT(*)
  INTO `cnt`
  FROM `radacct`
  WHERE `acctuniqueid` = `p_acctuniqueid`
  AND (`acctstoptime` = `p_timestamp`);

  # If there is an old closed entry then update it
  IF (`cnt` = 1) THEN
    UPDATE `radacct` SET
        `framedipaddress` = `p_framedipaddress`,
        `acctsessiontime` = `p_acctsessiontime`,
        `acctinputoctets` = `p_acctinputoctets`,
        `acctoutputoctets` = `p_acctoutputoctets`,
        `acctupdatetime` = `p_timestamp`
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` = `p_timestamp`);
  END IF;

  #Detect if there is an radacct entry open
  SELECT count(`callingstationid`), `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctupdatetime`
    INTO `countmac`, `Previous_Input_Octets`, `Previous_Output_Octets`, `Previous_Session_Time`, `Previous_AcctUpdate_Time`
    FROM `radacct`
    WHERE (`acctuniqueid` = `p_acctuniqueid`)
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

  IF (`countmac` = 1) THEN
    # Update record with new traffic
    UPDATE `radacct` SET
        `framedipaddress` = `p_framedipaddress`,
        `acctsessiontime` = `p_acctsessiontime`,
        `acctinputoctets` = `p_acctinputoctets`,
        `acctoutputoctets` = `p_acctoutputoctets`,
        `acctupdatetime` = `p_timestamp`,
        `acctinterval` = timestampdiff( second, `Previous_AcctUpdate_Time`,  `p_timestamp`  )
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);

    INSERT INTO `radacct_log`
     (`acctsessionid`, `username`, `nasipaddress`,
      `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
    VALUES
     (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
      `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
      (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`);

  ELSE
      # If there is no open session for this, open one.
      # Set values to 0 when no previous records
      SET `Previous_Session_Time` = 0;
      SET `Previous_Input_Octets` = 0;
      SET `Previous_Output_Octets` = 0;
      SET `Previous_AcctUpdate_Time` = `p_timestamp`;
      INSERT INTO `radacct`
             (
              `acctsessionid`,`acctuniqueid`,`username`,
              `realm`,`nasipaddress`,`nasportid`,
              `nasporttype`,`acctstarttime`,
              `acctupdatetime`,`acctsessiontime`,`acctauthentic`,
              `connectinfo_start`,`acctinputoctets`,
              `acctoutputoctets`,`calledstationid`,`callingstationid`,
              `servicetype`,`framedprotocol`,
              `framedipaddress`, `nasidentifier`,
              `calledstationssid`
             )
      VALUES
          (
              `p_acctsessionid`,`p_acctuniqueid`,`p_username`,
              `p_realm`,`p_nasipaddress`,`p_nasportid`,
              `p_nasporttype`,`p_timestamp`,
              `p_timestamp`,0,`p_acctauthentic`,
              `p_connectinfo_start`,0,
              0,`p_calledstationid`,`p_callingstationid`,
              `p_servicetype`,`p_framedprotocol`,
              `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`
          );

      INSERT INTO `radacct_log`
       (`acctsessionid`, `username`, `nasipaddress`,
        `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
      VALUES
       (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
       `p_timestamp`, `p_acctstatustype`, 0, 0,
       0, `p_acctuniqueid`);

   END IF;
END /
DELIMITER ;

--
-- Trigger to delete the temp password from 'password' when deleting the pid associated with
--

DROP TRIGGER IF EXISTS password_delete_trigger;
DELIMITER /
CREATE TRIGGER password_delete_trigger AFTER DELETE ON person
FOR EACH ROW
BEGIN
  DELETE FROM `password` WHERE pid = OLD.pid;
END /
DELIMITER ;

\! echo "altering sms_carrier"
ALTER TABLE sms_carrier
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

\! echo "Removing cached realm search for all users...";
DELETE FROM user_preference WHERE id='roles::defaultSearch';

\! echo "Add index on ip4log"
ALTER TABLE ip4log ADD INDEX IF NOT EXISTS ip4log_mac_start_time (mac, start_time);

\! echo "altering pki_certs"
ALTER TABLE pki_certs
    ADD COLUMN IF NOT EXISTS `csr` BOOLEAN DEFAULT FALSE AFTER scep;

\! echo "altering node"
ALTER TABLE node
   CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering action"
ALTER TABLE action
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering activation"
ALTER TABLE activation
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering auth_log"
ALTER TABLE auth_log
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering bandwidth_accounting"
ALTER TABLE bandwidth_accounting
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering bandwidth_accounting_history"
ALTER TABLE bandwidth_accounting_history
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering billing"
ALTER TABLE billing
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering chi_cache"
ALTER TABLE chi_cache
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering class"
ALTER TABLE class
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering dhcppool"
ALTER TABLE dhcppool
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering dhcp_option82"
ALTER TABLE dhcp_option82
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering dhcp_option82_history"
ALTER TABLE dhcp_option82_history
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering dns_audit_log"
ALTER TABLE dns_audit_log
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering ip4log"
ALTER TABLE ip4log
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering ip4log_archive"
ALTER TABLE ip4log_archive
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering ip4log_history"
ALTER TABLE ip4log_history
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering ip6log"
ALTER TABLE ip6log
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering ip6log_archive"
ALTER TABLE ip6log_archive
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering ip6log_history"
ALTER TABLE ip6log_history
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering keyed"
ALTER TABLE keyed
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering key_value_storage"
ALTER TABLE key_value_storage
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering locationlog"
ALTER TABLE locationlog
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering locationlog_history"
ALTER TABLE locationlog_history
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering node_category"
ALTER TABLE node_category
    MODIFY `acls` MEDIUMTEXT NOT NULL default '',
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering password"
ALTER TABLE password
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering person"
ALTER TABLE person
    MODIFY `otp` MEDIUMTEXT NULL DEFAULT NULL,
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering pf_version"
ALTER TABLE pf_version
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering pki_cas"
ALTER TABLE pki_cas
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering pki_certs"
ALTER TABLE pki_certs
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering pki_profiles"
ALTER TABLE pki_profiles
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering pki_revoked_certs"
ALTER TABLE pki_revoked_certs
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering radacct"
ALTER TABLE radacct
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering radacct_log"
ALTER TABLE radacct_log
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering radius_audit_log"
ALTER TABLE radius_audit_log
    MODIFY reason MEDIUMTEXT NULL,
    MODIFY radius_request MEDIUMTEXT,
    MODIFY radius_reply MEDIUMTEXT,
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering radius_nas"
ALTER TABLE radius_nas
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering radreply"
ALTER TABLE radreply
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "drop savedsearch"
DROP TABLE savedsearch;

\! echo "altering scan"
ALTER TABLE scan
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering user_preference"
ALTER TABLE user_preference
    CONVERT TO CHARACTER SET utf8mb4;

\! echo "altering wrix"
ALTER TABLE wrix
    MODIFY `English_Location_Name` MEDIUMTEXT NULL DEFAULT NULL,
    CONVERT TO CHARACTER SET utf8mb4;

ALTER TABLE admin_api_audit_log
    MODIFY `request` MEDIUMTEXT;

ALTER TABLE node
   ADD FOREIGN KEY `node_category_key` (`category_id`) REFERENCES `node_category` (`category_id`),
   ADD FOREIGN KEY `0_57` (`pid`) REFERENCES `person` (`pid`) ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE security_event
    MODIFY notes MEDIUMTEXT,
    ADD CONSTRAINT `mac_fkey_node` FOREIGN KEY (`mac`) REFERENCES `node` (`mac`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONVERT TO CHARACTER SET utf8mb4;

DELIMITER /

CREATE OR REPLACE FUNCTION `FREERADIUS_DECODE`(str text) RETURNS MEDIUMTEXT CHARSET utf8mb4
    DETERMINISTIC
BEGIN
    DECLARE result text;
    DECLARE ind INT DEFAULT 0;

    SET result = str;
    WHILE ind <= 255 DO
       SET result = REPLACE(result, CONCAT('=', LPAD(LOWER(HEX(ind)), 2, 0)), CHAR(ind));
       SET result = REPLACE(result, CONCAT('=', LPAD(HEX(ind), 2, 0)), CHAR(ind));
       SET ind = ind + 1;
    END WHILE;

    RETURN result;
END /

DELIMITER ;

CREATE OR REPLACE FUNCTION ROUND_TO_HOUR (d DATETIME)
    RETURNS DATETIME DETERMINISTIC
        RETURN DATE_ADD(DATE(d), INTERVAL HOUR(d) HOUR);

CREATE OR REPLACE FUNCTION ROUND_TO_MONTH (d DATETIME)
    RETURNS DATETIME DETERMINISTIC
        RETURN DATE_ADD(DATE(d),interval -DAY(d)+1 DAY);

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";
