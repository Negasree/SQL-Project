-- OBJECTIVE QUESTIONS

-- Q1. List the different dtypes of columns in table “ball_by_ball” (using information schema)
select 
	column_name,
    data_type
from information_schema.columns
where table_name = "ball_by_ball" and table_schema = "ipl";

-- Q2. What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)
with Score as (select 
	b.Match_id,
    b.Over_Id,
    b.Ball_Id,
    b.Innings_No,
    m.Season_Id,
    b.Team_Batting,
    t1.Team_Name as Batting_Team_Name,
    b.Team_Bowling,
    t2.Team_Name as Bowling_Team_Name,
    b.Runs_Scored,
    coalesce(e.Extra_Runs,0) as Extra_Runs
from ball_by_ball b join team t1 
on t1.Team_Id = b.Team_Batting 
join team t2  on t2.Team_Id = b.Team_Bowling
join matches m on m.Match_Id = b.Match_Id 
left join extra_runs e on e.Match_Id = b.Match_Id 
and e.Over_Id = b.Over_Id 
and e.Ball_Id = b.Ball_Id
and e.Innings_No = b.Innings_No)
select 
	sum(Runs_Scored + Extra_Runs) as Total_Runs
from Score 
where Season_Id = (select min(Season_Id) from Score)
and Batting_Team_Name = "Royal Challengers Bangalore";

-- Q3. How many players were more than the age of 25 during season 2014?
with playercount as (select 
	count(distinct p.Player_Id) as PlayerCountAbove25,
    s.Season_Id,
    s.Season_Year
from player p join player_match pm 
on p.Player_Id = pm.Player_Id
join matches m on m.Match_Id = pm.Match_Id
join season s on s.Season_Id = m.Season_Id
where s.Season_Year = 2014 
and timestampdiff(year, p.DOB, m.Match_Date) > 25
group by s.Season_Id, s.Season_Year)
select 
	PlayerCountAbove25
from playercount;

-- Q4. How many matches did RCB win in 2013? 
select
	t.team_Id,
    t.Team_Name,
	count(m.Match_Winner) as win_count
from matches m join season s 
on s.Season_Id = m.Season_Id
join team t 
on m.Match_Winner = t.Team_Id
where t.Team_Name = "Royal Challengers Bangalore"
and Season_Year = 2013
group by t.team_Id;

-- Q5. List the top 10 players according to their strike rate in the last 4 seasons
with seasonYear as (select 
	Season_Year
from season 
order by Season_Year desc
limit 4)
select 
	p.Player_Name,
    sum(b.Runs_Scored) as totalRuns,
    nullif(count(b.Ball_Id),0) as balls_faced,
	round((sum(b.Runs_Scored) * 100 )/ nullif(count(b.Ball_Id),0),2) as strike_rate
from ball_by_ball b join matches m on b.Match_Id = m.Match_Id
join player p on p.Player_Id = b.Striker
join season s on s.Season_Id = m.Season_Id
join seasonYear sy on sy.Season_Year = s.Season_Year
left join extra_runs e on e.Match_Id = b.Match_Id
and e.Over_Id = b.Over_Id 
and e.Ball_Id = b.Ball_Id 
and e.Innings_No = b.Innings_No
where e.Extra_Runs is null
group by p.Player_Name, b.Striker
order by strike_rate desc
limit 10;

-- Q6. What are the average runs scored by each batsman considering all the seasons?
select 
  p.player_name,
  round(sum(b.runs_scored)/ count(distinct Match_Id), 2) as average_runs
from ball_by_ball b
join player p on p.player_id = b.striker
group by p.player_name
order by average_runs desc;

    
-- Q7. What are the average wickets taken by each bowler considering all the seasons?
select
	p.Player_Name,
    count(wc.Player_Out) as wickets,
    count(distinct b.Match_Id) as Matches_played,
	round(count(wc.Player_Out)/count(distinct b.Match_Id),2) as avg_wickets_taken
from wicket_taken wc left join ball_by_ball b
on wc.Match_Id = b.Match_Id 
and wc.Over_Id = b.Over_Id
and wc.Ball_Id = b.Ball_Id 
and wc.Innings_No = b.Innings_No 
join player p on p.Player_Id = b.Bowler
group by p.Player_Name
order by avg_wickets_taken desc;

-- Q8. List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average
with avg_runs as (select 
  p.player_name,
  round(sum(b.runs_scored)*1.0 / count(distinct Match_Id), 2) as average_runs
from ball_by_ball b
join player p on p.player_id = b.striker
group by p.player_name),

