-- One row per (review, order). review_id alone is not unique in the source,
-- so we build a combined key.

with source as (

    select * from {{ source('olist', 'order_reviews') }}

),

renamed as (

    select
        review_id || '-' || order_id                    as review_order_key,
        review_id,
        order_id,
        review_score,
        review_comment_title                            as comment_title,
        review_comment_message                          as comment_message,
        review_comment_message is not null              as has_comment,
        review_creation_date                            as survey_sent_at,
        review_answer_timestamp                         as survey_answered_at
    from source

)

select * from renamed
