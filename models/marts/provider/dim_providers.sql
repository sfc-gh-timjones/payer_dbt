{{
    config(
        materialized='incremental',
        unique_key='provider_sk',
        incremental_strategy='merge'
    )
}}

with providers as (

    select * from {{ ref('int_providers_enriched') }}

),

addresses as (

    select * from {{ ref('int_provider_addresses_enriched') }}
    where addr_type = 'WORK'

),

final as (

    select
        p.provider_sk,
        p.prov_id,
        p.prov_type,
        p.gender,
        p.primary_taxonomy_code,
        p.primary_language,
        p.npi,
        a.street,
        a.city,
        a.state,
        a.zip,
        a.phone,
        p.dw_load_date
    from providers p
    left join addresses a
        on p.prov_rec_id = a.prov_rec_id

    {% if is_incremental() %}
    where p.dw_load_date > (select coalesce(max(dw_load_date), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}

)

select * from final
