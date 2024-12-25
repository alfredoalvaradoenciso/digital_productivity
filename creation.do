
global root "C:\Users\Dell\Downloads\Digital_productivity"
*global root "C:\Users\wb446522\OneDrive - WBG\Documents\___EFI FO\___Research\Stata\May5_23"
global results "$root\results"

cd "$root"


* Converts long data to wide keeping the value labels of 1 variable as varnames
** i = variables that uniquicly identified wide data
** j = 1 var with labels that will be preserved
** v = 1 var where reshape wide v, i(i) j(j)
cap program drop reshape_save_labels
program define reshape_save_labels
    args i j v
    keep `i' `j' `v'
    levelsof `j', local(col_levels)
    foreach val of local col_levels {   
        local l`val' : label `j' `val'    
    }  
    reshape wide `v', i(`i') j(`j')
    foreach lev of local col_levels {        
        label variable `v'`lev' "`l`lev''"
    }
end


cap program drop interpolate
program interpolate
syntax anything [, n(real 0) h(real 0)]
tokenize `"`anything'"'
by `1': ipolate `3' `2', gen(`3'_1) epolate 
by `1' (`2'), sort: egen `3'_last_data_year = max(cond(!missing(`3'), `2', .))
by `1' (`2'), sort: egen `3'_first_data_year = min(cond(!missing(`3'), `2', .))
by `1': egen `3'_n_actual_values = total(!missing(`3'))
clonevar `3'2 = `3'_1 
replace `3'2 = . if `2' > `3'_last_data_year + 3
replace `3'2 = . if `2' < `3'_first_data_year - 3
local vartag: var lab `3'
local vartag2=substr("`vartag'",1,72)
label var `3'2 "`vartag2' +/-3yrs"
cap drop *_last_data_year*
cap drop *_first_data_year*
cap drop *_n_actual_values*
if `n'==1 {
replace `3'2 =0 if `3'2<0  
}
if `h'==1 {
replace `3'2 =100 if `3'2>100 & `3'2!=. 
}
drop `3'_1
end


** PISA


***** Pisa score