overall_avg_runs as (select
	avg(average_runs) as overall_ar 
    from avg_runs),
    
avg_wickets as (select
	p.Player_Name,
	round(count(wc.Player_Out)* 1.0/count(distinct b.Match_Id),2) as avg_wickets_taken
from wicket_taken wc left join ball_by_ball b
on wc.Match_Id = b.Match_Id 
and wc.Over_Id = b.Over_Id
and wc.Ball_Id = b.Ball_Id 
and wc.Innings_No = b.Innings_No 
join player p on p.Player_Id = b.Bowler
group by p.Player_Name),

overall_avg_wickets as (select 
	avg(avg_wickets_taken) as overall_aw 
    from avg_wickets)

select 
	ar.Player_Name
from avg_runs ar join avg_wickets aw
on ar.Player_Name = aw.Player_Name
join overall_avg_runs oar on ar.average_runs > oar.overall_ar
join overall_avg_wickets oaw on aw.avg_wickets_taken > oaw.overall_aw;

-- Q9. Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
create table rcb_record as (select
	v.Venue_Name,
    count(*) as total_matches,
    sum(case when m.Match_Winner = t.Team_Id then 1 else 0 end) as wins,
    sum(case when m.Match_Winner <> Team_Id and (m.Team_1 = Team_Id or m.Team_2 = Team_Id) then 1 else 0 end) as losses,
    sum(case when m.Match_Winner is null then 1 else 0 end) as no_result
from venue v join matches m on v.Venue_Id = m.Venue_Id
join team t on t.Team_Name = "Royal Challengers Bangalore" 
where (t.Team_Id = m.Team_1 or t.Team_Id = m.Team_2)
group by v.Venue_Name);
select * from rcb_record;

-- Q10. What is the impact of bowling style on wickets taken?
select 
	bs.Bowling_skill as bowling_style,
    count(w.Player_Out) as total_wickets
from ball_by_ball b join wicket_taken w
on w.Match_Id = b.Match_Id 
and w.Over_Id = b.Over_Id 
and w.Ball_Id = b.Ball_Id
and w.Innings_No = b.Innings_No
join player p on p.Player_Id = b.Bowler 
join bowling_style bs on bs.Bowling_Id = p.Bowling_skill
group by bs.Bowling_skill
order by total_wickets desc;

-- Q11. Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance 
--          on the basis of the number of runs scored by the team in the season and the number of wickets taken 
with team_performance as (select
	t.Team_Name,
    s.Season_Year,
    sum(b.Runs_Scored) as Runs_scored,
    count(w.Player_Out) as Wickets_taken
from team t join player_match p on p.Team_Id = t.Team_Id
join matches m on m.Match_Id = p.Match_Id 
join season s on s.Season_Id = m.Season_Id 
left join ball_by_ball b on b.Match_Id = p.Match_Id and b.Striker = p.Player_Id
left join ball_by_ball b1 on b1.Match_Id = p.Match_Id and b1.Bowler = p.Player_Id
left join wicket_taken w on w.Match_Id = b1.Match_Id and w.Over_Id = b1.Over_Id 
	and w.Ball_Id = b1.Ball_Id and w.Innings_No = b1.Innings_No
group by t.Team_Name, s.Season_Year)
select
	t1.Team_Name,
    t1.Season_Year as Previous_year,
    t2.Season_Year as Current_Year,
    t1.Runs_scored as Previous_year_runs,
    t2.Runs_scored as Current_year_runs,
    t1.Wickets_taken as Previous_year_wickets,
    t2.Wickets_taken as Current_year_Wickets,
    case
		when t2.Runs_scored > t1.Runs_scored and t2.Wickets_taken > t1.Wickets_taken then "Overall Improved"
        when t2.Runs_scored = t1.Runs_scored and t2.Wickets_taken = t1.Wickets_taken then "Same"
        when t2.Runs_scored > t1.Runs_scored and t2.Wickets_taken <=t1.Wickets_taken then "Batting Improved"
		when t2.Runs_scored < t1.Runs_scored and t2.Wickets_taken >= t1.Wickets_taken then "Wickets Improved"
		else "Worse"
	end as Performance_status
from team_performance t1 join team_performance t2 
on t1.Team_Name = t2.Team_Name and t1.Season_Year = t2.Season_Year - 1
order by t1.Team_Name, t1.Season_Year;

