/*************************************************************************************
Author: Kylie
Date: 3/6/2018

Purpose: import, examine, analyze and report on real estate data to answer questions
**************************************************************************************/

proc datasets lib=work nolist kill; quit;

libname out "\\epsilondc1.epsiloneconomics.com\FileShares\Documents\Public Folders\Kylie Zhang\sample data";

options mlogic mprint label COMPRESS=YES;

%let path1=\\epsilondc1.epsiloneconomics.com\FileShares\Documents\Public Folders\Kylie Zhang\sample data\Raw Data;
%let path2=\\epsilondc1.epsiloneconomics.com\FileShares\Documents\Public Folders\Kylie Zhang\sample data\Output;

%macro output(file, sheet);
proc export data=&file. outfile="&path2.\presentation examples.xlsx" replace; sheet = "&sheet."; run;
%mend;

/***********************************************************
READ IN
***********************************************************/
data homes;
infile "&path1.\Homes.csv"
	delimiter=',' missover dsd firstobs=1 lrecl=32767; 
input 
	ID : $10.
	street : $50.
;
run;

data transaction;
infile "&path1.\Transaction.csv"
	delimiter=',' missover dsd firstobs=1 lrecl=32767; 
input 
	ID : $10.
	sale_date : yymmdd10.
	sale_amount : best32.
	z_amount : best32.
;
format sale_amount z_amount dollar32.2
	sale_date mmddyy10.;
run;

data Zestimate;
infile "&path1.\ZestimateHistory.csv"
	delimiter=',' missover dsd firstobs=1 lrecl=32767; 
input 
	z_date : yymmdd10.
	ID : $10.
	zestimate : best32.
;
format zestimate dollar32.2
	z_date mmddyy10.;
run;

proc freq data=homes noprint order=freq; tables ID /missing out=ID_homes; run;
proc freq data=transaction noprint order=freq; tables ID /missing out=ID_transaction; run;
proc freq data=zestimate noprint order=freq; tables ID /missing out=ID_zestimate; run;

/***********************************************************
MERGE
***********************************************************/
proc sql;
create table Transaction_1 as 
select a.ID, upcase(a.street) as street, b.ID as ID_tran, b.sale_date, b.sale_amount, b.z_amount
from homes as a full join transaction as b
on a.ID=b.ID
order by upcase(a.street), a.ID, b.ID, b.sale_date;
quit;

proc sql;
create table Zestimate_1 as 
select a.ID, upcase(a.street) as street, c.z_date, c.ID as ID_z, c.zestimate
from homes as a full join zestimate as c
on a.ID=c.ID
order by upcase(a.street), a.ID, c.z_date;
quit;

proc sql;
create table master as 
select case when a.ID_tran ne "" then a.ID else b.ID end as ID, case when a.ID_tran ne "" then a.street else b.street end as street,
	case when a.ID_tran ne "" then mdy(month(a.sale_date),1,year(a.sale_date)) else b.z_date end as date format mmddyy10.,
	a.ID_tran, a.sale_date, a.sale_amount, a.z_amount, b.ID_z, b.z_date, b.zestimate
from transaction_1 as a full join zestimate_1 as b 
on a.ID=b.ID and a.street=b.street and mdy(month(a.sale_date),1,year(a.sale_date))=b.z_date 
order by street, ID, date, b.z_date;
quit;

data master_1; set master; if ID ne ""; run;
proc freq data=master_1 noprint order=freq; tables ID /missing out=ID_master; run;

data chk_1; set master_1 (where=(ID_z="" and ID_tran="")); run;

/***********************************************************
q2: TOP 5 AND BOTTOM 5
***********************************************************/
*top 5 and bottom 5;
proc sql outobs=5;
create table sold_top5 as
select *, "TOP" as source format $10.
from transaction_1
where year(sale_date)=2007
order by sale_amount desc;
quit;

proc sql outobs=5;
create table sold_bottom5 as
select *, "Bottom" as source format $10.
from transaction_1
where year(sale_date)=2007
order by sale_amount;
quit;

data sold_tail; set sold_bottom5 sold_top5; run;
%output(sold_tail, top5 and bottom5 transactions);

*compare to same ID;
proc sql;
create table sold_same_ID as
select *
from transaction_1 
where ID in (select distinct ID from sold_tail)
order by ID, street, sale_amount desc;
quit;

*compare to same street;
proc sql;
create table sold_same_street as
select street, count(*) as count, median(case when year(sale_date)>=2006 then sale_amount else . end) as median_sale_0607 format dollar32.2, 
median(case when year(sale_date)=2007 then sale_amount else . end) as median_sale_2007 format dollar32.2
from transaction_1
where street in (select distinct street from sold_tail) and year(sale_date)>=2006
group by street;
quit;

%output(sold_same_id, transaction ID);
%output(sold_same_street, transaction street);

/***********************************************************
q3: MEAN, MEDIAN, MIN, MAX of Zestimate (by street)
***********************************************************/
*only zestimate data;
c

*include zestimate on property sold;
proc sql;
create table zestimate_sum_all as
select unique street, count(*) as count, min(case when zestimate ne . then zestimate else z_amount end) as min_amount format dollar32.2, 
mean(case when zestimate ne . then zestimate else z_amount end) as mean_amount format dollar32.2, 
median(case when zestimate ne . then zestimate else z_amount end) as median_amount format dollar32.2, 
max(case when zestimate ne . then zestimate else z_amount end) as max_amount format dollar32.2
from master_1
where ID ne "" and year(date)=2007
group by street
order by count desc, street;
quit;

