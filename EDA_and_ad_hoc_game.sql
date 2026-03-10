/* Исследовательский анализ данных и решение ad hoc задач для игры 
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей на покупку внутриигровой валюты «райские лепестки»,
 * а также оценить активность игроков при совершении внутриигровых покупок
 * 
 * Автор:Сикорская Ярослава */

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков 

-- 1.1. Доля платящих пользователей по всем данным:
SELECT count_players,
	count_players_payer,
	ROUND((count_players_payer::float/count_players)::numeric, 3) AS share_payer
FROM(
	SELECT COUNT(id) AS count_players,
	(SELECT COUNT(id) FROM fantasy.users WHERE payer=1) AS count_players_payer
	FROM fantasy.users
)AS fu;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH c_1  AS (
	SELECT race,
		ROUND((AVG(payer)), 4) AS share_payer,
		COUNT(id) AS count_players,
		SUM(payer) AS count_players_payer
	FROM fantasy.users AS fu
	LEFT JOIN fantasy.race AS fr ON fu.race_id=fr.race_id
	GROUP BY race
)
SELECT race,
	count_players,
	count_players_payer,
	share_payer
FROM c_1 
ORDER BY count_players_payer DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(transaction_id) AS count_purchase,
	SUM(amount) AS amount_all,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	ROUND(AVG(amount::numeric),2) AS avg_amount,
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::numeric, 2) AS median,
	ROUND((STDDEV(amount::numeric)), 2) AS stand_dev
FROM fantasy.events
WHERE amount<>0;

-- 2.2: Аномальные нулевые покупки:
SELECT count_purchase,
	count_null_purchase,
	ROUND((count_null_purchase/count_purchase::float::numeric), 4) AS share_null_purchase
FROM (SELECT COUNT(transaction_id) AS count_purchase,
			(SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount=0) AS count_null_purchase
	  FROM fantasy.events
) AS fe;

--Доп.исследование: какие предметы имели стоимость 0 у.е. и сколько раз их покупали/получали игроки
SELECT DISTINCT id,
	game_items,
	COUNT(transaction_id) AS count_free_purchase
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e USING(item_code)
WHERE amount=0
GROUP BY DISTINCT id, game_items
ORDER BY count_free_purchase DESC ;
	  
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
--кол-во всех покупок и сумма всех покупок
WITH a1 AS (
	SELECT id,
		COUNT(transaction_id) AS count_purchase,
		SUM(amount) AS amount_all_purchase
	FROM fantasy.events 
	WHERE amount<>0 
	GROUP BY id
) --сравнительный анализ
SELECT CASE
		WHEN payer=1
		THEN 'платящий'
		WHEN payer=0
		THEN 'неплатящий'
	END AS group_of_players,
	COUNT(a1.id) AS count_players,
	ROUND((AVG(count_purchase::numeric)), 3) AS avg_count_purchase_4_one,
	ROUND((AVG(amount_all_purchase::numeric)), 2) AS avg_sum_purchase_4_one
FROM a1 
LEFT JOIN fantasy.users AS u ON a1.id=u.id
GROUP BY group_of_players
ORDER BY count_players DESC;

--доп.исследование:анализ активности платящих и неплатящих игроков в разрезе рас
WITH a1 AS (
	SELECT id,
		COUNT(transaction_id) AS count_purchase,
		SUM(amount) AS amount_all_purchase
	FROM fantasy.events 
	WHERE amount<>0 
	GROUP BY id
)
SELECT CASE
		WHEN payer=1
		THEN 'платящий'
		WHEN payer=0
		THEN 'неплатящий'
	END AS group_of_players,
	race,
	COUNT(a1.id) AS count_players,
	ROUND((AVG(count_purchase::numeric)), 3) AS avg_count_purchase_4_one,
	ROUND((AVG(amount_all_purchase::numeric)), 2) AS avg_sum_purchase_4_one
FROM a1 
LEFT JOIN fantasy.users AS u ON a1.id=u.id
LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id 
GROUP BY group_of_players, race
ORDER BY count_players DESC ,avg_sum_purchase_4_one  DESC;