-- Q12. Can you derive more KPIs for the team strategy?
-- 1.Boundary Frequency Percentage
select 
	p.Player_Name,
    (sum(case when b.Runs_Scored in (4,6) then 1 else 0 end)* 100 / count(*)) as Boundary_frequency
from player p join ball_by_ball b 
on p.Player_Id = b.Striker
group by p.Player_Name
order by Boundary_frequency desc;

-- 2.Death Over Performance
select
	P.Player_Name as Batsman_Name,
	p1.Player_Name as Bowler_Name,
	t.Team_Name as Batting_team,
	t1.Team_Name as Bowler_team,
    sum(b.Runs_Scored) as Death_over_runs,
    count(w.Player_Out) as Death_over_wickets
from ball_by_ball b left join wicket_taken w
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
join team t on t.Team_Id = b.Team_Batting join team t1 on t1.Team_Id = b.Team_Bowling
join player p on p.Player_Id = b.Striker join player p1 on p1.Player_Id = b.Bowler
where b.Over_Id between 17 and 20
group by p.Player_Name, t.Team_Name, p1.Player_Name, t1.Team_Name, b.Team_Batting, b.Team_Bowling
order by Death_over_runs desc, Death_over_wickets desc;

-- 3.Powerplay performance
select 
	P.Player_Name as Batsman_Name,
	p1.Player_Name as Bowler_Name,
	t.Team_Name as Batting_team,
	t1.Team_Name as Bowler_team,
	sum(b.Runs_Scored) as Powerplay_runs,
    count(w.Player_Out) as Powerplay_wickets
from ball_by_ball b left join wicket_taken w
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
join team t on t.Team_Id = b.Team_Batting join team t1 on t1.Team_Id = b.Team_Bowling
join player p on p.Player_Id = b.Striker join player p1 on p1.Player_Id = b.Bowler
where b.Over_Id between 1 and 6
group by p.Player_Name, t.Team_Name, p1.Player_Name, t1.Team_Name, b.Team_Batting, b.Team_Bowling
order by Powerplay_runs desc, Powerplay_wickets desc;

-- 4.Average Contribution by top order
with first_three_batters as (select 
	distinct Match_Id,
    Team_Batting,
    Striker
from (select 
	Match_Id,
    Team_Batting,
    Striker,
    row_number() over(partition by Match_Id, Team_Batting order by Over_Id, Ball_Id) as entry_order
from ball_by_ball) rs where entry_order <=3),

top_order_stats as (select
	m.Match_Id,
    t.Team_Name,
    sum(case when f.Striker is not null then b.Runs_Scored else 0 end) as top_order_runs,
    sum(b.Runs_Scored) as match_total_runs
from matches m join ball_by_ball b on m.Match_Id = b.Match_Id
join team t on t.Team_Id = b.Team_Batting
left join first_three_batters f on f.Match_Id = b.Match_Id 
and f.Team_Batting = b.Team_Batting and f.Striker = b.Striker
group by m.Match_Id, t.Team_Name)

select 
	Team_Name,
    round(avg((top_order_runs * 1.0 / match_total_runs)* 100),2) as Avg_Top_Order_Contribution
from top_order_stats
group by Team_Name
order by Avg_Top_Order_Contribution desc;

-- 5.Powerplay Strike Rate
select
	p.Player_Name,
    round(sum(b.Runs_Scored)*100/count(*),2) as Strike_Rate
from ball_by_ball b join player p 
on p.Player_Id = b.Striker
where b.Over_Id between 1 and 6
group by p.Player_Name
having count(*) > 20
order by Strike_Rate desc;

-- Q13. Using SQL, write a query to find out the average wickets taken by each bowler in each venue. 
-- Also, rank the gender according to the average value.
with wickets_per_venue as (
    select 
        p.player_id, 
        p.player_name, 
        v.venue_name,
        count(wt.player_out) as total_wickets, 
        count(distinct m.match_id) as total_matches,
        round(count(wt.player_out) * 1.0 / count(distinct m.match_id), 2) as avg_wickets
    from player p
    join ball_by_ball bb on p.player_id = bb.bowler
    join matches m on bb.match_id = m.match_id
    join wicket_taken wt on bb.match_id = wt.match_id 
                         and bb.over_id = wt.over_id 
                         and bb.ball_id = wt.ball_id
    join venue v on m.venue_id = v.venue_id
    group by p.player_id, p.player_name, v.venue_name
)
select 
    player_id, 
    player_name, 
    venue_name, 
    total_wickets, 
    total_matches, 
    avg_wickets,
    rank() over (order by avg_wickets desc) as wicket_rank
