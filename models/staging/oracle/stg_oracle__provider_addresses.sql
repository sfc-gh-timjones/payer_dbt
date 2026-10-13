with source as (
    select * from {{ source('oracle', 'prov_addr') }}
),

renamed as (
    select
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
        phone,
        fax,
        fte,
        county,
        county_code,
        area,
        lob_id,
        changed_date,
        eff_date,
        end_date,
        last_modified_date,
        last_modified_by
    from source
)

select * from renamed
