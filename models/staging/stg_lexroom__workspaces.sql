-- Grain: one row per workspace (workspace_id).

with source as (
    select * from {{ source('lexroom', 'raw_workspaces') }}
),

final as (
    select
        workspace_id,
        -- 3 workspaces have no country: an explicit value keeps them in group-bys
        coalesce(upper(trim(country)), 'unknown')               as country,
        lower(trim(plan))                                       as plan,
        trim(firm_size_bucket)                                  as firm_size_bucket,
        cast(signup_date as date)                               as signup_date
    from source
)

select * from final
