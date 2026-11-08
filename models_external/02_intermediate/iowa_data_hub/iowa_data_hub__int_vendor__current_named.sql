-- Vendor type 3 (docs/dimensional-modeling-standards.md#31-slowly-changing-dimensions-scd):
-- before 2016-08-29 a vendor under 100 has a 2-digit code (10), later a 3-digit one (010)
-- (docs/profiling/iowa_data_hub/liquor_sales_2016.md #1). Both codes keep their rows; the old
-- code takes the later code's name as vendor_name. Not in the incremental
-- int_vendor__latest_picked: an old code's row stops updating in 2016, while its later
-- code's name can still change, so the current name is looked up on every build.
-- Why we don't follow docs/dimensional-modeling-standards.md#31-slowly-changing-dimensions-scd
-- (current_<attribute> for today's value): vendor_name is the name people read, so it holds
-- today's; the row's own name is the extra column, historic_vendor_name.
with

vendor as (
    select * from {{ ref('iowa_data_hub__int_vendor__latest_picked') }}
),

current_named as (
    select
        -- Keys
        vendor.vendor_code,
        -- Name, desc
        coalesce(later_code.vendor_name, vendor.vendor_name) as vendor_name,
        vendor.vendor_name as historic_vendor_name
    from vendor
    left join vendor as later_code
        on length(vendor.vendor_code) < 3   -- lpad also cuts longer codes ('UNKNOWN' to 'UNK')
        and later_code.vendor_code = lpad(vendor.vendor_code, 3, '0')
)

select * from current_named
