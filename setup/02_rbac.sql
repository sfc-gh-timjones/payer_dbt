-- =============================================================
-- Analytics dbt Project — RBAC Setup
-- Run as ACCOUNTADMIN
-- =============================================================
-- Naming conventions follow the Snowflake environments guide:
--
-- Databases:   {ENV}_{PROJECT}
--   PROD_ANALYTICS  PROD_RAW
--   TEST_ANALYTICS  TEST_RAW
--   DEV_ANALYTICS   DEV_RAW
--
-- Warehouses:  {ENV}_{WORKLOAD}_{SIZE}
--   PROD_ANALYTICS_XS  TEST_ANALYTICS_XS  DEV_ANALYTICS_XS
--
-- Roles:       {ENV}_{DATABASE}_{PRIVILEGE}
--   PROD_ANALYTICS_RW   ← write to PROD_ANALYTICS, read from PROD_RAW  (CI/CD only)
--   TEST_ANALYTICS_RW   ← write to TEST_ANALYTICS, read from TEST_RAW  (CI/CD only)
--   DEV_ANALYTICS_ADMIN ← write to DEV_ANALYTICS,  read from DEV_RAW   (developers)
--
-- Service accounts:  SVC_{SYSTEM}_{ENV}
--   SVC_DBT_PROD  SVC_DBT_TEST
--
-- NOTE ON ACCOUNTADMIN AND SECURITY BOUNDARIES:
-- ACCOUNTADMIN is a Snowflake superuser — it can grant any role
-- to any user at any time, including PROD_ANALYTICS_RW and TEST_ANALYTICS_RW.
-- There is no technical control that prevents ACCOUNTADMIN from bypassing CI/CD.
-- The protection is organizational:
--   1. Limit ACCOUNTADMIN to 2-3 trusted individuals. Developers should never have it.
--   2. Use a break-glass pattern — store ACCOUNTADMIN credentials in a secrets vault.
--   3. Alert on ACCOUNTADMIN DML against PROD_ANALYTICS or TEST_ANALYTICS via
--      SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY.
-- Not granting TEST/PROD roles to SYSADMIN guards against accidental access
-- by admins, but is a guardrail, not a hard boundary.
-- =============================================================

USE ROLE ACCOUNTADMIN;

-- -------------------------------------------------------------
-- 1. CREATE ROLES
-- -------------------------------------------------------------
CREATE ROLE IF NOT EXISTS PROD_ANALYTICS_RW
    COMMENT = 'dbt prod — write PROD_ANALYTICS, read PROD_RAW (CI/CD only)';

CREATE ROLE IF NOT EXISTS TEST_ANALYTICS_RW
    COMMENT = 'dbt test — write TEST_ANALYTICS, read TEST_RAW (CI/CD only)';

CREATE ROLE IF NOT EXISTS DEV_ANALYTICS_ADMIN
    COMMENT = 'dbt dev — write DEV_ANALYTICS, read DEV_RAW (developers)';

-- DEV role under SYSADMIN for normal admin management.
-- TEST and PROD roles are intentionally NOT granted to SYSADMIN —
-- granting them would allow any SYSADMIN user to write directly to test/prod.
GRANT ROLE DEV_ANALYTICS_ADMIN TO ROLE SYSADMIN;

-- -------------------------------------------------------------
-- 2. CREATE DATABASES  (if not already created)
-- -------------------------------------------------------------
-- Raw Oracle ingestion databases
CREATE DATABASE IF NOT EXISTS PROD_RAW
    COMMENT = 'Raw Oracle ingestion — production source of truth';
CREATE DATABASE IF NOT EXISTS TEST_RAW
    COMMENT = 'Raw Oracle data for test environment — zero-copy clone of PROD_RAW';
CREATE DATABASE IF NOT EXISTS DEV_RAW
    COMMENT = 'Raw Oracle data for dev environment — zero-copy clone of PROD_RAW';

-- Analytics transformation databases
CREATE DATABASE IF NOT EXISTS PROD_ANALYTICS
    COMMENT = 'dbt production — STAGING / INTERMEDIATE / MARTS';
