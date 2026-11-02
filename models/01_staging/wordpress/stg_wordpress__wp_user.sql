with

source as (
    select * from {{ source('wordpress', 'wp_users') }}
),

instructor_allowlist as (
    select * from {{ ref('wp_instructor_allowlist') }}
),

renamed as (
    select
        -- Keys
        id as wp_user_id,
        -- Name, desc
        display_name as wp_user_display_name,
        -- Attributes
        user_login as wp_user_login,
        user_email as wp_user_email,
        user_nicename as wp_user_slug,
        user_registered as registered_at_utc
    from source
),

casted as (
    select
        -- Keys
        cast(wp_user_id as bigint) as wp_user_id,
        -- Name, desc
        cast(wp_user_display_name as text) as wp_user_display_name,
        -- Attributes
        cast(wp_user_login as text) as wp_user_login,
        cast(wp_user_email as text) as wp_user_email,
        cast(wp_user_slug as text) as wp_user_slug,
        cast(registered_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as registered_at
    from renamed
),

hashed as (
    select
        -- Keys
        wp_user_id,
        -- Name, desc
        {{ hash_pii('wp_user_display_name') }} as wp_user_display_name_hash,
        case
            when exists (
                select 1 from instructor_allowlist
                where instructor_allowlist.wp_user_id = casted.wp_user_id
            ) then nullif(trim(wp_user_display_name), '')
        end as wp_user_public_name,                                     -- unhashed only for allowlisted instructors
        -- Attributes
        {{ hash_pii('wp_user_login') }} as wp_user_login_hash,      -- most logins are email addresses
        {{ hash_pii('wp_user_email') }} as wp_user_email_hash,
        {{ hash_pii('wp_user_slug') }} as wp_user_slug_hash,        -- user_nicename, derived from the login
        registered_at
    from casted
)

select * from hashed