from wickets_per_venue
order by wicket_rank;


-- Q14. 14.	Which of the given players have consistently performed well in past seasons?
-- (will you use any visualization to solve the problem)
with player_season_performance as (select
    p.Player_Name,
    s.Season_Year,
    sum(case when b.Striker = p.Player_Id then b.Runs_Scored else 0 end) as total_runs,
    count(distinct case when w.Player_Out = p.Player_Id then b.Match_Id else 0 end) as total_wickets
from player p left join ball_by_ball b 
on p.Player_Id = b.Striker or p.Player_Id = b.Bowler
left join matches m on m.Match_Id = b.Match_Id
left join season s on s.Season_Id = m.Season_Id
left join wicket_taken w 
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
group by p.Player_Name, s.Season_Year)
select
	Player_Name,
    count(distinct Season_Year) as Seasons_Played,
    round(avg(total_runs),2) as avg_runs_per_season,
    round(avg(total_wickets),2) as avg_wickets_per_season
from player_season_performance
group by Player_Name
having count(distinct Season_Year) > 2
order by avg_runs_per_season desc, avg_wickets_per_season desc;

-- Q15. Are there players whose performance is more suited to specific venues or conditions? 
-- (how would you present this using charts?) 
with player_venue_performance as (select
    p.Player_Name,
    v.Venue_Name,
    sum(case when b.Striker = p.Player_Id then b.Runs_Scored else 0 end) as total_runs,
    count(distinct case when w.Player_Out = p.Player_Id then b.Match_Id else 0 end) as total_wickets
from player p left join ball_by_ball b 
on p.Player_Id = b.Striker or p.Player_Id = b.Bowler
left join matches m on m.Match_Id = b.Match_Id
left join venue v on v.Venue_Id = m.Venue_Id
left join wicket_taken w 
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
group by p.Player_Name, v.Venue_Name)
select
	Player_Name,
    Venue_Name,
    round(avg(total_runs),2) as avg_runs,
    round(avg(total_wickets),2) as avg_wickets
from player_venue_performance
group by Player_Name, Venue_Name
having round(avg(total_runs),2) > 30
and  round(avg(total_wickets),2) > 5
order by avg_runs desc, avg_wickets desc;

-- Subjective Questions
-- 1.How does the toss decision affect the result of the match? (which visualizations could be used to 
-- present your answer better) And is the impact limited to only specific venues?
select 
	v.Venue_Name,
    t.Toss_Name as toss_decision,
    count(*) as Total_matches,
    sum(case when m.Toss_Winner = m.Match_Winner then 1 else 0 end) as matches_won_after_toss,
    round(sum(case when m.Toss_Winner = m.Match_Winner then 1 else 0 end) *100 / count(*),2) as win_percentage
from venue v join matches m on v.Venue_Id = m.Venue_Id
join team tm on tm.Team_Id = m.Toss_Winner
join toss_decision t on t.Toss_Id = m.Toss_Decide
where m.Match_Winner is not null
group by v.Venue_Name, t.Toss_Name
order by Total_matches desc, win_percentage desc;

-- Q2. Suggest some of the players who would be best fit for the team.
with player_season_performance as (select
    p.Player_Name,
    s.Season_Year,
    sum(case when b.Striker = p.Player_Id then b.Runs_Scored end) as total_runs,
    count(distinct case when w.Player_Out = p.Player_Id then b.Match_Id else 0 end) as total_wickets
from player p left join ball_by_ball b 
on p.Player_Id = b.Striker or p.Player_Id = b.Bowler
left join matches m on m.Match_Id = b.Match_Id
left join season s on s.Season_Id = m.Season_Id
left join wicket_taken w 
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
group by p.Player_Name, s.Season_Year)
select
	Player_Name,
    count(distinct Season_Year) as Seasons_Played,
    round(avg(total_runs),2) as avg_runs_per_season,
    round(avg(total_wickets),2) as avg_wickets_per_season
from player_season_performance
group by Player_Name
having count(distinct Season_Year) > 2
order by avg_runs_per_season desc, avg_wickets_per_season desc;

