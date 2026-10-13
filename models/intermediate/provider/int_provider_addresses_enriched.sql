{{
    config(
        materialized='incremental',
        unique_key=['prov_rec_id', 'addr_type', 'lob_id'],
        incremental_strategy='merge'
    )
}}

-- DIM_PROVIDER_ADDRESS: one row per provider + address type + line-of-business.
-- Multiple address types per provider are expected (HOME, WORK, MAILING).
--
-- Incremental strategy: merge on composite key (PROV_REC_ID, ADDR_TYPE, LOB_ID).
-- On each run we pick up addresses whose CHANGED_DATE is newer than
-- the most recent SOURCE_CHANGED_DATE already in this table.

with prov_addr as (

    select * from {{ ref('stg_oracle__provider_addresses') }}

    {% if is_incremental() %}
    where changed_date
          > (select coalesce(max(source_changed_date), '1900-01-01'::date)
             from {{ this }})
    {% endif %}

),

final as (

    select
        -- Stable surrogate key from composite natural key
        md5(concat_ws('|',
            prov_rec_id::text,
            addr_type,
            coalesce(lob_id, '')
        ))                              as provider_addr_sk,
        prov_rec_id,
        addr_type,
        lastname,
        firstname,
        middlename,
        suffix,
        title,
        greeting,
        street,
        address,
        city,
        state,
        zip,
        county,
        county_code,
        area,
        phone,
        fax,
        fte,
        lob_id,
        eff_date,
        end_date,
        changed_date                    as source_changed_date,
        current_timestamp()             as dw_load_date
    from prov_addr

)

select * from final
