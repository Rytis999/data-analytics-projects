Projektas: Klientų duomenų analizė

Naudodamas SQL apjungiau ir apdorojau klientų duomenis iš kelių lentelių – nuo apklausų iki užsakymų istorijos. 
Išvaliau reikšmes, apskaičiavau KMI, įvertinau norimą svorio pokytį, nustačiau  konversijas, prenumeratų trukmę, grąžinimus ir mokėjimus.
 Galiausiai viska sujungiau į vieną lentelę .








-- Pasiimam naujausią kliento atsakymą apie diabetą


WITH diabetes_type_raw AS (
  SELECT
    client_id,
    SAFE_CAST(REGEXP_EXTRACT(value, r'"([^"]+)"') AS STRING) AS diabetes_type,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY client_id 
      ORDER BY created_at DESC
    ) AS row_num
  FROM `td_customer_analysis.client_settings`
  WHERE field = 'diabetes_therapy'
),


 -- Tik naujausias atsakymas per klientą (nes kai kurie keitė nuomonę)


diabetes_type_cleaned AS (
  SELECT 
    client_id, 
    diabetes_type
  FROM diabetes_type_raw
  WHERE row_num = 1
),


-- Pasiimam naujausią aktyvumo lygį 


activity_level_raw AS (
  SELECT 
    field,
    client_id,
    ROW_NUMBER() OVER (
      PARTITION BY client_id
      ORDER BY created_at DESC 
    ) AS row_num,
    CASE 
      WHEN value = '2' THEN 'Moderately Active'
      WHEN value = '1' THEN 'Not Active'
      WHEN value = '3' THEN 'Very Active'
    END AS activity_level
  FROM `td_customer_analysis.client_settings`
  WHERE field = 'activity_level'
),






activity_level_cleaned AS (
  SELECT 
    client_id,
    activity_level 
  FROM  activity_level_raw
  WHERE row_num = 1
),






allergies_raw AS (
  SELECT
    client_id,
    value,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY client_id
      ORDER BY created_at DESC
    ) AS row_num
  FROM `td_customer_analysis.client_settings`
  WHERE field = 'allergies'
),


-- Peržiūrim reikšmę ir pažymim TRUE/FALSE pagal tai, ar alergija buvo nurodyta


allergies_cleaned AS (
  SELECT 
    client_id,
    CASE WHEN value LIKE '%lactose%' THEN TRUE ELSE FALSE END AS allergy_lactose,
    CASE WHEN value LIKE '%milk%' THEN TRUE ELSE FALSE END AS allergy_milk,
    CASE WHEN value LIKE '%gluten%' THEN TRUE ELSE FALSE END AS allergy_gluten,
    CASE 
      WHEN value NOT LIKE '%lactose%' 
        AND value NOT LIKE '%milk%' 
        AND value NOT LIKE '%gluten%' 
        AND value NOT LIKE '%none%' THEN TRUE
      ELSE FALSE
    END AS allergy_other,
    CASE WHEN value LIKE '%none%' THEN TRUE ELSE FALSE END AS no_allergy
  FROM allergies_raw
  WHERE row_num = 1
),




--Patikrinam ar klientas apskritai pirkęs kažką (jei taip, laikom jį "converted")


converted_raw AS (
  SELECT DISTINCT client_id,
    TRUE AS is_converted
  FROM `td_customer_analysis.orders`
),




--Gaunam naujausią prenumeratos planą ir ištraukiam jo trukmę mėnesiais


plan_length_raw AS (
  SELECT 
    client_id,
    plan,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY client_id 
      ORDER BY created_at DESC
    ) AS row_num
  FROM `td_customer_analysis.subscriptions`
),








plan_length_cleaned AS (
  SELECT 
    client_id,
    CAST(REGEXP_EXTRACT(plan, r'(\d+)') AS INT64) AS plan_length
  FROM plan_length_raw
  WHERE row_num = 1
),




-- Suskaičiuojam kiek mokėjimų klientas padarė (tik initial ir recurring)


payment_count_raw AS (
  SELECT 
    client_id,
    COUNT(*) AS payment_count 
  FROM `td_customer_analysis.orders`
  WHERE order_type IN ('initial', 'recurring')
  GROUP BY client_id
),




-- Patikrinam ar buvo grąžinimų pagal tipą


refunded_initial_raw AS (
  SELECT DISTINCT client_id,
    TRUE AS refunded_initial
  FROM `td_customer_analysis.refunds`
  WHERE order_type = 'initial'
),


refunded_recurring_raw AS (
  SELECT DISTINCT client_id,
    TRUE AS refunded_recurring
  FROM `td_customer_analysis.refunds`
  WHERE order_type = 'recurring'
),


refunded_oneclick_raw AS (
  SELECT DISTINCT client_id,
    TRUE AS refunded_oneclick
  FROM `td_customer_analysis.refunds`
  WHERE order_type IN ('oneclick', 'upsell')
),




--  Tas pats, bet su chargeback'ais (ginčai dėl mokėjimų)


