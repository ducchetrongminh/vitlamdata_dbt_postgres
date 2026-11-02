with

base as (
    select * from {{ ref('base_wordpress__wp_user') }}
),

hashed as (
    select
        -- Keys
        wp_user_id,
        -- Name, desc
        {{ hash_pii('wp_user_display_name') }} as wp_user_display_name_hash,
        -- Attributes
        {{ hash_pii('wp_user_login') }} as wp_user_login_hash,      -- most logins are email addresses
        {{ hash_pii('wp_user_email') }} as wp_user_email_hash,
        {{ hash_pii('wp_user_slug') }} as wp_user_slug_hash,        -- user_nicename, derived from the login
        registered_at
    from base
)

select * from hashed
