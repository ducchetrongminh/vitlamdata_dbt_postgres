with

source as (
    select * from {{ source('wordpress', 'wp_tutor_orders') }}
),

filtered as (
    select * from source
    where order_status <> 'trash'
),

renamed as (
    select
        -- Keys
        id as wp_order_no,
        -- Foreign keys
        user_id as ordered_by_wp_user_id,
        -- Attributes
        transaction_id as payment_transaction_no,
        note as payment_note,
        order_type as wp_order_type_code,
        order_status as wp_order_status_code,
        payment_status as payment_status_code,
        payment_method as payment_method_code,
        -- Dates
        created_at_gmt as ordered_at_utc,
        updated_at_gmt as updated_at_utc
    from filtered
),

casted as (
    select
        -- Keys
        cast(wp_order_no as bigint) as wp_order_no,
        -- Foreign keys
        cast(ordered_by_wp_user_id as bigint) as ordered_by_wp_user_id,
        -- Attributes
        cast(payment_transaction_no as text) as payment_transaction_no,
        cast(payment_note as text) as payment_note,
        cast(wp_order_type_code as text) as wp_order_type_code,
        cast(wp_order_status_code as text) as wp_order_status_code,
        cast(payment_status_code as text) as payment_status_code,
        cast(payment_method_code as text) as payment_method_code,
        -- Dates
        cast(ordered_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as ordered_at,
        cast(updated_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as updated_at
    from renamed
),

decoded as (
    select
        *,
        case wp_order_type_code
            when 'single_order' then 'Single Order'
            when 'subscription' then 'Subscription'
            when 'renewal' then 'Renewal'
            else 'Unknown'
        end as wp_order_type,
        case wp_order_status_code
            when 'incomplete' then 'Incomplete'
            when 'completed' then 'Completed'
            when 'cancelled' then 'Cancelled'
            when 'refunded' then 'Refunded'
            when 'partially-refunded' then 'Partially Refunded'
            else 'Unknown'
        end as wp_order_status,
        case payment_status_code
            when 'paid' then 'Paid'
            when 'unpaid' then 'Unpaid'
            when 'failed' then 'Failed'
            when 'refunded' then 'Refunded'
            when 'partially-refunded' then 'Partially Refunded'
            else 'Unknown'
        end as payment_status,
        case payment_method_code
            when 'chuyen-khoan' then 'Bank Transfer'
            else 'Unknown'
        end as payment_method,
        -- SePay writes its transaction id into the note ("SePay 87456092: 49.000₫"); Tutor leaves transaction_id empty
        coalesce(nullif(trim(payment_transaction_no), ''), substring(payment_note from '^SePay (\d+):')) as payment_transaction_no_resolved
    from casted
),

null_handled as (
    select
        -- Keys
        wp_order_no,
        -- Foreign keys
        coalesce(nullif(ordered_by_wp_user_id, 0), -1) as ordered_by_wp_user_id,
        -- Attributes
        coalesce(payment_transaction_no_resolved, 'Unknown') as payment_transaction_no,
        wp_order_type,
        wp_order_status,
        payment_status,
        payment_method,
        -- Dates
        ordered_at,
        updated_at
    from decoded
)

select * from null_handled
