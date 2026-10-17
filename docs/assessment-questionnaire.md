# VitalU periodic health assessment: questionnaire

Version 2026-10. Sent every six months by the university health administration. About 7 minutes; most questions are a single tap.

## How to read this document

- Each section matches one area of the admin dashboard.
- **Score** shows how an answer counts towards that area's well-being score (0 to 100). A higher score is always the healthier answer. Questions without scores are reported as counts only.
- Food questions ask about **the last 7 days** and define **one serving** in household measures (one cupped hand = ½ cup, one fist = 1 cup, palm-sized piece of fish or chicken).
- Section 11 (Clinical measurements) can be shown or hidden by the administration for each round.

## Section 1. Physical and cardiometabolic health

_Your details and recent health history._

**1. Are your details still correct?**  
`p_profile` · Confirm details

> We filled these in from your profile. Update anything that has changed.

Shows age, faculty, academic year and accommodation from the profile, with an option to update them.

**2. How would you rate your overall physical health right now?**  
`p_general` · 1 to 5 rating

| Answer | Score |
|---|---|
| Poor | 0 |
| Fair | 1 |
| Good | 2 |
| Very good | 3 |
| Excellent | 4 |

**3. In the last 6 months, has a doctor or nurse told you that you have any of these?**  
`p_new_dx` · Choose all that apply

> Select all that apply.

- High blood pressure
- Diabetes or prediabetes
- High cholesterol
- Heart or blood vessel disease
- Another long-term condition
- None of these
- Prefer not to say

**4. Do you currently use any of these?**  
`p_substance` · Choose all that apply · optional

> Optional and confidential. Answers are pooled with other students and never linked to your name. If you would like support to cut down or quit, the health centre and counsellors can help without judgement.

- Cigarettes or other tobacco (including beedi)
- E-cigarettes or vapes
- Alcohol
- Cannabis (ganja)
- Medicines not prescribed to me, taken to feel high
- Other substances
- None of these
- Prefer not to say

## Section 2. Dietary behaviours and food security

_Think about the last 7 days. Each question shows what one serving looks like._

**5. In the last 7 days, on how many days did you eat breakfast?**  
`d_breakfast` · Choose one

> Anything substantial before your first lecture counts: bread, hoppers, string hoppers, oats, milk rice or a rice meal.

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 3 days | 1 |
| 4 to 6 days | 2 |
| Every day | 3 |

**6. On how many days did you eat 2 or more servings of vegetables?**  
`d_veg` · Choose one

> 1 serving = ½ cup of cooked vegetables or mallum (one cupped hand), or 1 cup of raw salad (one fist). Potatoes do not count.

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 3 days | 1 |
| 4 to 6 days | 2 |
| Every day | 3 |

**7. On how many days did you eat dark green leafy vegetables?**  
`d_greens` · Choose one

> Gotukola, mukunuwenna, kankun, spinach or kathurumurunga. 1 serving = ½ cup cooked or as mallum (one cupped hand).

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 2 days | 1 |
| 3 to 4 days | 2 |
| 5 to 7 days | 3 |

**8. On how many days did you eat at least 1 serving of fruit?**  
`d_fruit` · Choose one

> 1 serving = 1 medium fruit (banana, orange, guava) or ½ cup of cut fruit such as papaya, pineapple or mango (one cupped hand). Fruit juice does not count.

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 3 days | 1 |
| 4 to 6 days | 2 |
| Every day | 3 |

**9. On how many days did you eat pulses?**  
`d_pulses` · Choose one

> Dhal (parippu), chickpeas (kadala), green gram, cowpea or soya meat. 1 serving = ½ cup cooked (one cupped hand).

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 2 days | 1 |
| 3 to 4 days | 2 |
| 5 to 7 days | 3 |

**10. On how many days did you eat fish, eggs or chicken?**  
`d_protein` · Choose one

> 1 serving = 1 egg, or a piece of fish or chicken about the size of your palm.

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 2 days | 1 |
| 3 to 4 days | 2 |
| 5 to 7 days | 3 |

**11. On how many days was your main starch a whole grain?**  
`d_wholegrain` · Choose one

> Red or brown rice, kurakkan, atta flour roti or bread, or oats. 1 serving = 1 cup of cooked rice (one fist) or 1 roti.

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 2 days | 1 |
| 3 to 4 days | 2 |
| 5 to 7 days | 3 |

**12. On how many days did you have milk, curd or yoghurt?**  
`d_dairy` · Choose one

> 1 serving = 1 glass of milk (200 ml) or 1 small cup of curd or yoghurt (about 100 g).

| Answer | Score |
|---|---|
| 0 days | 0 |
| 1 to 2 days | 1 |
| 3 to 4 days | 2 |
| 5 to 7 days | 3 |

**13. On how many days did you have sugary drinks or sweets?**  
`d_sugary` · Choose one

> Soft drinks, sweet tea or coffee, packet juice, cake, chocolate, kavum or ice cream. 1 serving = 1 glass or small bottle (200 ml), or 1 piece of a sweet.

