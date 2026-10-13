{{
    config(
        materialized='incremental',
        unique_key='prov_rec_id',
        incremental_strategy='merge'
    )
}}

-- DIM_PROVIDER: one row per provider.
-- Joins PROV with taxonomy (primary specialty), language (primary language),
-- and PRV_XREF1 (NPI number).
--
-- Incremental strategy: merge on PROV_REC_ID.
-- On each run we pick up rows whose PROV LAST_MODIFIED_DATE is newer than
-- the most recent DW_LOAD_DATE already in this table.

with prov as (

    select * from {{ ref('stg_oracle__providers') }}

    {% if is_incremental() %}
    -- Only process providers updated since the last dbt run
    where try_to_timestamp(last_modified_date, 'YYYY-MM-DD HH24:MI:SS')
          > (select coalesce(max(dw_load_date), '1900-01-01'::timestamp_ntz)
             from {{ this }})
    {% endif %}

),

-- One taxonomy per provider: prefer PRIMARY_FLAG = TRUE, then most-recent eff_date
taxonomy as (

    select
        prov_rec_id,
        taxonomy_code,
        eff_date as taxonomy_eff_date
    from {{ ref('stg_oracle__provider_taxonomies') }}
    qualify row_number() over (
        partition by prov_rec_id
        order by primary_flag desc, eff_date desc
    ) = 1

),

-- One language per provider: most-recent eff_date
lang as (

    select
        prov_rec_id,
        prov_language,
        proficiency
    from {{ ref('stg_oracle__provider_languages') }}
    qualify row_number() over (
        partition by prov_rec_id
        order by eff_date desc
    ) = 1

),

-- NPI from cross-reference table: active NPI records, most-recent first
npi_xref as (

    select
        prov_rec_id,
        reference_number as npi
    from {{ ref('stg_oracle__provider_xrefs') }}
    where xref_type = 'NPI'
      and active = true
    qualify row_number() over (
        partition by prov_rec_id
        order by eff_date desc
    ) = 1

),

final as (

    select
        -- Surrogate key: using PROV_REC_ID directly as the SK for this first pass
        p.prov_rec_id                       as provider_sk,
        p.prov_rec_id,
        p.prov_id,
        p.prov_type,
        p.gender,
        p.dob,
        p.county,
        p.area,
        p.accessible,
        p.credentialing_flag,
        p.hospital_accreditation_flag,
        p.vip_flag,
        p.qasp_level,
        t.taxonomy_code                     as primary_taxonomy_code,
        t.taxonomy_eff_date,
        l.prov_language                     as primary_language,
        l.proficiency                       as language_proficiency,
        n.npi,
        p.changed_date                      as source_changed_date,
        current_timestamp()                 as dw_load_date
    from prov            p
    left join taxonomy   t on p.prov_rec_id = t.prov_rec_id
    left join lang       l on p.prov_rec_id = l.prov_rec_id
    left join npi_xref   n on p.prov_rec_id = n.prov_rec_id

)

select * from final