chargebacked_initial_raw AS (
  SELECT DISTINCT c.client_id,
    TRUE AS chargebacked_initial
  FROM `td_customer_analysis.chargebacks` c
  JOIN `td_customer_analysis.orders` o
    ON c.order_id = CAST(o.order_id AS STRING)
  WHERE o.order_type = 'initial'
),


chargebacked_recurring_raw AS (
  SELECT DISTINCT c.client_id,
    TRUE AS chargebacked_recurring
  FROM `td_customer_analysis.chargebacks` c
  JOIN `td_customer_analysis.orders` o
    ON c.order_id = CAST(o.order_id AS STRING)
  WHERE o.order_type = 'recurring'
),


chargebacked_oneclick_raw AS (
  SELECT DISTINCT c.client_id,
    TRUE AS chargebacked_oneclick
  FROM `td_customer_analysis.chargebacks` c
  JOIN `td_customer_analysis.orders` o
    ON c.order_id = CAST(o.order_id AS STRING)
  WHERE o.order_type IN ('oneclick', 'upsell')
)




--  Viską sujungiame į vieną galutinę klientų lentelę


SELECT 
  clients.client_id,
  clients.gender,
  clients.age,
  clients.client_country,
  clients.created_at,
  clients.height,
  clients.weight,


-- Kiek kūno masės nori numesti (procentais)


  CASE 
    WHEN clients.weight != 0 THEN (clients.target_weight - clients.weight) / clients.weight
    ELSE NULL
  END AS body_mass_to_lose,


  -- Kategorija pagal numetimo procentą


  CASE
    WHEN clients.weight = 0 THEN NULL
    WHEN (clients.target_weight - clients.weight)/clients.weight < 0.05 THEN '<5%'
    WHEN (clients.target_weight - clients.weight)/clients.weight < 0.10 THEN '[5%-10%)'
    WHEN (clients.target_weight - clients.weight)/clients.weight < 0.20 THEN '[10%-20%)'
    WHEN (clients.target_weight - clients.weight)/clients.weight < 0.30 THEN '[20%-30%)'
    WHEN (clients.target_weight - clients.weight)/clients.weight < 0.40 THEN '[30%-40%)'
    WHEN (clients.target_weight - clients.weight)/clients.weight < 0.50 THEN '[40%-50%)'
    ELSE '>=50%'
  END AS body_mass_to_lose_category,


  --BMI ir jo kategorija


  clients.bmi,


  CASE
    WHEN clients.bmi < 19 THEN '<19'
    WHEN clients.bmi < 25 THEN '[20-25)'
    WHEN clients.bmi < 30 THEN '[25-30)'
    WHEN clients.bmi < 35 THEN '[30-35)'
    WHEN clients.bmi < 40 THEN '[35-40)'
    WHEN clients.bmi < 45 THEN '[40-45)'
    WHEN clients.bmi < 50 THEN '[45-50)'
    ELSE '>=50'
  END AS bmi_category,


-- Likusi info iš kitų lentelių


  diabetes_type_cleaned.diabetes_type,
  activity_level_cleaned.activity_level,
  allergies_cleaned.allergy_lactose,
  allergies_cleaned.allergy_milk,
  allergies_cleaned.allergy_gluten,
  allergies_cleaned.allergy_other,
  allergies_cleaned.no_allergy,
  converted_raw.is_converted,
  plan_length_cleaned.plan_length,
  payment_count_raw.payment_count,
  refunded_initial_raw.refunded_initial,
  refunded_recurring_raw.refunded_recurring,
  refunded_oneclick_raw.refunded_oneclick,
  chargebacked_initial_raw.chargebacked_initial,
  chargebacked_recurring_raw.chargebacked_recurring,
  chargebacked_oneclick_raw.chargebacked_oneclick


FROM `td_customer_analysis.clients` AS clients
LEFT JOIN diabetes_type_cleaned ON clients.client_id = diabetes_type_cleaned.client_id
LEFT JOIN activity_level_cleaned ON clients.client_id = activity_level_cleaned.client_id
LEFT JOIN allergies_cleaned ON clients.client_id = allergies_cleaned.client_id
LEFT JOIN converted_raw ON clients.client_id = converted_raw.client_id
LEFT JOIN plan_length_cleaned ON clients.client_id = plan_length_cleaned.client_id
LEFT JOIN payment_count_raw ON clients.client_id = payment_count_raw.client_id
LEFT JOIN refunded_initial_raw ON clients.client_id = refunded_initial_raw.client_id
LEFT JOIN refunded_recurring_raw ON clients.client_id = refunded_recurring_raw.client_id
LEFT JOIN refunded_oneclick_raw ON clients.client_id = refunded_oneclick_raw.client_id
LEFT JOIN chargebacked_initial_raw ON CAST(clients.client_id AS STRING) = chargebacked_initial_raw.client_id
LEFT JOIN chargebacked_recurring_raw ON CAST(clients.client_id AS STRING) = chargebacked_recurring_raw.client_id
LEFT JOIN chargebacked_oneclick_raw ON CAST(clients.client_id AS STRING) = chargebacked_oneclick_raw.client_id


LIMIT 1000;