| Answer | Score |
|---|---|
| 0 days | 3 |
| 1 to 2 days | 2 |
| 3 to 4 days | 1 |
| 5 to 7 days | 0 |

**14. On how many days did you eat short eats, fried food or fast food?**  
`d_fried` · Choose one

> Rolls, patties, cutlets, vadai, kottu, fried rice, instant noodles or burgers. 1 serving = 1 short eat or 1 plate.

| Answer | Score |
|---|---|
| 0 days | 3 |
| 1 to 2 days | 2 |
| 3 to 4 days | 1 |
| 5 to 7 days | 0 |

**15. How often were your main meals balanced?**  
`d_balanced` · Choose one

> A balanced meal has a starch (rice, roti or hoppers), vegetables and a protein (dhal, egg, fish, chicken or soya), like the healthy plate.

| Answer | Score |
|---|---|
| Almost always | 3 |
| Often | 2 |
| Sometimes | 1 |
| Rarely or never | 0 |

**16. Overall, how healthy was your diet this week?**  
`d_rating` · 1 to 5 rating

| Answer | Score |
|---|---|
| Very unhealthy | 0 |
| Somewhat unhealthy | 1 |
| In between | 2 |
| Fairly healthy | 3 |
| Very healthy | 4 |

**17. In the last month, did you skip meals or eat less because money was short?**  
`d_skip_money` · Choose one

| Answer | Score |
|---|---|
| Never | 3 |
| Once or twice | 2 |
| Sometimes | 1 |
| Often | 0 |

## Section 3. Academic workload and time pressure

_How study fits around the rest of life._

**18. How manageable is your academic workload right now?**  
`a_load` · 1 to 5 rating

| Answer | Score |
|---|---|
| Very hard | 0 |
| Hard | 1 |
| Okay | 2 |
| Manageable | 3 |
| Very manageable | 4 |

**19. How often has your academic workload got in the way of your meals, sleep or well-being?**  
`a_interfere` · Choose one

| Answer | Score |
|---|---|
| Never | 4 |
| Rarely | 3 |
| Sometimes | 2 |
| Often | 1 |
| Very often | 0 |

## Section 4. Emotional well-being and stress

_How you have been feeling. These are screening questions, not a diagnosis._

**20. Overall, how has your mood been over the past two weeks?**  
`e_mood` · 1 to 5 rating

| Answer | Score |
|---|---|
| Very low | 0 |
| Low | 1 |
| Okay | 2 |
| Good | 3 |
| Great | 4 |

**21. Over the last 2 weeks, how often have you been bothered by little interest or pleasure in doing things?**  
`e_phq1` · Choose one

| Answer | Score |
|---|---|
| Not at all | 3 |
| Several days | 2 |
| More than half the days | 1 |
| Nearly every day | 0 |

**22. Over the last 2 weeks, how often have you been bothered by feeling down, depressed or hopeless?**  
`e_phq2` · Choose one

| Answer | Score |
|---|---|
| Not at all | 3 |
| Several days | 2 |
| More than half the days | 1 |
| Nearly every day | 0 |

## Section 5. Sleep and daily routines

_Rest and the rhythm of your days._

**23. How many hours do you usually sleep a night?**  
`s_hours` · Choose one

| Answer | Score |
|---|---|
| Less than 5 hours | 0 |
| 5 to 6 hours | 1 |
| 7 to 8 hours | 3 |
| More than 8 hours | 2 |

**24. How would you rate your sleep quality over the past month?**  
`s_quality` · Choose one

| Answer | Score |
|---|---|
| Very bad | 0 |
| Fairly bad | 1 |
| Fairly good | 2 |
| Very good | 3 |

**25. Do you go to bed and wake up at about the same times most days?**  
`s_regular` · Choose one

| Answer | Score |
|---|---|
| Mostly, yes | 2 |
| Sometimes | 1 |
| Rarely | 0 |

## Section 6. Physical activity and sedentary behaviour

_Moving and sitting through the week._

**26. In the last 7 days, on how many days were you active for at least 30 minutes?**  
`m_active_days` · Choose one

> Brisk walking, sport, gym, cycling or dancing all count.

| Answer | Score |
|---|---|
| 0 days (Not active) | 0 |
| 1 to 2 days (A little active) | 1 |
| 3 to 4 days (Fairly active) | 2 |
| 5 to 7 days (Very active) | 3 |

**27. On a typical weekday, how many hours do you spend sitting?**  
`m_sitting` · Choose one

> Lectures, studying, travel and screen time together.

| Answer | Score |
|---|---|
| Less than 6 hours | 2 |
| 6 to 9 hours | 1 |
| 10 hours or more | 0 |

## Section 7. Financial and living conditions

_Where you stay and how money affects health._

**28. Where do you live during the semester?**  
`f_living` · Choose one · pre-filled from the student's profile

- University hostel
- Boarding or rented room
- At home with family
- Somewhere else

**29. How often do money worries affect your food, transport or health choices?**  
`f_money` · Choose one

| Answer | Score |
|---|---|
| Never | 3 |
| Sometimes | 2 |
| Often | 1 |
| Almost always | 0 |