*compare with or without zestimate on property sold;
proc sql;
create table zestimate_sum_1 as 
select a.*, b.count as count_total, b.median_amount as median_amount_total, a.median_amount/b.median_amount-1 as diff
from zestimate_sum as a left join zestimate_sum_all as b
on a.street=b.street
order by count desc, street;
quit;

%output(zestimate_sum_1, Zestimate 2007);

/***********************************************************
q4: MEAN, MEDIAN of Zestimate (all homes by year)
***********************************************************/
*only zestimate data;
proc sql;
create table zestimate_sum_yr as
select unique year(z_date) as year, count(*) as count format comma32., 
min(zestimate) as min_amount format dollar32.2, mean(zestimate) as mean_amount format dollar32.2, 
median(zestimate) as median_amount format dollar32.2, max(zestimate) as max_amount format dollar32.2
from zestimate_1
where ID_z ne "" 
group by year(z_date);
quit;

*include zestimate on property sold;
proc sql;
create table zestimate_sum_yr_all as
select unique year(date) as year, count(*) as count format comma32., 
min(case when zestimate ne . then zestimate else z_amount end) as min_amount format dollar32.2, 
mean(case when zestimate ne . then zestimate else z_amount end) as mean_amount format dollar32.2, 
median(case when zestimate ne . then zestimate else z_amount end) as median_amount format dollar32.2, 
max(case when zestimate ne . then zestimate else z_amount end) as max_amount format dollar32.2
from master_1
where ID ne ""
group by year(date);
quit;

*compare with or without zestimate on property sold;
proc sql;
create table zestimate_sum_yr_1 as 
select a.*, b.count as count_total, b.median_amount as median_amount_total, a.median_amount/b.median_amount-1 as diff
from zestimate_sum_yr as a left join zestimate_sum_yr_all as b
on a.year=b.year;
quit;

*street="STONE WAY N";
proc sql;
create table zestimate_sum_yr_stone as
select unique year(date) as year, count(*) as count format comma32., 
min(case when zestimate ne . then zestimate else z_amount end) as min_amount format dollar32.2, 
mean(case when zestimate ne . then zestimate else z_amount end) as mean_amount format dollar32.2, 
median(case when zestimate ne . then zestimate else z_amount end) as median_amount format dollar32.2, 
max(case when zestimate ne . then zestimate else z_amount end) as max_amount format dollar32.2
from master_1
where ID ne "" and street="STONE WAY N" 
group by year(date);
quit;

proc sql;
create table zestimate_sum_yr_2 as 
select a.*, b.median_amount as median_stone, b.mean_amount as mean_stone
from zestimate_sum_yr as a left join zestimate_sum_yr_stone as b
on a.year=b.year;
quit;

%output(zestimate_sum_yr, ZHVI by year);
%output(zestimate_sum_yr_2, ZHVI by year Stone);
/***********************************************************
q5: percentage error, median, by year
***********************************************************/
*calulate error and then aggregate
OR aggregate and then calculate error;

proc sql;
create table transaction_sum_yr as
select unique year(sale_date) as year, count(*) as count format comma32., 
median((z_amount-sale_amount)/sale_amount) as median_error,
median(sale_amount) as sale_amount format dollar32.2, median(z_amount) as z_amount format dollar32.2
from transaction
group by year(sale_date);
quit;

%output(transaction_sum_yr, error);

data chk_2; set transaction (where=(sale_amount>z_amount)); run;
data chk_3; set transaction (where=(sale_amount<z_amount)); run;

proc sql;
create table zestimate_sold as
select unique year(z_date) as year, count(*) as sold_count format comma32., 
median(zestimate) as sold_median format dollar32.2, mean(zestimate) as sold_mean format dollar32.2
from zestimate
where id in (select unique id from transaction)
group by year(z_date);
quit;

proc sql;
create table zestimate_not_sold as
select unique year(z_date) as year, count(*) as count format comma32., 
median(zestimate) as median format dollar32.2, mean(zestimate) as mean format dollar32.2
from zestimate
where id not in (select unique id from transaction)
group by year(z_date);
quit;

data zestimate_two; merge zestimate_sold zestimate_not_sold; by year; run;
proc ttest data=zestimate_two;
paired sold_mean*mean;
run;
proc ttest data=zestimate_two;
paired sold_median*median;
run;
%output(zestimate_two, two populations);

/***********************************************************
q6: New Index
***********************************************************/
proc sql;
create table zestimate_street_yr as
select unique street, year(z_date) as year, count(*) as count format comma32., 
median(zestimate) as median_zestimate format dollar32.2
from zestimate_1
where ID_z ne ""
group by street, year;
quit;

proc sql;
create table zestimate_2 as
select a.*, b.year, b.count, b.median_zestimate
from zestimate_1 as a left join zestimate_street_yr as b
on a.street=b.street and year(a.z_date)=b.year
where ID_z ne ""
group by a.street, year(a.z_date);
quit;

proc sql;
create table ZHVI as
select unique year(z_date) as year, count(*) as count format comma32., 
median(zestimate) as zestimate format dollar32.2, median(median_zestimate) as median_zestimate format dollar32.2
from zestimate_2
group by year(z_date);
quit;

proc sql;
create table ZHVI_1 as
select a.*, b.median_error, a.median_zestimate/(1+b.median_error) as ZHVI_adj format dollar32.2
from ZHVI as a left join transaction_sum_yr as b
on a.year=b.year;
quit;

%output(ZHVI_1, ZHVI adj);