-- Q3. What are some of the parameters that should be focused on while selecting the players?
with player_stats as (select
	p.Player_Name,
    count(distinct m.Match_Id) as matches_played,
    sum(case when b.Striker = p.Player_Id then b.Runs_Scored else 0 end) as total_runs,
    count(case when b.Striker = p.Player_Id then 1 end) as balls_faced,
    count(case when b.Bowler = p.Player_Id then 1 end) as balls_bowled,
    sum(case when b.Bowler = p.Player_Id then b.Runs_Scored else 0 end) as runs_conceded,
    count(case when wt.Player_Out = p.Player_Id then 1 end) as wickets_taken
from player p join player_match pm
on p.Player_Id = pm.Player_Id
join matches m on m.Match_Id = pm.Match_Id
left join ball_by_ball b on b.Match_Id = m.Match_Id 
and (b.Striker = p.Player_Id or b.Bowler = p.Player_Id)
left join wicket_taken wt on wt.Match_Id = b.Match_Id
and wt.Over_Id = b.Over_Id
and wt.Ball_Id = b.Ball_Id
and wt.Innings_No = b.Innings_No 
group by p.Player_Name)
select
	Player_Name,
    matches_played,
    total_runs,
    balls_faced,
    round(case when balls_faced > 0 then (total_runs * 100) / balls_faced else 0 end, 2) as strike_rate,
    wickets_taken,
    balls_bowled,
    round(case when balls_bowled > 0 then (runs_conceded * 100) / balls_bowled else 0 end, 2) as economy_rate
from player_stats
order by total_runs desc, wickets_taken desc;

-- Q4. Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)
with player_stats as (select
	p.Player_Name,
	count(distinct m.Match_Id) as matches_played,
	sum(case when b.Striker = p.Player_Id then b.Runs_Scored else 0 end) as total_runs,
	count(case when b.Striker = p.Player_Id then 1 end) as balls_faced,
	count(case when b.Bowler = p.Player_Id then 1 end) as balls_bowled,
	sum(case when b.Bowler = p.Player_Id then b.Runs_Scored else 0 end) as runs_conceded,
	count(case when wt.Player_Out = p.Player_Id then 1 end) as wickets_taken
from player p join player_match pm
on p.Player_Id = pm.Player_Id
join matches m on m.Match_Id = pm.Match_Id
left join ball_by_ball b on b.Match_Id = m.Match_Id 
and (b.Striker = p.Player_Id or b.Bowler = p.Player_Id)
left join wicket_taken wt on wt.Match_Id = b.Match_Id
and wt.Over_Id = b.Over_Id
and wt.Ball_Id = b.Ball_Id
and wt.Innings_No = b.Innings_No 
group by p.Player_Name)
select
	Player_Name,
	matches_played,
   	total_runs,
	balls_faced,
	round(case when balls_faced > 0 then (total_runs * 100) / balls_faced else 0 end, 2) as strike_rate,
	wickets_taken,
	balls_bowled,
	round(case when balls_bowled > 0 then (runs_conceded * 100) / balls_bowled else 0 end, 2) as economy_rate
from player_stats
where total_runs > 500 and wickets_taken > 20
order by total_runs desc, wickets_taken desc;

-- Q5. Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)
select
	p.Player_Name,
    t.Team_Name,
    count(distinct pm.Match_Id) as matches_played,
    sum(case when m.Match_Winner = pm.Team_Id then 1 else 0 end) as matches_won,
    round(100 * sum(case when m.Match_Winner = pm.Team_Id then 1 else 0 end) / count(distinct pm.Match_Id), 2) as matches_won_percentage
from player_match pm join matches m 
on pm.Match_Id = m.Match_Id
join team t on t.Team_Id = pm.Team_Id 
join player p on p.Player_Id = pm.Player_Id
where m.Match_Winner is not null
group by p.Player_Name, t.Team_Name
having count(distinct pm.Match_Id) > 10
order by matches_won_percentage desc;

-- Q7. What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies
-- 1. Home-ground influence
with player_venue_performance as (select
    p.Player_Name,
    v.Venue_Name,
    sum(case when b.Striker = p.Player_Id then b.Runs_Scored else 0 end) as total_runs,
    count(distinct case when w.Player_Out = p.Player_Id then b.Match_Id else 0 end) as total_wickets
from player p left join ball_by_ball b 
on p.Player_Id = b.Striker or p.Player_Id = b.Bowler
left join matches m on m.Match_Id = b.Match_Id
left join venue v on v.Venue_Id = m.Venue_Id
left join wicket_taken w 
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
group by p.Player_Name, v.Venue_Name)
select
	Player_Name,
    Venue_Name,
    round(avg(total_runs),2) as avg_runs,
    round(avg(total_wickets),2) as avg_wickets