## Section 8. Social environment and personal support

_The people around you._

**30. Do you have someone you can talk to when things get hard?**  
`o_talk` · Choose one

| Answer | Score |
|---|---|
| Yes, always | 2 |
| Sometimes | 1 |
| Not really | 0 |

**31. How often do you feel lonely on campus?**  
`o_lonely` · Choose one

| Answer | Score |
|---|---|
| Never | 3 |
| Rarely | 2 |
| Sometimes | 1 |
| Often | 0 |

## Section 9. Campus environment and access to services

_Food, spaces and health services on campus._

**32. How easy is it to find healthy, affordable food on campus?**  
`c_food` · 1 to 5 rating

| Answer | Score |
|---|---|
| Very hard | 0 |
| Hard | 1 |
| Okay | 2 |
| Easy | 3 |
| Very easy | 4 |

**33. Have you used the university health centre this academic year?**  
`c_health_centre` · Choose one

- Yes
- No, I did not need to
- No, I needed to but did not go

**34. What makes it hard to use campus health services?**  
`c_barriers` · Choose all that apply

> Select all that apply.

- Not sure what is offered
- Opening hours
- Waiting time
- Privacy worries
- Distance or transport
- Feeling uncomfortable asking
- Nothing, it is easy

## Section 10. Student voice and institutional priorities

_What the university should do next._

**35. What are your main challenges right now?**  
`v_challenges` · Choose all that apply · up to 3

> Pick up to three.

- Academic workload or exams
- Stress, low mood or emotional difficulties
- Money problems
- Cost or availability of healthy food
- Skipping breakfast or irregular meals
- Not enough physical activity
- Poor sleep
- Smoking or substance use
- Getting healthcare or counselling
- Accommodation or transport
- Something else
- Prefer not to say

**36. Pick up to three things the university should prioritise for student health.**  
`v_priorities` · Choose all that apply · up to 3

- Healthier canteen food
- Affordable meals
- Mental health and counselling
- Sports and fitness facilities
- Drinking water stations
- Better exam and study scheduling
- Regular health screenings
- Safer, cleaner hostels
- Health workshops and education

**37. What is the biggest problem affecting student health or well-being at your university?**  
`v_problem` · Free text (optional) · optional

> Optional. Please do not include names or anything that could identify you.

**38. What change or support would you most like the university to provide?**  
`v_change` · Free text (optional) · optional

> Optional. Please do not include names or anything that could identify you.

## Section 11. Clinical measurements

_Your latest measured values. Skip any you do not have._

**39. Did you get your measurements at the university health centre?**  
`k_source` · Choose one

> Only enter values that were measured, not guesses.

- Yes, at the university health centre
- No, at another clinic, hospital or pharmacy
- No, I measured them myself
- I don't have recent measurements

**40. When were they measured?**  
`k_when` · Choose one · asked only if measurements are available

- In the last week
- In the last month
- In the last 6 months
- More than 6 months ago

**41. Height**  
`k_height` · Number · optional · cm, 100 to 230 · pre-filled from the student's profile · asked only if measurements are available

**42. Weight**  
`k_weight` · Number · optional · kg, 25 to 250 · pre-filled from the student's profile · asked only if measurements are available

**43. Waist circumference**  
`k_waist` · Number · optional · cm, 40 to 200 · pre-filled from the student's profile · asked only if measurements are available

**44. Hip circumference**  
`k_hip` · Number · optional · cm, 50 to 200 · pre-filled from the student's profile · asked only if measurements are available

**45. Blood pressure, upper number (systolic)**  
`k_sbp` · Number · optional · mmHg, 70 to 250 · pre-filled from the student's profile · asked only if measurements are available

**46. Blood pressure, lower number (diastolic)**  
`k_dbp` · Number · optional · mmHg, 40 to 150 · pre-filled from the student's profile · asked only if measurements are available

**47. Fasting blood glucose**  
`k_fbg` · Number · optional · mg/dL, 40 to 500 · pre-filled from the student's profile · asked only if measurements are available

> Only from a fasting test (nothing to eat for 8 hours).

**48. Triglycerides**  
`k_tg` · Number · optional · mg/dL, 20 to 1500 · pre-filled from the student's profile · asked only if measurements are available

**49. Total cholesterol**  
`k_chol` · Number · optional · mg/dL, 60 to 600 · pre-filled from the student's profile · asked only if measurements are available

## Validated items

- **PHQ-2** (questions `e_phq1`, `e_phq2`): Kroenke, Spitzer & Williams (2003), *Medical Care* 41(11):1284-1292. Wording is unchanged. Each item is scored 0 (not at all) to 3 (nearly every day); a total of 3 or more is a positive screen. A positive screen is never a diagnosis: the student is shown the counsellor, the 1926 mental health helpline and the anonymous consultation option. In the domain score the items are reversed so that a higher score stays healthier.
- The diet questions are **indicators**, not a validated composite score. Analyse them item by item.
- Substance-use questions are optional and sensitive; confirm wording, ethics approval and referral procedures with the supervisor and health team before each round.