clear
set obs 21
gen year=_n+1999
tempfile a
save `a'

import excel "$root\Sources\IDEExcelExport-May182022-0938PM.xls", sheet("Report 1- Table") cellrange(B12:D810) firstrow clear
replace Year=Year[_n-1] if Year==""
replace Average="" if Average=="—"
replace Average="" if Average=="‡"
destring Average, replace
rename Average pisamath
tempfile b1
save  `b1'
import excel "$root\Sources\IDEExcelExport-May182022-0938PM.xls", sheet("Report 2- Table") cellrange(B12:D810) firstrow clear
replace Year=Year[_n-1] if Year==""
replace Average="" if Average=="—"
replace Average="" if Average=="‡"
destring Average, replace
rename Average pisareading
tempfile b2
save  `b2'
import excel "$root\Sources\IDEExcelExport-May182022-0938PM.xls", sheet("Report 3- Table") cellrange(B12:D810) firstrow clear
replace Year=Year[_n-1] if Year==""
replace Average="" if Average=="—"
replace Average="" if Average=="‡"
destring Average, replace
rename Average pisascience
merge 1:1 Year Jurisdiction using `b1', nogen
merge 1:1 Year Jurisdiction using `b2', nogen
drop if strmatch(Jurisdiction,"*Spain: *") | strmatch(Jurisdiction,"*United States: *") | strmatch(Jurisdiction,"*United Kingdom: *") |  strmatch(Jurisdiction,"*United Arab Emirates: *") |  strmatch(Jurisdiction,"*Russian Federation: *")
gen code=subinstr(Jurisdiction," (2015)","",.)
rename Year year
collapse (sum) pisa*, by(year code)
drop if code=="CABA (Argentina)"
drop if strmatch(code,"*China*")==1 & strmatch(code,"*Hong Kong (China)*")==0
drop if strmatch(code,"*Belgium: Flemish Community*")
replace code="Hong Kong SAR, China" if strmatch(code,"*Hong Kong (China)*")
replace code="Azerbaijan" if strmatch(code,"*Baku (Azerbaijan)*")
replace code="Vietnam" if code=="Viet Nam"
replace code="Russian Federation" if code=="Russia"
replace code="Korea, Rep." if code=="Korea"
replace code="Taiwan" if code=="Chinese Taipei"
rename code CountryName
destring year, replace
merge 1:1 CountryName year using "$root\Sources\codepopreg", nogen keep(match) keepus(code) 
sort code year
foreach v of varlist pisascience pisamath pisareading {
replace `v'=. if `v'==0
}
label var pisascience "PISA test Science"
label var pisamath "PISA test Math"
label var pisareading "PISA test Reading"
merge m:1 year using `a', nogen
fillin code year
drop if code==""
drop _fillin CountryName
compress
save  "$root\Sources\pisa", replace

**ILO


use "$root\Sources\GDP_211P_NOC_NB_A-filtered-2023-01-20", clear
rename (obs_value ref_area time) (prod_ilo code year) 
tempfile a 
save `a'
use "$root\Sources\SDG_B821_NOC_RT_A-filtered-2023-01-20", clear
rename (obs_value ref_area time) (prodgr code year) 
merge 1:1 code year using `a', nogen
drop source indicator
destring year, replace
rename _all, lower
label var prodgr "Annual growth rate output per worker PPP (const 2017 int$) ILO"
lab var prod_ilo "Output per worker (GDP constant 2017 international $ at PPP) ILO"
save "$root\Sources\ilo", replace

************** WORLD BANK
 
foreach b in WDI WGI DB Jobs {
import excel "$root\Sources\\P_`b'.xlsx", firstrow clear
tempvar b1
gen `b1'="`b'"
replace SeriesName="`b'-"+SeriesName if `b1'!="WDI"
cou
local N=`r(N)'-4
drop in `N'/`r(N)'
ds YR*
foreach v of varlist `r(varlist)' {
cap replace `v'="" if `v'==".."
cap destring `v', replace
}
tempfile `b'
save ``b''
}
clear
append using `WDI'
append using `WGI'
append using `DB'
append using `Jobs'
drop Category
reshape long YR, i(CountryName CountryCode SeriesName SeriesCode) j(year)
rename (CountryCode YR SeriesCode) (code value seriescode)
encode SeriesName, gen(col)

*Converting to panel data format and saving the variable labels
reshape_save_labels "year code" col value


lookfor "Mobile cellular subscriptions (per 100 people)"
global value1="`r(varlist)'"
rename $value1 mtelpop
lab var mtelpop "mobile cellular subscriptions per 100 total population"

lookfor "Population ages 15-64, total"
global value2="`r(varlist)'"
rename $value2 popadult

lookfor "Fixed telephone subscriptions (per 100 people)"
global value2="`r(varlist)'"
rename $value2 ftelpop

lookfor "Gross fixed capital formation (% of GDP)"
global value2="`r(varlist)'"
lab var $value2 "Investment rate"
rename  $value2 invgdp

lookfor "Employment to population ratio, 15+, total (%) (modeled ILO estimate)"
global value2="`r(varlist)'"
lab var $value2 "Employment rate"
rename $value2 emppop

lookfor "WGI-Control of Corruption: Estimate"
global value2="`r(varlist)'"
lab var  $value2 "Corruption control"
rename $value2 corrcont

lookfor "GDP per capita, PPP (constant 2017 international $)"
global value2="`r(varlist)'"
rename $value2 gdppc

lookfor "School enrollment, tertiary (% gross)"
global value2="`r(varlist)'"
lab var $value2 "Tertiary"
rename $value2 terenr

lookfor "Pupil-teacher ratio, secondary"
global value2="`r(varlist)'"
lab var  $value2 "Pupil-teacher"
rename $value2 pupilratio