from player_venue_performance
group by Player_Name, Venue_Name
having round(avg(total_runs),2) > 30
and  round(avg(total_wickets),2) > 5
order by avg_runs desc, avg_wickets desc;

-- 2. Toss-decision impact
select 
	v.Venue_Name,
    t.Toss_Name as toss_decision,
    count(*) as Total_matches,
    sum(case when m.Toss_Winner = m.Match_Winner then 1 else 0 end) as matches_won_after_toss,
    round(sum(case when m.Toss_Winner = m.Match_Winner then 1 else 0 end) *100 / count(*),2) as win_percentage
from venue v join matches m on v.Venue_Id = m.Venue_Id
join team tm on tm.Team_Id = m.Toss_Winner
join toss_decision t on t.Toss_Id = m.Toss_Decide
where m.Match_Winner is not null
group by v.Venue_Name, t.Toss_Name
order by Total_matches desc, win_percentage desc;

-- 3.Death Over Performance
select
	P.Player_Name as Batsman_Name,
	p1.Player_Name as Bowler_Name,
	t.Team_Name as Batting_team,
	t1.Team_Name as Bowler_team,
    sum(b.Runs_Scored) as Death_over_runs,
    count(w.Player_Out) as Death_over_wickets
from ball_by_ball b left join wicket_taken w
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
join team t on t.Team_Id = b.Team_Batting join team t1 on t1.Team_Id = b.Team_Bowling
join player p on p.Player_Id = b.Striker join player p1 on p1.Player_Id = b.Bowler
where b.Over_Id between 17 and 20
group by p.Player_Name, t.Team_Name, p1.Player_Name, t1.Team_Name, b.Team_Batting, b.Team_Bowling
order by Death_over_runs desc, Death_over_wickets desc;

-- 4.Powerplay performance
select 
	P.Player_Name as Batsman_Name,
	p1.Player_Name as Bowler_Name,
	t.Team_Name as Batting_team,
	t1.Team_Name as Bowler_team,
	sum(b.Runs_Scored) as Powerplay_runs,
    count(w.Player_Out) as Powerplay_wickets
from ball_by_ball b left join wicket_taken w
on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id 
and b.Innings_No = w.Innings_No 
join team t on t.Team_Id = b.Team_Batting join team t1 on t1.Team_Id = b.Team_Bowling
join player p on p.Player_Id = b.Striker join player p1 on p1.Player_Id = b.Bowler
where b.Over_Id between 1 and 6
group by p.Player_Name, t.Team_Name, p1.Player_Name, t1.Team_Name, b.Team_Batting, b.Team_Bowling
order by Powerplay_runs desc, Powerplay_wickets desc;

-- Q8. Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
with home_matches AS (select
	m.match_id, 
    case
		when m.team_1 = t.team_id then m.team_1
		when m.team_2 = t.team_id then m.team_2
	end as team_id, team_name, m.match_winner, v.venue_id
from matches m join team t on (m.team_1 = t.team_id or m.team_2 = t.team_id) 
join venue v on m.venue_id = v.venue_id
where (m.team_1 = t.team_id or m.team_2 = t.team_id) 
and m.venue_id = v.venue_id)
select
	team_id, 
    team_name, 
    count(*) as total_home_matches, 
    sum(case when match_winner = team_id then 1 else 0 end) as home_matches_won,
	round(sum(case when match_winner = team_id then 1 else 0 end) * 100.0 / COUNT(*), 2) as home_win_percentage
from home_matches
group by team_id, team_name
order by home_win_percentage desc;

-- Q9. Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.
with rcb_performance as (
    select
        m.season_id as season_id,
        count(m.match_id) as matches_played,
        sum(case when m.match_winner = t.team_id then 1 else 0 end) as matches_won,
        sum(case when m.match_winner != t.team_id then 1 else 0 end) as matches_lost,
        (sum(case when m.match_winner = t.team_id then 1 else 0 end) * 100.0) / count(m.match_id) as win_percentage
    from matches m
    inner join team t on t.team_id = m.team_1 or t.team_id = m.team_2
    where t.team_name = 'royal challengers bangalore'
    group by m.season_id
)
select
    s.season_year,
    rp.matches_played,
    rp.matches_won,
    rp.matches_lost,
    round(rp.win_percentage, 2) as win_percentage
from rcb_performance rp
inner join season s on rp.season_id = s.season_id
order by s.season_year;

-- Q11. In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" 
-- instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
update team
set Team_Name = 'delhi_daredevils'
where Team_Name = 'delhi_capitals';
select * from team;
