-- Controls which schema models land in.
--
-- prod / test: bare schema names — environments are isolated by database.
--   STAGING, INTERMEDIATE, MARTS
--
-- dev: user-prefixed schemas so multiple developers share DEV_ANALYTICS without colliding.
--   COCO_STAGING, COCO_INTERMEDIATE, COCO_MARTS
--   ALICE_STAGING, ALICE_INTERMEDIATE, ALICE_MARTS
--
-- The source schema (ORACLE) is NEVER prefixed — it is shared within DEV_RAW.
-- Only the output schemas (STAGING, INTERMEDIATE, MARTS) receive the prefix.
--
-- Prefix is driven by DBT_ENV_SCHEMA_PREFIX in env.yml:
--   dev  → DBT_ENV_SCHEMA_PREFIX = CURRENT_USER()
--   test → (not set — bare schema names)
--   prod → (not set — bare schema names)
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set env_prefix = env_var('DBT_ENV_SCHEMA_PREFIX', '') | trim -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif env_prefix != '' -%}
        {{ env_prefix }}_{{ custom_schema_name | trim }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