CREATE DATABASE IF NOT EXISTS TEST_ANALYTICS
    COMMENT = 'dbt test — CI/CD pre-prod validation';
CREATE DATABASE IF NOT EXISTS DEV_ANALYTICS
    COMMENT = 'dbt dev — shared; developer output schemas are user-prefixed';

-- Schema structure inside each raw DB (run for each environment)
-- CREATE SCHEMA IF NOT EXISTS PROD_RAW.ORACLE;
-- CREATE SCHEMA IF NOT EXISTS TEST_RAW.ORACLE CLONE PROD_RAW.ORACLE;
-- CREATE SCHEMA IF NOT EXISTS DEV_RAW.ORACLE  CLONE PROD_RAW.ORACLE;

-- Schema structure inside each analytics DB
-- CREATE SCHEMA IF NOT EXISTS PROD_ANALYTICS.STAGING;
-- CREATE SCHEMA IF NOT EXISTS PROD_ANALYTICS.INTERMEDIATE;
-- CREATE SCHEMA IF NOT EXISTS PROD_ANALYTICS.MARTS;
-- (same pattern for TEST_ANALYTICS and DEV_ANALYTICS)

-- -------------------------------------------------------------
-- 3. RAW schema READ access for all dbt roles
-- -------------------------------------------------------------
-- DEV_ANALYTICS_ADMIN: reads DEV_RAW.ORACLE
GRANT USAGE  ON DATABASE DEV_RAW                                  TO ROLE DEV_ANALYTICS_ADMIN;
GRANT USAGE  ON SCHEMA   DEV_RAW.ORACLE                           TO ROLE DEV_ANALYTICS_ADMIN;
GRANT SELECT ON ALL TABLES    IN SCHEMA DEV_RAW.ORACLE            TO ROLE DEV_ANALYTICS_ADMIN;
GRANT SELECT ON FUTURE TABLES IN SCHEMA DEV_RAW.ORACLE            TO ROLE DEV_ANALYTICS_ADMIN;

-- DEV_ANALYTICS_ADMIN also gets read-only on PROD_ANALYTICS to compare results
GRANT USAGE  ON DATABASE PROD_ANALYTICS                           TO ROLE DEV_ANALYTICS_ADMIN;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE PROD_ANALYTICS         TO ROLE DEV_ANALYTICS_ADMIN;
GRANT SELECT ON ALL TABLES     IN DATABASE PROD_ANALYTICS         TO ROLE DEV_ANALYTICS_ADMIN;
GRANT SELECT ON ALL VIEWS      IN DATABASE PROD_ANALYTICS         TO ROLE DEV_ANALYTICS_ADMIN;
GRANT SELECT ON FUTURE TABLES  IN DATABASE PROD_ANALYTICS         TO ROLE DEV_ANALYTICS_ADMIN;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE PROD_ANALYTICS         TO ROLE DEV_ANALYTICS_ADMIN;

-- TEST_ANALYTICS_RW: reads TEST_RAW.ORACLE
GRANT USAGE  ON DATABASE TEST_RAW                                 TO ROLE TEST_ANALYTICS_RW;
GRANT USAGE  ON SCHEMA   TEST_RAW.ORACLE                          TO ROLE TEST_ANALYTICS_RW;
GRANT SELECT ON ALL TABLES    IN SCHEMA TEST_RAW.ORACLE           TO ROLE TEST_ANALYTICS_RW;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TEST_RAW.ORACLE           TO ROLE TEST_ANALYTICS_RW;

-- PROD_ANALYTICS_RW: reads PROD_RAW.ORACLE
GRANT USAGE  ON DATABASE PROD_RAW                                 TO ROLE PROD_ANALYTICS_RW;
GRANT USAGE  ON SCHEMA   PROD_RAW.ORACLE                          TO ROLE PROD_ANALYTICS_RW;
GRANT SELECT ON ALL TABLES    IN SCHEMA PROD_RAW.ORACLE           TO ROLE PROD_ANALYTICS_RW;
GRANT SELECT ON FUTURE TABLES IN SCHEMA PROD_RAW.ORACLE           TO ROLE PROD_ANALYTICS_RW;

