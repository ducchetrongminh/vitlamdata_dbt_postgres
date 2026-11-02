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
        id as wp_order_id,
        parent_id as parent_wp_order_id,
        user_id as ordered_by_wp_user_id,
        created_by as created_by_wp_user_id,
        updated_by as updated_by_wp_user_id,
        coupon_code as wp_coupon_code,
        -- Attributes
        transaction_id as payment_transaction_no,
        note as payment_note,
        order_type as wp_order_type_code,
        order_status as wp_order_status_code,
        payment_status as payment_status_code,
        payment_method as payment_method_code,
        tax_type as tax_type_code,
        discount_type as discount_type_code,
        discount_reason,
        -- Dates
        created_at_gmt as ordered_at_utc,
        updated_at_gmt as updated_at_utc,
        -- Measures
        subtotal_price as subtotal_amt,
        coupon_amount as coupon_discount_amt,
        discount_amount as discount_amt,
        pre_tax_price as pre_tax_amt,
        tax_amount as tax_amt,
        total_price as total_amt,
        net_payment as net_payment_amt,
        fees as fee_amt,
        earnings as earning_amt,
        refund_amount as refund_amt,
        tax_rate as tax_pct
    from filtered
),

casted as (
    select
        -- Keys
        cast(wp_order_id as bigint) as wp_order_id,
        cast(parent_wp_order_id as bigint) as parent_wp_order_id,
        cast(ordered_by_wp_user_id as bigint) as ordered_by_wp_user_id,
        cast(created_by_wp_user_id as bigint) as created_by_wp_user_id,
        cast(updated_by_wp_user_id as bigint) as updated_by_wp_user_id,
        cast(wp_coupon_code as text) as wp_coupon_code,
        -- Attributes
        cast(payment_transaction_no as text) as payment_transaction_no,
        cast(payment_note as text) as payment_note,
        cast(wp_order_type_code as text) as wp_order_type_code,
        cast(wp_order_status_code as text) as wp_order_status_code,
        cast(payment_status_code as text) as payment_status_code,
        cast(payment_method_code as text) as payment_method_code,
        cast(tax_type_code as text) as tax_type_code,
        cast(discount_type_code as text) as discount_type_code,
        cast(discount_reason as text) as discount_reason,
        -- Dates
        cast(ordered_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as ordered_at,
        cast(updated_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as updated_at,
        -- Measures
        cast(subtotal_amt as numeric) as subtotal_amt,
        cast(coupon_discount_amt as numeric) as coupon_discount_amt,
        cast(discount_amt as numeric) as discount_amt,
        cast(pre_tax_amt as numeric) as pre_tax_amt,
        cast(tax_amt as numeric) as tax_amt,
        cast(total_amt as numeric) as total_amt,
        cast(net_payment_amt as numeric) as net_payment_amt,
        cast(fee_amt as numeric) as fee_amt,
        cast(earning_amt as numeric) as earning_amt,
        cast(refund_amt as numeric) as refund_amt,
        cast(tax_pct as numeric) as tax_pct
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
        case coalesce(tax_type_code, '')
            when '' then 'No Tax'
            when 'inclusive' then 'Tax Inclusive'
            when 'exclusive' then 'Tax Exclusive'
            else 'Unknown'
        end as tax_type,
        case coalesce(discount_type_code, '')
            when '' then 'No Discount'
            when 'flat' then 'Flat'
            when 'percentage' then 'Percentage'
            else 'Unknown'
        end as discount_type,
        -- SePay writes its transaction id into the note ("SePay 87456092: 49.000₫"); Tutor leaves transaction_id empty
        coalesce(nullif(trim(payment_transaction_no), ''), substring(payment_note from '^SePay (\d+):')) as payment_transaction_no_resolved
    from casted
),

null_handled as (
    select
        -- Keys
        wp_order_id,
        coalesce(nullif(parent_wp_order_id, 0), -1) as parent_wp_order_id,          -- Tutor writes 0 for no parent
        coalesce(nullif(ordered_by_wp_user_id, 0), -1) as ordered_by_wp_user_id,
        coalesce(nullif(created_by_wp_user_id, 0), -1) as created_by_wp_user_id,
        coalesce(nullif(updated_by_wp_user_id, 0), -1) as updated_by_wp_user_id,
        coalesce(nullif(trim(wp_coupon_code), ''), 'UNKNOWN') as wp_coupon_code,
        -- Attributes
        coalesce(payment_transaction_no_resolved, 'Unknown') as payment_transaction_no,
        wp_order_type,
        wp_order_status,
        payment_status,
        payment_method,
        tax_type,
        discount_type,
        coalesce(nullif(trim(discount_reason), ''), 'Unknown') as discount_reason,
        -- Dates
        ordered_at,
        updated_at,
        -- Measures
        subtotal_amt,
        coupon_discount_amt,
        discount_amt,
        pre_tax_amt,
        tax_amt,
        total_amt,
        net_payment_amt,
        fee_amt,
        earning_amt,
        refund_amt,
        tax_pct
    from decoded
)

select * from null_handled
