# payer_provider dbt Project — Architecture Map

## Summary

This document is a visual reference for the `payer_provider` dbt pipeline on Snowflake. It maps Oracle source data from Azure through three parallel environments — dev, test, and prod — each with its own database pair, schemas, role, warehouse, and Snowflake-native dbt project object. The CI/CD pipeline triggers automated runs of the test and prod dbt project objects on merge.

**Also known as / related terms:** payer_provider, dbt pipeline, Snowflake native dbt, snow dbt, CenCal dbt, provider analytics pipeline, DEV_ANALYTICS, TEST_ANALYTICS, PROD_ANALYTICS, staging intermediate marts, RBAC, incremental models, zero-copy clone

---

## Table of Contents

1. [High-Level Architecture](#1-high-level-architecture)
2. [Snowflake Environments Side-by-Side](#2-snowflake-environments-side-by-side)
3. [CI/CD Pipeline Flow](#3-cicd-pipeline-flow)
4. [DBT Model Layers](#4-dbt-model-layers)
5. [RBAC and Access Summary](#5-rbac-and-access-summary)
6. [Quick Reference Cheat Sheet](#6-quick-reference-cheat-sheet)

---

## 1. High-Level Architecture

```
┌─ AZURE ────────────────────────────────────────────────────────────────┐
│                                                                        │
│  Oracle Source Database                                                │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  prov, prov_addr, prov_language, prov_taxonomy, prv_xref,        │  │
│  │  prv_xref1, vendor, vendor_address, vendor_provider_ref,         │  │
│  │  vendor_taxonomy, prov_associate, prov_communication             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                         │
                data load to Snowflake
                         │
              ┌──────────▼──────────────────────┐
              │  PROD_RAW.ORACLE (authoritative) │
              └──────────────────────────────────┘
                   │                        │
            zero-copy clone          zero-copy clone
                   │                        │
                   ▼                        ▼
         ┌─────────────────────┐  ┌──────────────────────┐
         │  DEV_RAW.ORACLE     │  │  TEST_RAW.ORACLE      │
         └─────────────────────┘  └──────────────────────┘
                   │                        │
                   ▼                        ▼
           (see Section 2)           (see Section 2)
```

Azure hosts the Oracle source system. Data is loaded into `PROD_RAW.ORACLE`. Both `DEV_RAW` and `TEST_RAW` are zero-copy clones — dev and test get production-quality source data without storage duplication.

---

## 2. Snowflake Environments Side-by-Side

```
┌─ SNOWFLAKE ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                                                                                       │
│  ┌─ DEV ENVIRONMENT ─────────────────────────────────┐  ┌─ TEST ENVIRONMENT ────────────────────────────────┐  ┌─ PROD ENVIRONMENT ────────────────────────────────┐  │
│  │                                                   │  │                                                   │  │                                                   │  │
│  │  ┌─ Role ──────────────────────────────────────┐  │  │  ┌─ Role ──────────────────────────────────────┐  │  │  ┌─ Role ──────────────────────────────────────┐  │  │
│  │  │  DEV_ANALYTICS_ADMIN                        │  │  │  │  TEST_ANALYTICS_RW                          │  │  │  │  PROD_ANALYTICS_RW                          │  │  │
│  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │                                                   │  │                                                   │  │
│  │  ┌─ Warehouse ─────────────────────────────────┐  │  │  ┌─ Warehouse ─────────────────────────────────┐  │  │  ┌─ Warehouse ─────────────────────────────────┐  │  │
│  │  │  DEV_ANALYTICS_XS  (XSMALL)                 │  │  │  │  TEST_ANALYTICS_XS  (XSMALL)                │  │  │  │  PROD_ANALYTICS_XS  (XSMALL)                │  │  │
│  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │                                                   │  │                                                   │  │
│  │  ┌─ DEV_RAW ───────────────────────────────────┐  │  │  ┌─ TEST_RAW ──────────────────────────────────┐  │  │  ┌─ PROD_RAW ──────────────────────────────────┐  │  │
│  │  │  schema: ORACLE                             │  │  │  │  schema: ORACLE                             │  │  │  │  schema: ORACLE                             │  │  │
│  │  │  (zero-copy clone of PROD_RAW)              │  │  │  │  (zero-copy clone of PROD_RAW)              │  │  │  │  (authoritative source)                     │  │  │
│  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │
│  │                   dbt transforms                  │  │                   dbt transforms                  │  │                   dbt transforms                  │  │
│  │                         ▼                         │  │                         ▼                         │  │                         ▼                         │  │
│  │  ┌─ DEV_ANALYTICS ─────────────────────────────┐  │  │  ┌─ TEST_ANALYTICS ────────────────────────────┐  │  │  ┌─ PROD_ANALYTICS ────────────────────────────┐  │  │
│  │  │  TIMJONES_STAGING       (views)             │  │  │  │  STAGING            (views)                 │  │  │  │  STAGING            (views)                 │  │  │
│  │  │  TIMJONES_INTERMEDIATE  (incremental)       │  │  │  │  INTERMEDIATE       (incremental)           │  │  │  │  INTERMEDIATE       (incremental)           │  │  │
│  │  │  TIMJONES_MARTS         (incremental)       │  │  │  │  MARTS              (incremental)           │  │  │  │  MARTS              (incremental)           │  │  │
│  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │  └─────────────────────────────────────────────┘  │  │
│  │                                                   │  │                                                   │  │                                                   │  │
│  └───────────────────────────────────────────────────┘  └───────────────────────────────────────────────────┘  └───────────────────────────────────────────────────┘  │
│                                                                                                                                                                       │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Each environment is fully isolated: its own RAW source database, its own ANALYTICS output database, its own warehouse, and its own role. Dev schema names are user-prefixed (`TIMJONES_STAGING`, etc.) so developers do not collide in `DEV_ANALYTICS`. Test and prod use bare schema names. The test and prod service account roles are not granted to `SYSADMIN`.

**How `profiles.yml` and `env.yml` wire together:**

```
┌─ profiles.yml ─────────────────────────────────────┐    ┌─ env.yml ──────────────────────────────────────────────────┐
│  default:                                          │    │env_config:                                                 │
│    target: default                                 │    │  default_environment: dev                                  │
│    outputs:                                        │    │  environments:                                             │
│      default:                                      │    │                                                            │
│        type: snowflake                             │    │    - name: dev                                             │
│        account: ""  # resolved by CLI              │    │      env:                                                  │
│        user: ""     # resolved by CLI              │    │        DBT_CURRENT_ROLE:    DEV_ANALYTICS_ADMIN            │
│        role: "{{ env_var('DBT_CURRENT_ROLE') }}"   │    │        DBT_DATABASE:        DEV_ANALYTICS                  │
│        database: "{{ env_var('DBT_DATABASE') }}"   │    │        DBT_SOURCE_DATABASE: DEV_RAW                        │
│        warehouse: "{{ env_var('DBT_WAREHOUSE') }}" │    │        DBT_WAREHOUSE:       DEV_ANALYTICS_XS               │
│        schema: "{{ env_var('DBT_SCHEMA') }}"       │    │        DBT_SCHEMA:          DEFAULT                        │
│        threads: 4                                  │    │        DBT_ENV_SCHEMA_PREFIX: TIMJONES  # dev only         │
└────────────────────────────────────────────────────┘    │                                                            │
│                                                    │    │    - name: prod                                            │
│                                                    │    │      env:                                                  │
│                                                    │    │        DBT_CURRENT_ROLE:    PROD_ANALYTICS_RW              │
│                                                    │    │        DBT_DATABASE:        PROD_ANALYTICS                 │
│                                                    │    │        DBT_SOURCE_DATABASE: PROD_RAW                       │
│                                                    │    │        DBT_WAREHOUSE:       PROD_ANALYTICS_XS              │
│                                                    │    │        DBT_SCHEMA:          DEFAULT                        │
│                                                    │    └────────────────────────────────────────────────────────────┘
```

`profiles.yml` contains only Jinja `env_var()` references — no hardcoded credentials or database names. At runtime, `env.yml` supplies the actual values for the chosen environment. In dev, `DBT_ENV_SCHEMA_PREFIX: TIMJONES` is the key addition: it causes `generate_schema_name` to prefix your output schemas, so your models land in `TIMJONES_STAGING` instead of `STAGING`.

---

## 3. CI/CD Pipeline Flow

```
PR merged to main branch
          │
          ├──────────────────────────────────────────┐
          │                                          │
          ▼                                          ▼
┌─ Test Run ────────────────────┐    ┌─ Prod Run ────────────────────┐
│  role:      TEST_ANALYTICS_RW │    │  role:      PROD_ANALYTICS_RW │
│  user:      SVC_DBT_TEST      │    │  user:      SVC_DBT_PROD      │
│  warehouse: TEST_ANALYTICS_XS │    │  warehouse: PROD_ANALYTICS_XS │
│                               │    │                               │
│  EXECUTE DBT PROJECT          │    │  EXECUTE DBT PROJECT          │
│    payer_provider             │    │    payer_provider             │
│    ENV_CONFIG = test          │    │    ENV_CONFIG = prod          │
└───────────────────────────────┘    └───────────────────────────────┘
          │                                          │
          ▼                                          ▼
    TEST_ANALYTICS                            PROD_ANALYTICS
```

CI/CD authenticates using the environment's dedicated service account. Neither `SVC_DBT_TEST` nor `SVC_DBT_PROD` can access the other's environment. The dev dbt project object is run manually by developers — never by CI/CD. `ENV_CONFIG` selects the `env.yml` block (database, warehouse, role, schema prefix).

---

## 4. DBT Model Layers

```
┌─ Source Layer (Azure Oracle → PROD_RAW / DEV_RAW / TEST_RAW) ─────────────────────┐
│  schema: ORACLE                                                                   │
│  prov, prov_addr, prov_language, prov_taxonomy, prv_xref, prv_xref1,              │
│  vendor, vendor_address, vendor_provider_ref, vendor_taxonomy,                    │
│  prov_associate, prov_communication                                               │
└───────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─ Staging Layer ───────────────────────────────────────────────────────────────────┐
│  materialization: VIEW                                                            │
│  schema: STAGING  (or TIMJONES_STAGING in dev)                                    │
│                                                                                   │
│  stg_oracle__providers                  ← prov                                    │
│  stg_oracle__provider_addresses         ← prov_addr                               │
│  stg_oracle__provider_languages         ← prov_language                           │
│  stg_oracle__provider_taxonomies        ← prov_taxonomy                           │
│  stg_oracle__provider_xrefs             ← prv_xref / prv_xref1                    │
└───────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─ Intermediate Layer ──────────────────────────────────────────────────────────────┐
│  materialization: INCREMENTAL (merge)                                             │
│  schema: INTERMEDIATE                                                             │
│                                                                                   │
│  int_providers_enriched           ← joins + business logic over staging           │
│  int_provider_addresses_enriched  ← address normalization and enrichment          │
└───────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─ Marts Layer ─────────────────────────────────────────────────────────────────────┐
│  materialization: INCREMENTAL (merge)                                             │
│  schema: MARTS                                                                    │
│                                                                                   │
│  dim_providers                    ← final consumer-facing provider dimension      │
└───────────────────────────────────────────────────────────────────────────────────┘
```

Staging models are lightweight views — no business logic, just column renames and casts from Oracle source. Intermediate models use incremental merge to build enriched, joined datasets. Marts produce the final consumer-facing dimensional tables.

---

## 5. RBAC and Access Summary

```
┌─ Role Hierarchy ──────────────────────────────────────────────────────────────────┐
│                                                                                   │
│   SYSADMIN                                                                        │
│       │                                                                           │
│       └──► DEV_ANALYTICS_ADMIN  ──────► read/write DEV_ANALYTICS                  │
│                                         read       DEV_RAW                        │
│                                         read       PROD_ANALYTICS  (read-only)    │
│                                                                                   │
│   SVC_DBT_TEST  ──────────────────────► read/write TEST_ANALYTICS                 │
│                                         read       TEST_RAW                       │
│                                                                                   │
│   SVC_DBT_PROD  ──────────────────────► read/write PROD_ANALYTICS                 │
│                                         read       PROD_RAW                       │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

`DEV_ANALYTICS_ADMIN` is granted to `SYSADMIN` so developers can use it through their normal Snowflake session. The test and prod service account roles are held only by `SVC_DBT_TEST` and `SVC_DBT_PROD` — not granted to `SYSADMIN`. Dev also gains read access to `PROD_ANALYTICS` so developers can compare output against production.

---

## 6. Quick Reference Cheat Sheet

| Term | What It Means |
|---|---|
| **payer_provider** | The dbt project name; the Snowflake native dbt project object name |
| **DEV_RAW / TEST_RAW** | Zero-copy clones of `PROD_RAW`; no storage cost until data diverges |
| **PROD_RAW** | Authoritative Oracle source data loaded from Azure; never written to by dbt |
| **DEV_ANALYTICS** | dbt output database for developers; schemas are user-prefixed (e.g. `TIMJONES_STAGING`) |
| **TEST_ANALYTICS** | dbt output database for CI/CD test runs; bare schema names |
| **PROD_ANALYTICS** | dbt output database for production; bare schema names; CI/CD only |
| **STAGING schema** | Contains dbt staging views — lightweight renames/casts of Oracle source tables |
| **INTERMEDIATE schema** | Contains incremental merge tables — enriched, joined provider data |
| **MARTS schema** | Contains `dim_providers` — final consumer-facing dimensional output |
| **TIMJONES_ prefix** | User-specific schema prefix in dev (e.g. `TIMJONES_STAGING`) — prevents dev conflicts |
| **DBT PROJECT object** | Snowflake-native object; executed with `EXECUTE DBT PROJECT` |
| **ENV_CONFIG** | env.yml key passed to select dev / test / prod env vars |
| **DEV_ANALYTICS_ADMIN** | Developer role; granted to SYSADMIN; reads PROD_ANALYTICS for comparison |
| **TEST/PROD_ANALYTICS_RW** | CI/CD-only service account roles; not granted to SYSADMIN |
| **SVC_DBT_TEST / SVC_DBT_PROD** | Service accounts used by CI/CD pipeline; pending creation |
| **generate_schema_name** | dbt macro that applies `TIMJONES_` prefix in dev, bare names in test/prod |
| **zero-copy clone** | Snowflake feature: instant DB copy with no storage cost until data diverges |
| **incremental merge** | dbt strategy: only insert/update changed rows rather than full table rebuild |