lookfor "Patent applications, residents"
global value2="`r(varlist)'"
lab var  $value2 "Resident patents"
rename $value2 patent

lookfor "Research and development expenditure (% of GDP)"
global value2="`r(varlist)'"
lab var  $value2 "R&D/GDP"
rename $value2 researchgdp

lookfor "Researchers in R&D (per million people)"
global value2="`r(varlist)'"
lab var  $value2 "Researchers per million pop"
rename $value2 researchers

lookfor "Government expenditure on education, total (% of GDP)"
global value2="`r(varlist)'"
lab var  $value2 "Education/GDP"
rename $value2 education

save "$root\Sources\wbg", replace


**************************** ITU

import excel "$root\Sources\ddd_dataset_v202104.xlsx", clear firstrow
drop if Value==""
*keep if Reg=="The Americas"
replace Value="" if Value=="NULL"
destring Value , replace
drop Region ITU Country
compress
rename (ISO Indicatorname Year Value) (code SeriesName year value)
encode SeriesName, gen(col)

*Converting to panel data format and saving the variable labels
reshape_save_labels "year code" col value

compress
order code year
lookfor "Population covered by at least a 4G mobile network (%)"
global value1="`r(varlist)'"
rename $value1 mnet4g
lookfor "Population covered by at least a 3G mobile network (%)"
global value2="`r(varlist)'"
rename $value2 mnet3g
lookfor "Population covered by a mobile-cellular network (%)"
global value3="`r(varlist)'"
rename $value3 mnet_pop
lookfor "Active mobile-broadband subscriptions"
global value4="`r(varlist)'"
rename $value4 mbband
lookfor "Fixed broadband subscriptions: 256kbit/s - <2Mbit/s"
global value5="`r(varlist)'"
rename $value5 fbbandlow
lookfor "Fixed broadband subscriptions: 2 to 10 Mbit/s"
global value5="`r(varlist)'"
rename $value5 fbbandmed
lookfor "Fixed broadband subscriptions: >10 Mbit/s"
global value5="`r(varlist)'"
rename $value5 fbbandhigh

lookfor "International bandwidth per Internet user (kbit/s)"
global value5="`r(varlist)'"
rename $value5 bandwidth_intus

lookfor "Households with Internet access at home (%)"
global value5="`r(varlist)'"
rename $value5 intacceshh
lookfor "Households with a computer at home (%)"
global value5="`r(varlist)'"
rename $value5 comphh
save "$root\Sources\itux", replace


******************************************* ITU 2