-- -------------------------------------------------------------
-- 4. DEV_ANALYTICS — full write for DEV_ANALYTICS_ADMIN
--    dbt creates user-prefixed schemas dynamically (COCO_STAGING etc.)
-- -------------------------------------------------------------
GRANT USAGE         ON DATABASE DEV_ANALYTICS                     TO ROLE DEV_ANALYTICS_ADMIN;
GRANT CREATE SCHEMA ON DATABASE DEV_ANALYTICS                     TO ROLE DEV_ANALYTICS_ADMIN;
GRANT ALL ON FUTURE SCHEMAS  IN DATABASE DEV_ANALYTICS            TO ROLE DEV_ANALYTICS_ADMIN;
GRANT ALL ON FUTURE TABLES   IN DATABASE DEV_ANALYTICS            TO ROLE DEV_ANALYTICS_ADMIN;
GRANT ALL ON FUTURE VIEWS    IN DATABASE DEV_ANALYTICS            TO ROLE DEV_ANALYTICS_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE DEV_ANALYTICS                TO ROLE DEV_ANALYTICS_ADMIN;
GRANT ALL ON ALL TABLES  IN DATABASE DEV_ANALYTICS                TO ROLE DEV_ANALYTICS_ADMIN;
GRANT ALL ON ALL VIEWS   IN DATABASE DEV_ANALYTICS                TO ROLE DEV_ANALYTICS_ADMIN;

-- -------------------------------------------------------------
-- 5. TEST_ANALYTICS — full write for TEST_ANALYTICS_RW (CI/CD only)
-- -------------------------------------------------------------
GRANT USAGE         ON DATABASE TEST_ANALYTICS                    TO ROLE TEST_ANALYTICS_RW;
GRANT CREATE SCHEMA ON DATABASE TEST_ANALYTICS                    TO ROLE TEST_ANALYTICS_RW;
GRANT ALL ON FUTURE SCHEMAS  IN DATABASE TEST_ANALYTICS           TO ROLE TEST_ANALYTICS_RW;
GRANT ALL ON FUTURE TABLES   IN DATABASE TEST_ANALYTICS           TO ROLE TEST_ANALYTICS_RW;
GRANT ALL ON FUTURE VIEWS    IN DATABASE TEST_ANALYTICS           TO ROLE TEST_ANALYTICS_RW;
GRANT ALL ON ALL SCHEMAS IN DATABASE TEST_ANALYTICS               TO ROLE TEST_ANALYTICS_RW;
GRANT ALL ON ALL TABLES  IN DATABASE TEST_ANALYTICS               TO ROLE TEST_ANALYTICS_RW;
GRANT ALL ON ALL VIEWS   IN DATABASE TEST_ANALYTICS               TO ROLE TEST_ANALYTICS_RW;

-- -------------------------------------------------------------
-- 6. PROD_ANALYTICS — full write for PROD_ANALYTICS_RW (CI/CD only)
-- -------------------------------------------------------------
GRANT USAGE         ON DATABASE PROD_ANALYTICS                    TO ROLE PROD_ANALYTICS_RW;
GRANT CREATE SCHEMA ON DATABASE PROD_ANALYTICS                    TO ROLE PROD_ANALYTICS_RW;
GRANT ALL ON FUTURE SCHEMAS  IN DATABASE PROD_ANALYTICS           TO ROLE PROD_ANALYTICS_RW;
GRANT ALL ON FUTURE TABLES   IN DATABASE PROD_ANALYTICS           TO ROLE PROD_ANALYTICS_RW;
GRANT ALL ON FUTURE VIEWS    IN DATABASE PROD_ANALYTICS           TO ROLE PROD_ANALYTICS_RW;
GRANT ALL ON ALL SCHEMAS IN DATABASE PROD_ANALYTICS               TO ROLE PROD_ANALYTICS_RW;
GRANT ALL ON ALL TABLES  IN DATABASE PROD_ANALYTICS               TO ROLE PROD_ANALYTICS_RW;
GRANT ALL ON ALL VIEWS   IN DATABASE PROD_ANALYTICS               TO ROLE PROD_ANALYTICS_RW;

