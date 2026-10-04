# Business Problem

## The question

> **Which customers are most valuable, which are becoming inactive, and which customers should the company prioritize for retention?**

## Context

Olist is a Brazilian marketplace connecting small sellers to customers. Acquiring a new customer
costs more than keeping an existing one, yet most marketplace customers never place a second order.
The company needs to know where to spend a limited retention budget (vouchers, follow-up emails,
service recovery) to get the biggest return.

## Three sub-questions, and the data that answers them

| # | Sub-question | Measured with (existing columns only) |
|---|---|---|
| 1 | **Who is most valuable?** | Total spend: `SUM(order_payments.payment_value)` per `customer_unique_id`. Order count: number of orders. Average order value. |
| 2 | **Who is becoming inactive?** | Days since last purchase: `order_purchase_timestamp` measured from the dataset's last order date. Gap since last order vs. the customer's usual gap. |
| 3 | **Who should we prioritise?** | High value **and** rising inactivity, plus experience signals: low `review_score`, late delivery (`order_delivered_customer_date` > `order_estimated_delivery_date`). |

## Success criteria for the project

- Every customer (`customer_unique_id`) gets a value segment, an activity status and a priority level.
- Business users can filter the prioritised list by state and category in Tableau (Dashboard 5).
- Every metric traces back to a documented column in [data_dictionary.md](data_dictionary.md).

## Assumptions and limits (stated up front)

- **No explicit churn label exists.** "Inactive" will be a rule based on days since last purchase.
  The threshold will be chosen from the data in Sprint 2, not guessed.
- **"Today" = the last order date in the data** (2018), not the real current date.
- Most customers buy once, so the analysis must separate *one-time buyers* from *lapsed repeat buyers*.
- No marketing, demographic or web-behaviour data is available, and none is assumed.
