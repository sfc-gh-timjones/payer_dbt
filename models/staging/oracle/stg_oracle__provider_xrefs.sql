-- PRV_XREF1: preferred cross-reference table.
-- Use XREF_TYPE to filter to a specific identifier (NPI, DEA, STATE_LIC, etc.).
with source as (
    select * from {{ source('oracle', 'prv_xref1') }}
),

renamed as (
    select
        prov_rec_id,
        lob_id,
        xref_type,
        eff_date,
        end_date,
        "REFERENCE#"             as reference_number,
        state,
        last_modified_date,
        last_modified_by,
        active
    from source
)

select * from renamed