use "$root\Sources\codepopreg", clear
collapse (first) Region, by(code CountryName)
rename (CountryName) (country)
replace country="Saint Kitts and Nevis" if country=="St. Kitts and Nevis"
replace country="Saint Lucia" if country=="St. Lucia"
replace country="Saint Vincent and the Grenadines" if country=="St. Vincent and the Grenadines"
replace country="St. Maarten" if country=="Sint Maarten (Dutch part)"
replace country="Bahamas" if strmatch(country, "Bahamas*")
replace country="Bolivia" if strmatch(country, "Bolivia*")
replace country="Dominican Republic" if country=="Dominican Rep."
replace country="French Guiana" if strmatch(country, "French Guiana*")
replace country="Martinique" if strmatch(country, "Martinique*")
replace country="Nicaragua" if strmatch(country, "Nicaragua*")
replace country="Panama" if country=="Panamá"
replace country="Venezuela" if strmatch(country, "Venezuela*")
replace country="Turks & Caicos Is." if country=="Turks and Caicos Islands"
replace country="Virgin Islands (US)" if country=="Virgin Islands (U.S.)"
replace country="Dem. Rep. of the Congo" if country=="Congo, Dem. Rep."
replace country="Congo (Rep. of the)" if country=="Congo, Rep."
replace country="Egypt" if country=="Egypt, Arab Rep."
replace country="Korea (Rep. of)" if country=="Korea, Rep."
replace country="Czech Republic" if country=="Czechia"
replace country="Gambia" if country=="Gambia, The"
replace country="Central African Rep." if country=="Central African Republic"
replace country="Hong Kong, China" if country=="Hong Kong SAR, China"
replace country="Iran (Islamic Republic of)" if country=="Iran, Islamic Rep."
replace country="Kyrgyzstan" if country=="Kyrgyz Republic"
replace country="Lao P.D.R." if country=="Lao PDR"
replace country="Macao, China" if country=="Macao SAR, China"
replace country="Micronesia" if country=="Micronesia, Fed. Sts."
replace country="Nepal (Republic of)" if country=="Nepal"
replace country="Northern Marianas" if country=="Northern Mariana Islands"
replace country="Slovakia" if country=="Slovak Republic"
replace country="Taiwan, Province of China" if country=="Taiwan"
replace country="Turkey" if country=="Turkiye"
replace country="Viet Nam" if country=="Vietnam"
replace country="Yemen" if country=="Yemen, Rep."
tempfile iso
save `iso'
local bases "InternationalBandwidthInMbits_2007-2020 MobileBroadbandSubscriptions_2007-2020 FixedBroadbandSubscriptions_2000-2020 PercentIndividualsUsingInternet MobileCellularSubscriptions_2000-2020 FixedTelephoneSubscriptions_2000-2020"
foreach ba of local bases {
di "`ba'"
import excel "$root\Sources\\`ba'.xlsx", clear firstrow 
local i =1
foreach v of varlist _all {
rename `v' A`i'
 local i = `i'+1
}
rename (A1 A2) (B C)

ds A*
foreach v of varlist `r(varlist)' {
   local x : variable label `v'
   rename `v' v`x'
}
keep B C *value
rename *_value *
reshape long v, i(B C) j(year)
local five = substr("`ba'",1,10)
tempfile `five'
save ``five''
}
clear
foreach ba of local bases{
local five = substr("`ba'",1,10)
append using ``five''
}
rename (B C v) (variable country value)
replace country="Dominican Republic" if country=="Dominican Rep."
replace country="French Guiana" if strmatch(country, "French Guiana*")
replace country="Martinique" if strmatch(country, "Martinique*")
replace country="Nicaragua" if strmatch(country, "Nicaragua*")
replace country="Panama" if country=="Panamá"
replace country="Venezuela" if strmatch(country, "Venezuela*")
replace country="Bolivia" if strmatch(country, "Bolivia*")
replace country="Korea, Dem. People's Rep." if strmatch(country, "Dem. People*")
replace country="Cote d'Ivoire" if strmatch(country, "*Ivoire*")

encode variable, gen(col)
drop if col==.
*Converting to panel data format and saving the variable labels
reshape_save_labels "year country" col value

merge m:1 country using `iso', keep(match master) nogen
drop country
drop if code==""
compress
lookfor "Mobile-cellular telephone subscriptions;  by postpaid/prepaid"
global value5="`r(varlist)'"
rename ( $value5) ( mtel) 
lookfor "Fixed-broadband subscriptions"
global value5="`r(varlist)'"
rename ( $value5) ( fbband) 
lookfor "International bandwidth;  in Mbit/s"
global value5="`r(varlist)'"
rename $value5 bandwidth
lookfor "Internet users (%)"
global value5="`r(varlist)'"
rename $value5 intuspop
lookfor "Fixed-telephone subscriptions"
global value5="`r(varlist)'"
rename $value5 ftel
save "$root\Sources\itu2x", replace

*************** WEO

