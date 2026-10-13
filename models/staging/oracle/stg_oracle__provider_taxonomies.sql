with source as (
    select * from {{ source('oracle', 'prov_taxonomy') }}
),

renamed as (
    select
        prov_rec_id,
        taxonomy_code,
        primary_flag,
        eff_date,
        end_date,
        last_modified_date,
        last_modified_by
    from source
)

select * from renamed