-- 2.4: Популярные эпические предметы: 
SELECT game_items,
	COUNT(transaction_id) AS count_purchase_absolutely,
	(COUNT(transaction_id)/(SELECT COUNT(transaction_id) FROM fantasy.events)::float)::numeric(10,4) AS share_relatively,
	(COUNT(DISTINCT id)/((SELECT COUNT(id) FROM fantasy.users)::float))::numeric(10,4) AS share_buyers
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e USING(item_code)
WHERE amount<>0
GROUP BY game_items 
ORDER BY count_purchase_absolutely DESC;

--доп.исследование количество предметов, которые ни разу не покупали
SELECT game_items,
	COUNT(transaction_id) AS count_null_purchase
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e USING(item_code)
GROUP BY game_items 
HAVING((COUNT(transaction_id))=0);

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
--расчет всех игроков по расам
WITH a1 AS (
	SELECT race,
		COUNT(id) AS count_players
	FROM fantasy.users AS u
	LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
	GROUP  BY race
), --расчет "платящих" покупающих игроков по расам
a2 AS (
	SELECT race,
		COUNT(DISTINCT e.id) AS c_players_buyer_payer
	FROM fantasy.users AS u
	LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id	
	left JOIN fantasy.events AS e ON u.id=e.id
	WHERE payer=1 
	GROUP BY race
), --расчет количества покупок, количества покупающих игроков и суммы покупок в разрезе рас, искл нулевую стоимость 
a3 AS (
	SELECT race, 
		COUNT(transaction_id) AS count_purchase,
		COUNT(DISTINCT id) AS count_players_buyer,
		SUM(amount) AS amount_all
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users  AS u USING(id)
	LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
	WHERE amount<>0
	GROUP BY race
)
SELECT a1.race,
		a1.count_players,
		a3.count_players_buyer,
		(a3.count_players_buyer/a1.count_players::float)::numeric(10, 4) AS share_players_buyer,
		a2.c_players_buyer_payer,
		(a2.c_players_buyer_payer/a3.count_players_buyer::float)::numeric(10, 4) AS share_c_players_buyer_payer,
		a3.count_purchase/a3.count_players_buyer AS avg_purchase_4_one,
		(a3.amount_all/a3.count_purchase)::numeric(10, 2) AS avg_amount_one_purchase_4_one,
		(a3.amount_all/a3.count_players_buyer)::numeric(10, 2) AS avg_sum_amount_purchase_4_one
FROM a1
LEFT JOIN a2 USING(race)
LEFT JOIN a3 USING(race)
ORDER BY avg_purchase_4_one DESC;

-- Задача 2: Частота покупок
--вычисляем для каждой покупки количество дней с предыдущей покупки
WITH b1 AS (
	SELECT id, 
		transaction_id,
		amount,
	((date::timestamp)-(LAG(date::timestamp) OVER(PARTITION BY id ORDER BY date))) AS difference_day
	FROM fantasy.events
),--находим кол-во покупок и среднее значение по кол-ву дней между покупками для покупающих с не нулевой стоим и >=25 покупок + ранг
b2 AS (
	SELECT b1.id, 
		payer,
		COUNT(transaction_id) AS count_purchase,
		NTILE(3) OVER(ORDER BY DATE_trunc('DAY',(AVG(difference_day))) ASC) AS rank,
		DATE_trunc('DAY',(AVG(difference_day))) AS avg_difference_day
		FROM b1 
		LEFT JOIN fantasy.users AS u USING(id)
		WHERE amount<>0
		GROUP BY payer, b1.id
		HAVING (COUNT(transaction_id)>=25) 
)
SELECT CASE 
		WHEN b2.rank=1
		THEN 'высокая частота'
		WHEN b2.rank=2
		THEN 'умеренная частота'
		WHEN b2.rank=3
		THEN 'низкая частота'
	END AS frequency_of_purchase,
	COUNT(DISTINCT id) AS count_players_buyer,
	SUM(payer) AS count_players_buyer_payer,
	ROUND((SUM(payer)/COUNT(DISTINCT id)::float)::numeric, 4)AS share_c_players_buyer_payer,
	ROUND(AVG(count_purchase)::numeric, 0) AS avg_count_purchase,
	DATE_trunc('DAY', (AVG(avg_difference_day))) AS avg_difference_day
FROM b2
GROUP BY frequency_of_purchase 
ORDER BY count_players_buyer_payer DESC;