import excel "$root\Sources\WEO_Data (9).xlsx", clear firstrow
drop if Country==""
drop Estimates Scale
compress
ds F-AA
local i = 2000	
foreach v of varlist `r(varlist)'{
cap replace `v'="" if `v'=="n/a"
cap destring `v', replace
rename `v' value`i'
local i = `i'+ 1
}
reshape long value, i(ISO Country SubjectDescriptor Units) j(year)
gen SeriesName="WEO-" + SubjectDescriptor + " (" + Units + ")"
drop SubjectDescriptor Units Country 
rename ISO code
encode SeriesName, gen(col)

*Converting to panel data format and saving the variable labels
reshape_save_labels "year code" col value

compress
lookfor "WEO-Inflation, average consumer prices (Percent change)"
global value5="`r(varlist)'"
lab var $value5  "Inflation"
rename $value5 inf
save "$root\Sources\weox", replace


use "$root\Sources\PWT 2023", clear
rename countrycode code
tempfile a
save `a'

*********** ALL TOGUETER
use "$root\Sources\wbg", clear
merge 1:1 code year using "$root\Sources/impgoods_curusd.dta", keep(master match) nogen
merge 1:1 code year using "$root\Sources/expgoods_curusd.dta", keep(master match) nogen
merge 1:1 code year using "$root\Sources/ictimp_goodimp.dta", keep(master match) nogen
merge 1:1 code year using "$root\Sources/sec_school_enr.dta", keep(master match) nogen
merge 1:1 code year using "$root\Sources/tradegdp.dta", keep(master match) nogen
merge 1:1 code year using "$root\Sources\egov", keep(master match) nogen
merge 1:1 code year using "$root\Sources\ilo", keep(master match) nogen
merge 1:1 code year using "$root\Sources\itux", keep(master match) nogen
merge 1:1 code year using "$root\Sources\itu2x", keep(master match) nogen
merge 1:1 code year using "$root\Sources\wits", keep(master match) nogen
merge 1:1 code year using "$root\Sources\gsod", keep(master match) nogen
merge 1:1 code year using "$root\Sources\weox", keep(master match) nogen
merge 1:1 code year using "$root\Sources\pisa", keep(master match) nogen
merge 1:1 code year using `a', keep(master match) nogen
drop if Region==""


lookfor "Gross value added at basic prices (GVA) (constant 2015 US$)"
global value1="`r(varlist)'"
lookfor "Jobs-Total employment, total (ages 15+)"
global value2="`r(varlist)'"
gen prod=$value1 /$value2
lab var prod "GVA per worker (const 2015$)"


gen mtel_adpop=(mtel/popadult)*100
lab var mtel_adpop "Mobile cellular subscriptions per 100 adult pop"
gen mbband_adpop=(mbband/popadult)*100
lab var mbband_adpop "Mobile broadband subscription per 100 adult pop"
replace fbband=. if fbband==0 // Haiti had value of zero for this in 2012/13/14, which I think is an error
gen fbband_adpop=(fbband/popadult)*100 // fixed broadband subscription per 100 adult population
lab var fbband_adpop "Fixed broadband subscription per 100 adult pop"
gen ftel_adpop=(ftel/popadult)*100 
label var ftel_adpop "Fixed tel subs. per 100 adult pop-ITU"


rename expgood expgoods
label var secschenr "Secondary"
rename secschenr secenr
rename trade tradegdp
lab var tradegdp "Trade/GDP"
rename e_gov_develop egov
lookfor "ICT goods imports"
global value0="`r(varlist)'"
lab var  $value0 "ICT imports"
rename $value0 ictimports
lookfor "Goods imports (BoP, current US$)"
global value1="`r(varlist)'"
lookfor "GDP (current US$)"
global value2="`r(varlist)'"
generate ictgdp=ictimports*$value1/$value2
lab var  ictgdp "ICT/GDP"
lab var transplaw "Transparent laws with predictable enforcement (0-4)"
lab var laworder "Law and order ICGR index"
lab var bureauqual "Bureaucracy quality ICRG index"
replace pupilratio=1/pupilratio
gen patent_adpop=(patent/popadult)*1000000
lab var patent_adpop "Resident patent per million pop"

gen capital_gdp=rnna/rgdpna
lab var capital_gdp "Capital stock to GDP ratio"


