with source as (
    select * from {{ source('oracle', 'prov_language') }}
),

renamed as (
    select
        prov_rec_id,
        prov_language,
        personnel,
        proficiency,
        eff_date,
        end_date,
        last_modified_date,
        last_modified_by
    from source
)

select * from renamed
