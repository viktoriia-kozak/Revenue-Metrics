with cte_1 as (
select  gp.user_id
--округлюю дату
,DATE_TRUNC('month',gp.payment_date) as
payment_month
,SUM(gp.revenue_amount_usd) as
total_revenue
from project.games_payments gp
group by gp.user_id
--групуємо по користувачу і  по місяцю
, DATE_TRUNC('month',gp.payment_date)
)
--select count(*)
--from cte_1 ;
,cte_2 as (
select *,
--попередній місяць
lag(payment_month) over (partition by user_id order by payment_month) as
previous_paid_month
--насупний місяць
,lead (payment_month) over (partition by user_id order by payment_month) as
next_paid_month
,date(payment_month-interval '1 month') as
previous_calendar_month
,date(payment_month +interval '1 month') as
next_calendar_month
--прихід попереднього місяця
,lag(total_revenue) over(partition by user_id order by payment_month) as
previous_revenue
from cte_1 c1
)
, cte_3 as (
select
c2.user_id
, c2.payment_month
, c2.total_revenue
, coalesce(c2.previous_revenue,0) as previous_revenue
, c2.previous_paid_month
, c2.next_paid_month
, c2.previous_calendar_month
, c2.next_calendar_month
--NEW paid Users
,case when c2.previous_paid_month is null then 1 else 0 end as
new_paid_user
--MRR
,case when c2.previous_paid_month is null then c2.total_revenue else 0 end as
new_MRR
--Churned Users
,case when c2.next_paid_month is null or c2.next_paid_month <> c2.next_calendar_month then 1 else 0 end as
churned_user
--Churned revenue
,case when c2.next_paid_month is null or c2.next_paid_month <> c2.next_calendar_month then c2.total_revenue else 0 end as
churned_revenue
--Expansion MRR
,case when c2.previous_paid_month = c2.previous_calendar_month
and c2.total_revenue > c2.previous_revenue then c2.total_revenue - c2.previous_revenue  else 0 end as
expansion_MRR
--contraction MRR
,case when c2.previous_paid_month = c2.previous_calendar_month
and c2.total_revenue < c2.previous_revenue then c2.previous_revenue - c2.total_revenue  else 0 end as
contraction_MRR
,gpu."language"
,gpu.age
,gpu.game_name
from cte_2 c2
left join project.games_paid_users gpu  on c2.user_id = gpu.user_id
)
select *
from cte_3;