egen code1=group(code), label
xtset code1 year
foreach i in ctfp cwtfp rtfpna rwtfpna {
gen `i'gr_pwt=`i'/l.`i'-1
}

lab var ctfpgr_pwt "TFP level at current PPPs (USA=1) growth"
lab var cwtfpgr_pwt "Welfare-relevant TFP levels at current PPPs (USA=1) growth"
lab var rtfpnagr_pwt "TFP at constant national prices (2017=1) growth"
lab var rwtfpnagr_pwt "Welfare-relevant TFP at constant national prices (2017=1) growth"
gen gdppc_pwt=rgdpna/pop
gen gdppcgr_pwt =gdppc_pwt/l.gdppc_pwt-1
lab var gdppcgr_pwt "Real GDP at constant 2017 per capita growth"
gen gdpgr_pwt =rgdpna/l.rgdpna-1
lab var gdpgr_pwt "Real GDP at constant 2017 growth"

*Interpolate
global intrapolate "bandwidth egov bandwidth_intus fbbandmed fbbandlow fbbandhigh corrcont inf gdppc prod prodgr prod_ilo hhmarket laworder transplaw bureauqual pisascience pisamath pisareading ctfp cwtfp rtfpna rwtfpna"
sort  code1 year
foreach var in $intrapolate {
interpolate code1 year `var'
}


*Interpolate but cannot be <0 
global intrapolatepercent "researchers pupilratio patent_adpop ictgdp ictimports tradegdp ftel_adpop ftelpop mtel_adpop mtelpop fbband_adpop mbband_adpop"
foreach var in $intrapolatepercent {
interpolate code1 year `var', n(1)
}

*Interpolate but cannot be <0 and >100
global intrapolatepercent "mnet_pop mnet3g mnet4g intuspop intacceshh comphh secenr invgdp emppop terenr researchgdp education"
foreach var in $intrapolatepercent {
interpolate code1 year `var', n(1) h(1)
}

*Converting percentage to proportion to increase coefficient magnitudes
global proportion "ftel_adpop mtel_adpop mtelpop ftelpop fbband_adpop mbband_adpop intuspop mnet3g mnet4g mnet_pop intacceshh comphh"
foreach var in $proportion {
replace `var'2=`var'2/100
}


*converting level indicators to logs to have standard coefficients 
foreach v in prod2 gdppc2 patent_adpop2 researchers2 bandwidth2 egov2 ftel_adpop2 ftelpop2 mtel_adpop2 mtelpop2 fbbandmed2 fbbandlow2 fbbandhigh2 fbband_adpop2 bandwidth_intus2 intuspop2 prod_ilo2 secenr2 terenr2 education2 invgdp2 emppop2 tradegdp2 inf2 corrcont2 ctfp cwtfp rtfpna rwtfpna rnna gdppcgr_pwt gdpgr_pwt ctfpgr_pwt cwtfpgr_pwt rtfpnagr_pwt rwtfpnagr_pwt capital_gdp {
local tag: var lab  `v'
gen ln`v'=ln(`v'+1)
lab var ln`v' "log `tag'"
}

drop if country=="Cuba"
drop if country=="Venezuela, RB"
egen region=group(Region), label
replace region=1 if region==5
sort code year 

*DEMEANING
foreach var1 in lnprod2 ftel_adpop2 ftelpop2 mtel_adpop2 mtelpop2 fbband_adpop2 intuspop2 secenr2 terenr2 pupilratio2 ictgdp2 invgdp2 emppop2 tradegdp2 inf2 corrcont2 lnpatent_adpop2 pisascience2 pisamath2 pisareading2 education2 researchers2 researchgdp2 prodgr2 lnprod_ilo2 {
	by code: egen `var1'_mean=mean(`var1')
	by code: gen `var1'_dm = `var1'- `var1'_mean 
	local var2 : variable label `var1'
	lab var `var1'_dm "`var2'"
	drop `var1'_mean
}



save "$root\data2", replace
