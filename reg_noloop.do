
global root "C:\Users\Dell\Downloads\Digital_productivity"
*global root "C:\Users\wb446522\OneDrive - WBG\Documents\___EFI FO\___Research\Stata\May5_23"
global results "$root\results"


cd "$root"


*global ecovars "lnprod2 prodgr2 gdppcgr2 gdpgr lngdp2 lngdppc2"
global digvars "ftel_adpop2 ftelpop2 mtel_adpop2 mtelpop2 fbband_adpop2 intuspop2"
global digvars_dm "ftel_adpop2_dm ftelpop2_dm mtel_adpop2_dm mtelpop2_dm fbband_adpop2_dm intuspop2_dm"
global control "secenr2 terenr2 education2 ictgdp2 invgdp2 emppop2 tradegdp2 inf2 corrcont2 lnpatent_adpop2" 
global control_dm "secenr2_dm terenr2_dm education2_dm ictgdp2_dm invgdp2_dm emppop2_dm tradegdp2_dm inf2_dm corrcont2_dm lnpatent_adpop2_dm" 



use "$root\data", clear
local first="lnprod2"
local second="secenr2"
local third="hhmarket2"
local var1="mnet_pop2"

xtset code1 year

local newdigvars
local replace replace
tempfile regs
foreach c in $control {
local tag`c': var lab `c'
}
foreach var1 in $digvars {
reg d1.(`first' `var1' $control) i.year ib7.region, robust
local rc=_rc 
if "`rc'"=="0"{
quietly ta code if e(sample)
local N_g=r(r)
local R2="`e(r2)'"
cap regsave using "`regs'", p addlabel(dep,"`var1'", codes, "`N_g'", R2, "`R2'") `replace'
local replace append
local tag`var1': var lab `var1'
local newdigvars "`newdigvars' `var1'"
}
}
global newdigvars "`newdigvars'"
use "`regs'", clear
*saving the results in a Stata dataset
tempfile mytable
gen dep2="D."+dep
replace var="Coef" if var==dep2 // we have the same dependant var. and different independent var., so we rearrange to have all the independent variable in a row called "Coef"
drop dep2
drop if strmatch(var, "7b.region*")
drop if strmatch(var, "2001b.year*")
local replace replace
foreach v in $newdigvars  {	
cap regsave_tbl using "`mytable'" if dep=="`v'", name(`v') asterisk(10 5 1) parentheses(stderr) `replace' format(%5.3f)
local replace append
}
use "`mytable'", clear
drop if substr(var,1,2)=="o."  | substr(var,-5,5)=="_pval"
drop if var=="dep"
drop if strmatch(var,"*year*") | strmatch(var,"*code1*") 
** ordering so we see the relevant variables first
gen id=_n
replace id=id-100 if substr(var,1,4)!="_cons"  & var!="N" & var!="codes" & var!="R2"  
sort id
drop id
replace var = subinstr(var,"_coef","",1)
replace var = "" if strpos(var,"_stderr")
replace var = "Number of observations" if var=="N"
replace var = "Number of countries" if var=="codes"
replace var = "Constant" if var=="_cons"
foreach var1 in $digvars {      
cap label variable  `var1' "`tag`var1''"
}
foreach c in $control {      
replace var="`tag`c''" if var=="D.`c'" 
}
drop if var=="r2"
replace var=subinstr(var,"1.region", "EAP", .)
replace var=subinstr(var,"2.region", "ECA_NA", .)
replace var=subinstr(var,"3.region", "LAC", .)
replace var=subinstr(var,"4.region", "MNA", .)
replace var=subinstr(var,"6.region", "SAR", .)
replace var=subinstr(var," +/-3yrs", "", .)
export excel "$results\\`first'.xlsx", replace firstrow(varl)