-- -------------------------------------------------------------
-- 7. WAREHOUSES — one per environment
-- -------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS PROD_ANALYTICS_XS
    WAREHOUSE_SIZE=XSMALL WAREHOUSE_TYPE=STANDARD AUTO_SUSPEND=30 AUTO_RESUME=TRUE
    INITIALLY_SUSPENDED=TRUE COMMENT='dbt production analytics warehouse';
CREATE WAREHOUSE IF NOT EXISTS TEST_ANALYTICS_XS
    WAREHOUSE_SIZE=XSMALL WAREHOUSE_TYPE=STANDARD AUTO_SUSPEND=30 AUTO_RESUME=TRUE
    INITIALLY_SUSPENDED=TRUE COMMENT='dbt test analytics warehouse (CI/CD)';
CREATE WAREHOUSE IF NOT EXISTS DEV_ANALYTICS_XS
    WAREHOUSE_SIZE=XSMALL WAREHOUSE_TYPE=STANDARD AUTO_SUSPEND=30 AUTO_RESUME=TRUE
    INITIALLY_SUSPENDED=TRUE COMMENT='dbt dev analytics warehouse';

GRANT USAGE ON WAREHOUSE PROD_ANALYTICS_XS TO ROLE PROD_ANALYTICS_RW;
GRANT USAGE ON WAREHOUSE TEST_ANALYTICS_XS TO ROLE TEST_ANALYTICS_RW;
GRANT USAGE ON WAREHOUSE DEV_ANALYTICS_XS  TO ROLE DEV_ANALYTICS_ADMIN;

-- -------------------------------------------------------------
-- 8. CI/CD SERVICE ACCOUNTS — SVC_{SYSTEM}_{ENV}
--    Uncomment and replace with your actual CI/CD user names
-- -------------------------------------------------------------
-- CREATE USER IF NOT EXISTS SVC_DBT_PROD
--     DEFAULT_ROLE = PROD_ANALYTICS_RW DEFAULT_WAREHOUSE = PROD_ANALYTICS_XS
--     COMMENT = 'dbt CI/CD service account for production runs';
-- GRANT ROLE PROD_ANALYTICS_RW TO USER SVC_DBT_PROD;
--
-- CREATE USER IF NOT EXISTS SVC_DBT_TEST
--     DEFAULT_ROLE = TEST_ANALYTICS_RW DEFAULT_WAREHOUSE = TEST_ANALYTICS_XS
--     COMMENT = 'dbt CI/CD service account for test runs';
-- GRANT ROLE TEST_ANALYTICS_RW TO USER SVC_DBT_TEST;

-- -------------------------------------------------------------
-- 9. GRANT DEV_ANALYTICS_ADMIN TO DEVELOPERS
--    Repeat for each developer
-- -------------------------------------------------------------
-- GRANT ROLE DEV_ANALYTICS_ADMIN TO USER TIMJONES;
-- GRANT ROLE DEV_ANALYTICS_ADMIN TO USER ALICE;

-- -------------------------------------------------------------
-- 10. REFRESH RAW CLONES (nightly or on-demand)
--     Keeps dev/test raw data in sync with production.
--     Zero-copy — no storage cost until data diverges.
-- -------------------------------------------------------------
-- CREATE OR REPLACE SCHEMA TEST_RAW.ORACLE CLONE PROD_RAW.ORACLE;
-- CREATE OR REPLACE SCHEMA DEV_RAW.ORACLE  CLONE PROD_RAW.ORACLE;

-- -------------------------------------------------------------
-- VERIFICATION
-- -------------------------------------------------------------
-- SHOW GRANTS ON DATABASE DEV_ANALYTICS;
-- SHOW GRANTS ON DATABASE PROD_ANALYTICS;
-- SHOW GRANTS TO ROLE DEV_ANALYTICS_ADMIN;
