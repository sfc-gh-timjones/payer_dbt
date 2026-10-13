with source as (
    select * from {{ source('oracle', 'prov') }}
),

renamed as (
    select
        prov_id,
        prov_rec_id,
        prov_type,
        county,
        area,
        accessible,
        gender,
        changed_date,
        "OP#"                        as op_number,
        last_modified_date,
        last_modified_by,
        dob,
        qasp_level,
        credentialing_flag,
        hospital_accreditation_flag,
        vip_flag
    from source
)

select * from renamed
